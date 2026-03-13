import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { getTierLimits } from "../middleware/subscription";
import { validate } from "../middleware/validate";
import {
  CreateTaskSchema,
  UpdateTaskSchema,
  BatchTaskSchema,
  TaskDoc,
} from "../models/schemas";
import {
  calculateNextDueDate,
  shouldCreateNextOccurrence,
} from "../services/recurrence";
import { parseTaskInput } from "../services/nlp-parser";

const router = Router();

function tasksCollection(uid: string) {
  return db.collection("users").doc(uid).collection("tasks");
}

// GET /tasks — list all tasks
router.get("/", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const snapshot = await tasksCollection(uid).orderBy("sortOrder").get();
    const tasks = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    res.json({ tasks });
  } catch {
    res.status(500).json({ error: "Failed to fetch tasks" });
  }
});

// POST /tasks — create a task
router.post("/", validate(CreateTaskSchema), async (req: Request, res: Response) => {
  const uid = getUid(res);
  const now = new Date().toISOString();
  try {
    // Enforce tasks-per-list limit
    const limits = getTierLimits(res);
    const listId = req.body.listId;
    if (listId && limits.maxTasksPerList !== Infinity) {
      const snapshot = await tasksCollection(uid)
        .where("listId", "==", listId)
        .where("completed", "==", false)
        .count()
        .get();
      const count = snapshot.data().count;
      if (count >= limits.maxTasksPerList) {
        res.status(403).json({
          error: "Task limit per list reached",
          code: "LIMIT_EXCEEDED",
          limit: limits.maxTasksPerList,
          current: count,
          upgrade: true,
        });
        return;
      }
    }

    const taskData: Omit<TaskDoc, "id"> = {
      ...req.body,
      completed: false,
      createdAt: now,
      updatedAt: now,
    };
    const docRef = await tasksCollection(uid).add(taskData);
    res.status(201).json({ id: docRef.id, ...taskData });
  } catch {
    res.status(500).json({ error: "Failed to create task" });
  }
});

// POST /tasks/batch — create multiple tasks
router.post("/batch", validate(BatchTaskSchema), async (req: Request, res: Response) => {
  const uid = getUid(res);
  const now = new Date().toISOString();
  try {
    const batch = db.batch();
    const results: TaskDoc[] = [];

    for (const task of req.body.tasks) {
      const docRef = tasksCollection(uid).doc();
      const taskData: Omit<TaskDoc, "id"> = {
        ...task,
        completed: false,
        createdAt: now,
        updatedAt: now,
      };
      batch.set(docRef, taskData);
      results.push({ id: docRef.id, ...taskData });
    }

    await batch.commit();
    res.status(201).json({ tasks: results });
  } catch {
    res.status(500).json({ error: "Failed to create tasks" });
  }
});

// POST /tasks/parse — parse natural language task input
router.post("/parse", async (req: Request, res: Response) => {
  try {
    const { text } = req.body;
    if (typeof text !== "string") {
      res.status(400).json({ error: "Missing 'text' field" });
      return;
    }
    const parsed = parseTaskInput(text);
    res.json(parsed);
  } catch {
    res.status(500).json({ error: "Failed to parse task input" });
  }
});

// GET /tasks/:id — get a single task
router.get("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const doc = await tasksCollection(uid).doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Task not found" });
      return;
    }
    res.json({ id: doc.id, ...doc.data() });
  } catch {
    res.status(500).json({ error: "Failed to fetch task" });
  }
});

// PUT /tasks/:id — update a task
router.put("/:id", validate(UpdateTaskSchema), async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = tasksCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Task not found" });
      return;
    }
    const updateData = { ...req.body, updatedAt: new Date().toISOString() };
    await docRef.update(updateData);
    res.json({ id: doc.id, ...doc.data(), ...updateData });
  } catch {
    res.status(500).json({ error: "Failed to update task" });
  }
});

// DELETE /tasks/:id — delete a task
router.delete("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = tasksCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Task not found" });
      return;
    }
    await docRef.delete();
    res.status(204).send();
  } catch {
    res.status(500).json({ error: "Failed to delete task" });
  }
});

// PATCH /tasks/:id/complete — toggle task completion
// For recurring tasks: completing creates the next occurrence automatically
router.patch("/:id/complete", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = tasksCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Task not found" });
      return;
    }
    const data = doc.data() as TaskDoc;
    const now = new Date().toISOString();
    const completing = !data.completed;
    const updateData = {
      completed: completing,
      completedAt: completing ? now : null,
      updatedAt: now,
    };
    await docRef.update(updateData);

    let nextTask: (TaskDoc & { id: string }) | undefined;

    // If completing a recurring task, create next occurrence
    if (completing && data.recurrence) {
      const recurrenceCount = (data.recurrenceCount ?? 0) + 1;
      const baseDate = data.recurrence.afterCompletion
        ? now
        : data.dueDate ?? now;
      const nextDueDate = calculateNextDueDate(baseDate, data.recurrence);

      if (
        shouldCreateNextOccurrence(data.recurrence, recurrenceCount, nextDueDate)
      ) {
        // Calculate shifted startDate if original had one
        let nextStartDate: string | undefined;
        if (data.startDate && data.dueDate && nextDueDate) {
          const dueDiff =
            new Date(nextDueDate).getTime() - new Date(data.dueDate).getTime();
          nextStartDate = new Date(
            new Date(data.startDate).getTime() + dueDiff
          ).toISOString();
        }

        const nextTaskData: Omit<TaskDoc, "id"> = {
          title: data.title,
          description: data.description,
          dueDate: nextDueDate ?? undefined,
          startDate: nextStartDate,
          duration: data.duration,
          priority: data.priority,
          tags: data.tags,
          listId: data.listId,
          completed: false,
          sortOrder: data.sortOrder,
          recurrence: data.recurrence,
          recurrenceSourceId: data.recurrenceSourceId ?? doc.id,
          recurrenceCount: recurrenceCount,
          createdAt: now,
          updatedAt: now,
        };

        const nextDocRef = await tasksCollection(uid).add(nextTaskData);
        nextTask = { id: nextDocRef.id, ...nextTaskData };
      }

      // Update completed task's recurrence count
      await docRef.update({ recurrenceCount: recurrenceCount });
    }

    const { id: _id, ...rest } = data;
    const result: Record<string, unknown> = {
      id: doc.id,
      ...rest,
      ...updateData,
    };
    if (nextTask) {
      result.nextOccurrence = nextTask;
    }
    res.json(result);
  } catch {
    res.status(500).json({ error: "Failed to update task completion" });
  }
});

// GET /tasks/:id/occurrences — list all occurrences of a recurring task
router.get("/:id/occurrences", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const taskId = req.params.id;
    // Find tasks that share the same recurrence source
    const snapshot = await tasksCollection(uid)
      .where("recurrenceSourceId", "==", taskId)
      .orderBy("createdAt")
      .get();

    // Also include the original task
    const originalDoc = await tasksCollection(uid).doc(taskId).get();
    const tasks: Record<string, unknown>[] = [];
    if (originalDoc.exists) {
      tasks.push({ id: originalDoc.id, ...originalDoc.data() });
    }
    for (const doc of snapshot.docs) {
      tasks.push({ id: doc.id, ...doc.data() });
    }

    res.json({ occurrences: tasks });
  } catch {
    res.status(500).json({ error: "Failed to fetch occurrences" });
  }
});

export default router;
