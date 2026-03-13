import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import {
  CreateTaskSchema,
  UpdateTaskSchema,
  BatchTaskSchema,
  TaskDoc,
} from "../models/schemas";

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
    const updateData = {
      completed: !data.completed,
      completedAt: !data.completed ? now : null,
      updatedAt: now,
    };
    await docRef.update(updateData);
    const { id: _id, ...rest } = data;
    res.json({ id: doc.id, ...rest, ...updateData });
  } catch {
    res.status(500).json({ error: "Failed to update task completion" });
  }
});

export default router;
