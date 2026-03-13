import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import {
  CreateNoteSchema,
  UpdateNoteSchema,
  CreateNoteFolderSchema,
  UpdateNoteFolderSchema,
  NoteDoc,
} from "../models/schemas";

const router = Router();

function notesCollection(uid: string) {
  return db.collection("users").doc(uid).collection("notes");
}

function noteFoldersCollection(uid: string) {
  return db.collection("users").doc(uid).collection("noteFolders");
}

// ── Notes ──────────────────────────────────────────

// GET /notes — list all notes
router.get("/", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const snapshot = await notesCollection(uid).orderBy("sortOrder").get();
    const notes = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    res.json({ notes });
  } catch {
    res.status(500).json({ error: "Failed to fetch notes" });
  }
});

// POST /notes — create a note
router.post("/", validate(CreateNoteSchema), async (req: Request, res: Response) => {
  const uid = getUid(res);
  const now = new Date().toISOString();
  try {
    const noteData: Omit<NoteDoc, "id"> = {
      ...req.body,
      createdAt: now,
      updatedAt: now,
    };
    const docRef = await notesCollection(uid).add(noteData);
    res.status(201).json({ id: docRef.id, ...noteData });
  } catch {
    res.status(500).json({ error: "Failed to create note" });
  }
});

// GET /notes/:id — get a single note
router.get("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const doc = await notesCollection(uid).doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Note not found" });
      return;
    }
    res.json({ id: doc.id, ...doc.data() });
  } catch {
    res.status(500).json({ error: "Failed to fetch note" });
  }
});

// PUT /notes/:id — update a note
router.put("/:id", validate(UpdateNoteSchema), async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = notesCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Note not found" });
      return;
    }
    const updateData = { ...req.body, updatedAt: new Date().toISOString() };
    await docRef.update(updateData);
    res.json({ id: doc.id, ...doc.data(), ...updateData });
  } catch {
    res.status(500).json({ error: "Failed to update note" });
  }
});

// DELETE /notes/:id — delete a note
router.delete("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = notesCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Note not found" });
      return;
    }
    await docRef.delete();
    res.status(204).send();
  } catch {
    res.status(500).json({ error: "Failed to delete note" });
  }
});

// ── Note Folders ───────────────────────────────────

// GET /notes/folders/all — list all note folders
router.get("/folders/all", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const snapshot = await noteFoldersCollection(uid).orderBy("sortOrder").get();
    const folders = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    res.json({ folders });
  } catch {
    res.status(500).json({ error: "Failed to fetch note folders" });
  }
});

// POST /notes/folders — create a note folder
router.post("/folders", validate(CreateNoteFolderSchema), async (req: Request, res: Response) => {
  const uid = getUid(res);
  const now = new Date().toISOString();
  try {
    const folderData = {
      ...req.body,
      createdAt: now,
      updatedAt: now,
    };
    const docRef = await noteFoldersCollection(uid).add(folderData);
    res.status(201).json({ id: docRef.id, ...folderData });
  } catch {
    res.status(500).json({ error: "Failed to create note folder" });
  }
});

// PUT /notes/folders/:id — update a note folder
router.put("/folders/:id", validate(UpdateNoteFolderSchema), async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = noteFoldersCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Folder not found" });
      return;
    }
    const updateData = { ...req.body, updatedAt: new Date().toISOString() };
    await docRef.update(updateData);
    res.json({ id: doc.id, ...doc.data(), ...updateData });
  } catch {
    res.status(500).json({ error: "Failed to update note folder" });
  }
});

// DELETE /notes/folders/:id — delete a note folder (moves notes to unfiled)
router.delete("/folders/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const folderId = req.params.id;
    const folderRef = noteFoldersCollection(uid).doc(folderId);
    const folderDoc = await folderRef.get();
    if (!folderDoc.exists) {
      res.status(404).json({ error: "Folder not found" });
      return;
    }

    // Move notes in this folder to unfiled
    const notesInFolder = await notesCollection(uid)
      .where("folderId", "==", folderId)
      .get();
    const batch = db.batch();
    for (const noteDoc of notesInFolder.docs) {
      batch.update(noteDoc.ref, { folderId: null, updatedAt: new Date().toISOString() });
    }
    batch.delete(folderRef);
    await batch.commit();

    res.status(204).send();
  } catch {
    res.status(500).json({ error: "Failed to delete note folder" });
  }
});

export default router;
