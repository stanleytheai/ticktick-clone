import { Router, Request, Response } from "express";
import { db, auth } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import { UpdateProfileSchema } from "../models/schemas";

const router = Router();

// GET /account/profile - Get user profile
router.get("/profile", async (_req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const userRecord = await auth.getUser(uid);

    res.json({
      uid: userRecord.uid,
      email: userRecord.email,
      displayName: userRecord.displayName || null,
      photoURL: userRecord.photoURL || null,
      emailVerified: userRecord.emailVerified,
      createdAt: userRecord.metadata.creationTime,
      lastSignIn: userRecord.metadata.lastSignInTime,
      providers: userRecord.providerData.map((p) => p.providerId),
    });
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch profile" });
  }
});

// PUT /account/profile - Update user profile
router.put(
  "/profile",
  validate(UpdateProfileSchema),
  async (req: Request, res: Response) => {
    try {
      const uid = getUid(res);
      const { displayName, photoURL } = req.body;

      const updateData: Record<string, string> = {};
      if (displayName !== undefined) updateData.displayName = displayName;
      if (photoURL !== undefined) updateData.photoURL = photoURL;

      const userRecord = await auth.updateUser(uid, updateData);

      res.json({
        uid: userRecord.uid,
        email: userRecord.email,
        displayName: userRecord.displayName || null,
        photoURL: userRecord.photoURL || null,
      });
    } catch (error) {
      res.status(500).json({ error: "Failed to update profile" });
    }
  }
);

// POST /account/password-reset - Send password reset email
router.post("/password-reset", async (req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const userRecord = await auth.getUser(uid);

    if (!userRecord.email) {
      res.status(400).json({ error: "No email associated with account" });
      return;
    }

    const link = await auth.generatePasswordResetLink(userRecord.email);

    res.json({ message: "Password reset link generated", link });
  } catch (error) {
    res.status(500).json({ error: "Failed to generate password reset link" });
  }
});

// POST /account/export - Export all user data
router.post("/export", async (_req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const userRecord = await auth.getUser(uid);
    const userRef = db.collection("users").doc(uid);

    // Gather all user data
    const [tasksSnap, listsSnap, tagsSnap] = await Promise.all([
      userRef.collection("tasks").get(),
      userRef.collection("lists").get(),
      userRef.collection("tags").get(),
    ]);

    // Gather subtasks for each task
    const tasksWithSubtasks = await Promise.all(
      tasksSnap.docs.map(async (taskDoc) => {
        const subtasksSnap = await taskDoc.ref.collection("subtasks").get();
        return {
          ...taskDoc.data(),
          id: taskDoc.id,
          subtasks: subtasksSnap.docs.map((s) => ({ id: s.id, ...s.data() })),
        };
      })
    );

    const exportData = {
      exportedAt: new Date().toISOString(),
      profile: {
        email: userRecord.email,
        displayName: userRecord.displayName,
        createdAt: userRecord.metadata.creationTime,
      },
      tasks: tasksWithSubtasks,
      lists: listsSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
      tags: tagsSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
    };

    res.json(exportData);
  } catch (error) {
    res.status(500).json({ error: "Failed to export data" });
  }
});

// DELETE /account - Delete user account and all data
router.delete("/", async (_req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const userRef = db.collection("users").doc(uid);

    // Delete all subcollections
    const collections = ["tasks", "lists", "tags"];
    for (const collName of collections) {
      const snap = await userRef.collection(collName).get();
      const batch = db.batch();
      for (const doc of snap.docs) {
        // Delete subcollections of tasks (subtasks)
        if (collName === "tasks") {
          const subtasks = await doc.ref.collection("subtasks").get();
          for (const sub of subtasks.docs) {
            batch.delete(sub.ref);
          }
        }
        batch.delete(doc.ref);
      }
      await batch.commit();
    }

    // Delete settings doc
    const settingsDoc = userRef.collection("settings").doc("preferences");
    await settingsDoc.delete();

    // Delete user doc
    await userRef.delete();

    // Delete Firebase Auth user
    await auth.deleteUser(uid);

    res.json({ message: "Account deleted successfully" });
  } catch (error) {
    res.status(500).json({ error: "Failed to delete account" });
  }
});

export default router;
