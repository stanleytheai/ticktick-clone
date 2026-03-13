import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import {
  CreateFilterSchema,
  UpdateFilterSchema,
  FilterDoc,
} from "../models/schemas";

const router = Router();

function filtersCollection(uid: string) {
  return db.collection("users").doc(uid).collection("filters");
}

// GET /filters — list all filters
router.get("/", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const snapshot = await filtersCollection(uid).orderBy("sortOrder").get();
    const filters = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    res.json({ filters });
  } catch {
    res.status(500).json({ error: "Failed to fetch filters" });
  }
});

// POST /filters — create a filter
router.post("/", validate(CreateFilterSchema), async (req: Request, res: Response) => {
  const uid = getUid(res);
  const now = new Date().toISOString();
  try {
    const filterData: Omit<FilterDoc, "id"> = {
      ...req.body,
      createdAt: now,
      updatedAt: now,
    };
    const docRef = await filtersCollection(uid).add(filterData);
    res.status(201).json({ id: docRef.id, ...filterData });
  } catch {
    res.status(500).json({ error: "Failed to create filter" });
  }
});

// GET /filters/:id — get a single filter
router.get("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const doc = await filtersCollection(uid).doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Filter not found" });
      return;
    }
    res.json({ id: doc.id, ...doc.data() });
  } catch {
    res.status(500).json({ error: "Failed to fetch filter" });
  }
});

// PUT /filters/:id — update a filter
router.put("/:id", validate(UpdateFilterSchema), async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = filtersCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Filter not found" });
      return;
    }
    const updateData = { ...req.body, updatedAt: new Date().toISOString() };
    await docRef.update(updateData);
    res.json({ id: doc.id, ...doc.data(), ...updateData });
  } catch {
    res.status(500).json({ error: "Failed to update filter" });
  }
});

// DELETE /filters/:id — delete a filter
router.delete("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = filtersCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Filter not found" });
      return;
    }
    await docRef.delete();
    res.status(204).send();
  } catch {
    res.status(500).json({ error: "Failed to delete filter" });
  }
});

export default router;
