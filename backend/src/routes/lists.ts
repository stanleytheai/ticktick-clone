import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import { CreateListSchema, UpdateListSchema } from "../models/schemas";

const router = Router();

function listsCollection(uid: string) {
  return db.collection("users").doc(uid).collection("lists");
}

// GET /lists — list all lists
router.get("/", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const snapshot = await listsCollection(uid).orderBy("sortOrder").get();
    const lists = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    res.json({ lists });
  } catch {
    res.status(500).json({ error: "Failed to fetch lists" });
  }
});

// POST /lists — create a list
router.post("/", validate(CreateListSchema), async (req: Request, res: Response) => {
  const uid = getUid(res);
  const now = new Date().toISOString();
  try {
    const listData = {
      ...req.body,
      archived: false,
      createdAt: now,
      updatedAt: now,
    };
    const docRef = await listsCollection(uid).add(listData);
    res.status(201).json({ id: docRef.id, ...listData });
  } catch {
    res.status(500).json({ error: "Failed to create list" });
  }
});

// GET /lists/:id — get a single list
router.get("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const doc = await listsCollection(uid).doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "List not found" });
      return;
    }
    res.json({ id: doc.id, ...doc.data() });
  } catch {
    res.status(500).json({ error: "Failed to fetch list" });
  }
});

// PUT /lists/:id — update a list
router.put("/:id", validate(UpdateListSchema), async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = listsCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "List not found" });
      return;
    }
    const updateData = { ...req.body, updatedAt: new Date().toISOString() };
    await docRef.update(updateData);
    res.json({ id: doc.id, ...doc.data(), ...updateData });
  } catch {
    res.status(500).json({ error: "Failed to update list" });
  }
});

// DELETE /lists/:id — delete a list
router.delete("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = listsCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "List not found" });
      return;
    }
    await docRef.delete();
    res.status(204).send();
  } catch {
    res.status(500).json({ error: "Failed to delete list" });
  }
});

export default router;
