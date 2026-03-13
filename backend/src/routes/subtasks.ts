import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import { CreateSubtaskSchema, UpdateSubtaskSchema } from "../models/schemas";

const router = Router({ mergeParams: true });

function subtasksCollection(uid: string, taskId: string) {
  return db
    .collection("users")
    .doc(uid)
    .collection("tasks")
    .doc(taskId)
    .collection("subtasks");
}

// GET /tasks/:id/subtasks — list subtasks
router.get("/", async (req: Request, res: Response) => {
  const uid = getUid(res);
  const taskId = req.params.id;
  try {
    const snapshot = await subtasksCollection(uid, taskId)
      .orderBy("sortOrder")
      .get();
    const subtasks = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
    res.json({ subtasks });
  } catch {
    res.status(500).json({ error: "Failed to fetch subtasks" });
  }
});

// POST /tasks/:id/subtasks — create a subtask
router.post(
  "/",
  validate(CreateSubtaskSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    const taskId = req.params.id;
    const now = new Date().toISOString();
    try {
      const subtaskData = {
        ...req.body,
        createdAt: now,
        updatedAt: now,
      };
      const docRef = await subtasksCollection(uid, taskId).add(subtaskData);
      res.status(201).json({ id: docRef.id, ...subtaskData });
    } catch {
      res.status(500).json({ error: "Failed to create subtask" });
    }
  }
);

// PUT /tasks/:id/subtasks/:sid — update a subtask
router.put(
  "/:sid",
  validate(UpdateSubtaskSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    const taskId = req.params.id;
    const sid = req.params.sid;
    try {
      const docRef = subtasksCollection(uid, taskId).doc(sid);
      const doc = await docRef.get();
      if (!doc.exists) {
        res.status(404).json({ error: "Subtask not found" });
        return;
      }
      const updateData = { ...req.body, updatedAt: new Date().toISOString() };
      await docRef.update(updateData);
      res.json({ id: doc.id, ...doc.data(), ...updateData });
    } catch {
      res.status(500).json({ error: "Failed to update subtask" });
    }
  }
);

// DELETE /tasks/:id/subtasks/:sid — delete a subtask
router.delete("/:sid", async (req: Request, res: Response) => {
  const uid = getUid(res);
  const taskId = req.params.id;
  const sid = req.params.sid;
  try {
    const docRef = subtasksCollection(uid, taskId).doc(sid);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Subtask not found" });
      return;
    }
    await docRef.delete();
    res.status(204).send();
  } catch {
    res.status(500).json({ error: "Failed to delete subtask" });
  }
});

export default router;
