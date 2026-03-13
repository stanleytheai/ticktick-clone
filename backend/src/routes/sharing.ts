import { Router, Request, Response } from "express";
import { db, auth } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import {
  ShareListSchema,
  UpdateMemberSchema,
  CreateTaskSchema,
  UpdateTaskSchema,
  CreateCommentSchema,
  AssignTaskSchema,
  SharedListDoc,
  MemberInfo,
  ActivityDoc,
} from "../models/schemas";

const router = Router();

function sharedListsCollection() {
  return db.collection("sharedLists");
}

function sharedTasksCollection(listId: string) {
  return sharedListsCollection().doc(listId).collection("tasks");
}

function activityCollection(listId: string) {
  return sharedListsCollection().doc(listId).collection("activity");
}

async function requireMembership(
  listId: string,
  uid: string,
  minRole: "view" | "edit" | "admin" = "view"
): Promise<{ doc: FirebaseFirestore.DocumentSnapshot; data: SharedListDoc } | null> {
  const doc = await sharedListsCollection().doc(listId).get();
  if (!doc.exists) return null;
  const data = { id: doc.id, ...doc.data() } as SharedListDoc;
  const member = data.members[uid];
  if (!member) return null;

  const roleHierarchy = { view: 0, edit: 1, admin: 2 };
  if (roleHierarchy[member.role] < roleHierarchy[minRole]) return null;

  return { doc, data };
}

async function logActivity(
  listId: string,
  actorId: string,
  type: string,
  description: string,
  metadata?: Record<string, unknown>
): Promise<void> {
  const entry: Omit<ActivityDoc, "id"> = {
    type,
    actorId,
    description,
    metadata,
    createdAt: new Date().toISOString(),
  };
  await activityCollection(listId).add(entry);
}

// POST /shared-lists — create a new shared list
router.post("/", async (req: Request, res: Response) => {
  const uid = getUid(res);
  const { name, color, icon } = req.body;
  if (!name || typeof name !== "string" || name.trim().length === 0) {
    res.status(400).json({ error: "Name is required" });
    return;
  }
  const now = new Date().toISOString();
  try {
    let userEmail = "";
    let displayName = "";
    try {
      const userRecord = await auth.getUser(uid);
      userEmail = userRecord.email ?? "";
      displayName = userRecord.displayName ?? "";
    } catch {
      // ignore if user record not found
    }

    const members: Record<string, MemberInfo> = {
      [uid]: {
        role: "admin",
        email: userEmail,
        displayName,
        addedAt: now,
      },
    };

    const listData: Omit<SharedListDoc, "id"> = {
      name: name.trim(),
      color,
      icon,
      ownerId: uid,
      members,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    };

    const docRef = await sharedListsCollection().add(listData);
    await logActivity(docRef.id, uid, "list_created", `Created shared list "${name.trim()}"`);
    res.status(201).json({ id: docRef.id, ...listData });
  } catch {
    res.status(500).json({ error: "Failed to create shared list" });
  }
});

// GET /shared-lists — list all shared lists for current user
router.get("/", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const snapshot = await sharedListsCollection()
      .where(`members.${uid}.role`, "in", ["view", "edit", "admin"])
      .get();
    const lists = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    res.json({ lists });
  } catch {
    res.status(500).json({ error: "Failed to fetch shared lists" });
  }
});

// GET /shared-lists/:id — get a shared list
router.get("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const result = await requireMembership(req.params.id, uid);
    if (!result) {
      res.status(404).json({ error: "Shared list not found" });
      return;
    }
    res.json(result.data);
  } catch {
    res.status(500).json({ error: "Failed to fetch shared list" });
  }
});

// PUT /shared-lists/:id — update shared list
router.put("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const result = await requireMembership(req.params.id, uid, "edit");
    if (!result) {
      res.status(403).json({ error: "Insufficient permissions" });
      return;
    }
    const { name, color, icon } = req.body;
    const updateData: Record<string, unknown> = { updatedAt: new Date().toISOString() };
    if (name !== undefined) updateData.name = name;
    if (color !== undefined) updateData.color = color;
    if (icon !== undefined) updateData.icon = icon;
    await sharedListsCollection().doc(req.params.id).update(updateData);
    res.json({ ...result.data, ...updateData });
  } catch {
    res.status(500).json({ error: "Failed to update shared list" });
  }
});

// DELETE /shared-lists/:id — delete a shared list (owner only)
router.delete("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const result = await requireMembership(req.params.id, uid, "admin");
    if (!result || result.data.ownerId !== uid) {
      res.status(403).json({ error: "Only the owner can delete a shared list" });
      return;
    }
    // Delete all tasks and activity in the list
    const batch = db.batch();
    const tasks = await sharedTasksCollection(req.params.id).get();
    for (const doc of tasks.docs) batch.delete(doc.ref);
    const activity = await activityCollection(req.params.id).get();
    for (const doc of activity.docs) batch.delete(doc.ref);
    batch.delete(sharedListsCollection().doc(req.params.id));
    await batch.commit();
    res.status(204).send();
  } catch {
    res.status(500).json({ error: "Failed to delete shared list" });
  }
});

// POST /shared-lists/:id/members — invite a member by email
router.post(
  "/:id/members",
  validate(ShareListSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    try {
      const result = await requireMembership(req.params.id, uid, "admin");
      if (!result) {
        res.status(403).json({ error: "Insufficient permissions" });
        return;
      }
      const { email, permission } = req.body;

      // Look up user by email
      let targetUser;
      try {
        targetUser = await auth.getUserByEmail(email);
      } catch {
        res.status(404).json({ error: "No user found with that email" });
        return;
      }

      if (result.data.members[targetUser.uid]) {
        res.status(409).json({ error: "User is already a member" });
        return;
      }

      const now = new Date().toISOString();
      const memberInfo: MemberInfo = {
        role: permission,
        email,
        displayName: targetUser.displayName ?? "",
        addedAt: now,
      };

      await sharedListsCollection()
        .doc(req.params.id)
        .update({
          [`members.${targetUser.uid}`]: memberInfo,
          updatedAt: now,
        });

      await logActivity(
        req.params.id,
        uid,
        "member_added",
        `Invited ${email} as ${permission}`,
        { targetUid: targetUser.uid, email, permission }
      );

      res.status(201).json({ uid: targetUser.uid, ...memberInfo });
    } catch {
      res.status(500).json({ error: "Failed to invite member" });
    }
  }
);

// PUT /shared-lists/:id/members/:uid — update member permission
router.put(
  "/:id/members/:memberUid",
  validate(UpdateMemberSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    try {
      const result = await requireMembership(req.params.id, uid, "admin");
      if (!result) {
        res.status(403).json({ error: "Insufficient permissions" });
        return;
      }
      const memberUid = req.params.memberUid;
      if (!result.data.members[memberUid]) {
        res.status(404).json({ error: "Member not found" });
        return;
      }
      if (memberUid === result.data.ownerId) {
        res.status(400).json({ error: "Cannot change owner's permission" });
        return;
      }

      const { permission } = req.body;
      await sharedListsCollection()
        .doc(req.params.id)
        .update({
          [`members.${memberUid}.role`]: permission,
          updatedAt: new Date().toISOString(),
        });

      await logActivity(
        req.params.id,
        uid,
        "member_updated",
        `Changed ${result.data.members[memberUid].email}'s role to ${permission}`,
        { targetUid: memberUid, permission }
      );

      res.json({ uid: memberUid, role: permission });
    } catch {
      res.status(500).json({ error: "Failed to update member" });
    }
  }
);

// DELETE /shared-lists/:id/members/:uid — remove a member
router.delete("/:id/members/:memberUid", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const result = await requireMembership(req.params.id, uid, "admin");
    const memberUid = req.params.memberUid;

    // Allow self-removal even without admin
    if (!result && memberUid !== uid) {
      res.status(403).json({ error: "Insufficient permissions" });
      return;
    }

    // Re-check membership for self-removal case
    if (!result) {
      const selfCheck = await requireMembership(req.params.id, uid);
      if (!selfCheck) {
        res.status(404).json({ error: "Shared list not found" });
        return;
      }
    }

    const listDoc = await sharedListsCollection().doc(req.params.id).get();
    const listData = listDoc.data() as SharedListDoc;

    if (memberUid === listData.ownerId) {
      res.status(400).json({ error: "Cannot remove the owner" });
      return;
    }

    const { FieldValue } = await import("firebase-admin/firestore");
    await sharedListsCollection()
      .doc(req.params.id)
      .update({
        [`members.${memberUid}`]: FieldValue.delete(),
        updatedAt: new Date().toISOString(),
      });

    await logActivity(
      req.params.id,
      uid,
      "member_removed",
      memberUid === uid ? "Left the list" : `Removed a member`,
      { targetUid: memberUid }
    );

    res.status(204).send();
  } catch {
    res.status(500).json({ error: "Failed to remove member" });
  }
});

// ── Shared list tasks ──────────────────────────────────

// GET /shared-lists/:id/tasks
router.get("/:id/tasks", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const result = await requireMembership(req.params.id, uid);
    if (!result) {
      res.status(404).json({ error: "Shared list not found" });
      return;
    }
    const snapshot = await sharedTasksCollection(req.params.id).orderBy("sortOrder").get();
    const tasks = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    res.json({ tasks });
  } catch {
    res.status(500).json({ error: "Failed to fetch tasks" });
  }
});

// POST /shared-lists/:id/tasks
router.post(
  "/:id/tasks",
  validate(CreateTaskSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    try {
      const result = await requireMembership(req.params.id, uid, "edit");
      if (!result) {
        res.status(403).json({ error: "Insufficient permissions" });
        return;
      }
      const now = new Date().toISOString();
      const taskData = {
        ...req.body,
        completed: false,
        createdBy: uid,
        createdAt: now,
        updatedAt: now,
      };
      const docRef = await sharedTasksCollection(req.params.id).add(taskData);

      await logActivity(
        req.params.id,
        uid,
        "task_created",
        `Created task "${req.body.title}"`,
        { taskId: docRef.id }
      );

      res.status(201).json({ id: docRef.id, ...taskData });
    } catch {
      res.status(500).json({ error: "Failed to create task" });
    }
  }
);

// PUT /shared-lists/:id/tasks/:taskId
router.put(
  "/:id/tasks/:taskId",
  validate(UpdateTaskSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    try {
      const result = await requireMembership(req.params.id, uid, "edit");
      if (!result) {
        res.status(403).json({ error: "Insufficient permissions" });
        return;
      }
      const taskRef = sharedTasksCollection(req.params.id).doc(req.params.taskId);
      const taskDoc = await taskRef.get();
      if (!taskDoc.exists) {
        res.status(404).json({ error: "Task not found" });
        return;
      }
      const updateData = { ...req.body, updatedAt: new Date().toISOString() };
      await taskRef.update(updateData);
      res.json({ id: taskDoc.id, ...taskDoc.data(), ...updateData });
    } catch {
      res.status(500).json({ error: "Failed to update task" });
    }
  }
);

// DELETE /shared-lists/:id/tasks/:taskId
router.delete("/:id/tasks/:taskId", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const result = await requireMembership(req.params.id, uid, "edit");
    if (!result) {
      res.status(403).json({ error: "Insufficient permissions" });
      return;
    }
    const taskRef = sharedTasksCollection(req.params.id).doc(req.params.taskId);
    const taskDoc = await taskRef.get();
    if (!taskDoc.exists) {
      res.status(404).json({ error: "Task not found" });
      return;
    }
    await taskRef.delete();

    await logActivity(
      req.params.id,
      uid,
      "task_deleted",
      `Deleted task "${(taskDoc.data() as Record<string, unknown>).title}"`,
      { taskId: req.params.taskId }
    );

    res.status(204).send();
  } catch {
    res.status(500).json({ error: "Failed to delete task" });
  }
});

// PATCH /shared-lists/:id/tasks/:taskId/complete — toggle completion
router.patch("/:id/tasks/:taskId/complete", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const result = await requireMembership(req.params.id, uid, "edit");
    if (!result) {
      res.status(403).json({ error: "Insufficient permissions" });
      return;
    }
    const taskRef = sharedTasksCollection(req.params.id).doc(req.params.taskId);
    const taskDoc = await taskRef.get();
    if (!taskDoc.exists) {
      res.status(404).json({ error: "Task not found" });
      return;
    }
    const data = taskDoc.data()!;
    const now = new Date().toISOString();
    const completing = !data.completed;
    const updateData = {
      completed: completing,
      completedAt: completing ? now : null,
      updatedAt: now,
    };
    await taskRef.update(updateData);

    await logActivity(
      req.params.id,
      uid,
      completing ? "task_completed" : "task_reopened",
      completing
        ? `Completed task "${data.title}"`
        : `Reopened task "${data.title}"`,
      { taskId: req.params.taskId }
    );

    res.json({ id: taskDoc.id, ...data, ...updateData });
  } catch {
    res.status(500).json({ error: "Failed to update task completion" });
  }
});

// PATCH /shared-lists/:id/tasks/:taskId/assign — assign task
router.patch(
  "/:id/tasks/:taskId/assign",
  validate(AssignTaskSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    try {
      const result = await requireMembership(req.params.id, uid, "edit");
      if (!result) {
        res.status(403).json({ error: "Insufficient permissions" });
        return;
      }

      const { assigneeId } = req.body;

      // Verify assignee is a member (if not null)
      if (assigneeId && !result.data.members[assigneeId]) {
        res.status(400).json({ error: "Assignee must be a member of the list" });
        return;
      }

      const taskRef = sharedTasksCollection(req.params.id).doc(req.params.taskId);
      const taskDoc = await taskRef.get();
      if (!taskDoc.exists) {
        res.status(404).json({ error: "Task not found" });
        return;
      }

      const now = new Date().toISOString();
      await taskRef.update({ assigneeId: assigneeId ?? null, updatedAt: now });

      const assigneeName = assigneeId
        ? result.data.members[assigneeId]?.displayName || result.data.members[assigneeId]?.email
        : "nobody";

      await logActivity(
        req.params.id,
        uid,
        "task_assigned",
        `Assigned "${(taskDoc.data() as Record<string, unknown>).title}" to ${assigneeName}`,
        { taskId: req.params.taskId, assigneeId }
      );

      res.json({ id: taskDoc.id, ...taskDoc.data(), assigneeId, updatedAt: now });
    } catch {
      res.status(500).json({ error: "Failed to assign task" });
    }
  }
);

// ── Comments ───────────────────────────────────────────

function commentsCollection(listId: string, taskId: string) {
  return sharedTasksCollection(listId).doc(taskId).collection("comments");
}

// GET /shared-lists/:id/tasks/:taskId/comments
router.get("/:id/tasks/:taskId/comments", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const result = await requireMembership(req.params.id, uid);
    if (!result) {
      res.status(404).json({ error: "Shared list not found" });
      return;
    }
    const snapshot = await commentsCollection(req.params.id, req.params.taskId)
      .orderBy("createdAt")
      .get();
    const comments = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    res.json({ comments });
  } catch {
    res.status(500).json({ error: "Failed to fetch comments" });
  }
});

// POST /shared-lists/:id/tasks/:taskId/comments
router.post(
  "/:id/tasks/:taskId/comments",
  validate(CreateCommentSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    try {
      const result = await requireMembership(req.params.id, uid);
      if (!result) {
        res.status(404).json({ error: "Shared list not found" });
        return;
      }

      // Get author info
      let authorName = "";
      try {
        const userRecord = await auth.getUser(uid);
        authorName = userRecord.displayName ?? userRecord.email ?? "";
      } catch {
        // ignore
      }

      const now = new Date().toISOString();
      const commentData = {
        text: req.body.text,
        authorId: uid,
        authorName,
        mentions: req.body.mentions ?? [],
        createdAt: now,
        updatedAt: now,
      };

      const docRef = await commentsCollection(req.params.id, req.params.taskId).add(
        commentData
      );

      await logActivity(
        req.params.id,
        uid,
        "comment_added",
        `Commented on a task`,
        { taskId: req.params.taskId, commentId: docRef.id }
      );

      res.status(201).json({ id: docRef.id, ...commentData });
    } catch {
      res.status(500).json({ error: "Failed to create comment" });
    }
  }
);

// DELETE /shared-lists/:id/tasks/:taskId/comments/:commentId
router.delete(
  "/:id/tasks/:taskId/comments/:commentId",
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    try {
      const result = await requireMembership(req.params.id, uid);
      if (!result) {
        res.status(404).json({ error: "Shared list not found" });
        return;
      }
      const commentRef = commentsCollection(
        req.params.id,
        req.params.taskId
      ).doc(req.params.commentId);
      const commentDoc = await commentRef.get();
      if (!commentDoc.exists) {
        res.status(404).json({ error: "Comment not found" });
        return;
      }
      // Only author or admin can delete
      const commentData = commentDoc.data()!;
      const memberRole = result.data.members[uid]?.role;
      if (commentData.authorId !== uid && memberRole !== "admin") {
        res.status(403).json({ error: "Can only delete your own comments" });
        return;
      }
      await commentRef.delete();
      res.status(204).send();
    } catch {
      res.status(500).json({ error: "Failed to delete comment" });
    }
  }
);

// ── Activity Feed ──────────────────────────────────────

// GET /shared-lists/:id/activity
router.get("/:id/activity", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const result = await requireMembership(req.params.id, uid);
    if (!result) {
      res.status(404).json({ error: "Shared list not found" });
      return;
    }
    const limit = Math.min(parseInt(req.query.limit as string) || 50, 100);
    const snapshot = await activityCollection(req.params.id)
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();
    const activity = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    res.json({ activity });
  } catch {
    res.status(500).json({ error: "Failed to fetch activity" });
  }
});

// POST /lists/:id/share — convert a personal list to a shared list
router.post("/from-personal/:listId", async (req: Request, res: Response) => {
  const uid = getUid(res);
  const personalListId = req.params.listId;
  try {
    // Read the personal list
    const personalListRef = db
      .collection("users")
      .doc(uid)
      .collection("lists")
      .doc(personalListId);
    const personalListDoc = await personalListRef.get();
    if (!personalListDoc.exists) {
      res.status(404).json({ error: "Personal list not found" });
      return;
    }
    const personalData = personalListDoc.data()!;

    // Get user info
    let userEmail = "";
    let displayName = "";
    try {
      const userRecord = await auth.getUser(uid);
      userEmail = userRecord.email ?? "";
      displayName = userRecord.displayName ?? "";
    } catch {
      // ignore
    }

    const now = new Date().toISOString();
    const members: Record<string, MemberInfo> = {
      [uid]: {
        role: "admin",
        email: userEmail,
        displayName,
        addedAt: now,
      },
    };

    const sharedListData: Omit<SharedListDoc, "id"> = {
      name: personalData.name,
      color: personalData.color,
      icon: personalData.icon,
      ownerId: uid,
      members,
      sortOrder: personalData.sortOrder ?? 0,
      createdAt: personalData.createdAt ?? now,
      updatedAt: now,
    };

    // Create shared list
    const sharedRef = await sharedListsCollection().add(sharedListData);

    // Move tasks from personal to shared
    const personalTasks = await db
      .collection("users")
      .doc(uid)
      .collection("tasks")
      .where("listId", "==", personalListId)
      .get();

    const batch = db.batch();
    for (const taskDoc of personalTasks.docs) {
      const taskData = taskDoc.data();
      const sharedTaskRef = sharedTasksCollection(sharedRef.id).doc(taskDoc.id);
      batch.set(sharedTaskRef, {
        ...taskData,
        createdBy: uid,
        listId: undefined,
      });
      batch.delete(taskDoc.ref);
    }

    // Delete the personal list
    batch.delete(personalListRef);
    await batch.commit();

    await logActivity(
      sharedRef.id,
      uid,
      "list_created",
      `Converted personal list "${personalData.name}" to shared`
    );

    res.status(201).json({ id: sharedRef.id, ...sharedListData });
  } catch {
    res.status(500).json({ error: "Failed to convert list to shared" });
  }
});

export default router;
