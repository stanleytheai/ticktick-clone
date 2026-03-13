import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import { CreateTagSchema, UpdateTagSchema } from "../models/schemas";

const router = Router();

function tagsCollection(uid: string) {
  return db.collection("users").doc(uid).collection("tags");
}

// GET /tags — list all tags
router.get("/", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const snapshot = await tagsCollection(uid).get();
    const tags = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    res.json({ tags });
  } catch {
    res.status(500).json({ error: "Failed to fetch tags" });
  }
});

// POST /tags — create a tag
router.post("/", validate(CreateTagSchema), async (req: Request, res: Response) => {
  const uid = getUid(res);
  const now = new Date().toISOString();
  try {
    const tagData = {
      ...req.body,
      createdAt: now,
      updatedAt: now,
    };
    const docRef = await tagsCollection(uid).add(tagData);
    res.status(201).json({ id: docRef.id, ...tagData });
  } catch {
    res.status(500).json({ error: "Failed to create tag" });
  }
});

// GET /tags/:id — get a single tag
router.get("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const doc = await tagsCollection(uid).doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Tag not found" });
      return;
    }
    res.json({ id: doc.id, ...doc.data() });
  } catch {
    res.status(500).json({ error: "Failed to fetch tag" });
  }
});

// PUT /tags/:id — update a tag
router.put("/:id", validate(UpdateTagSchema), async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = tagsCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Tag not found" });
      return;
    }
    const updateData = { ...req.body, updatedAt: new Date().toISOString() };
    await docRef.update(updateData);
    res.json({ id: doc.id, ...doc.data(), ...updateData });
  } catch {
    res.status(500).json({ error: "Failed to update tag" });
  }
});

// DELETE /tags/:id — delete a tag
router.delete("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = tagsCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Tag not found" });
      return;
    }
    await docRef.delete();
    res.status(204).send();
  } catch {
    res.status(500).json({ error: "Failed to delete tag" });
  }
});

export default router;
