import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import {
  CreateCalendarSyncSchema,
  UpdateCalendarSyncSchema,
  CalendarSyncDoc,
  CalendarEventDoc,
} from "../models/schemas";

const router = Router();

function syncCollection(uid: string) {
  return db.collection("users").doc(uid).collection("calendarSyncs");
}

function eventsCollection(uid: string) {
  return db.collection("users").doc(uid).collection("calendarEvents");
}

// GET /calendar-sync — list all calendar sync configs
router.get("/", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const snapshot = await syncCollection(uid).get();
    const syncs = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
    res.json({ syncs });
  } catch {
    res.status(500).json({ error: "Failed to fetch calendar syncs" });
  }
});

// POST /calendar-sync — create a new calendar sync
router.post(
  "/",
  validate(CreateCalendarSyncSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    const now = new Date().toISOString();
    try {
      // Store tokens securely — in production, encrypt these
      const { accessToken, refreshToken, ...rest } = req.body;

      // Store tokens in a separate secure subcollection
      const syncData: Omit<CalendarSyncDoc, "id"> = {
        ...rest,
        createdAt: now,
        updatedAt: now,
      };
      const docRef = await syncCollection(uid).add(syncData);

      // Store tokens separately
      await db
        .collection("users")
        .doc(uid)
        .collection("calendarTokens")
        .doc(docRef.id)
        .set({
          accessToken,
          refreshToken: refreshToken || null,
          updatedAt: now,
        });

      res.status(201).json({ id: docRef.id, ...syncData });
    } catch {
      res.status(500).json({ error: "Failed to create calendar sync" });
    }
  }
);

// GET /calendar-sync/:id — get a single sync config
router.get("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const doc = await syncCollection(uid).doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Calendar sync not found" });
      return;
    }
    res.json({ id: doc.id, ...doc.data() });
  } catch {
    res.status(500).json({ error: "Failed to fetch calendar sync" });
  }
});

// PUT /calendar-sync/:id — update sync config
router.put(
  "/:id",
  validate(UpdateCalendarSyncSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    try {
      const docRef = syncCollection(uid).doc(req.params.id);
      const doc = await docRef.get();
      if (!doc.exists) {
        res.status(404).json({ error: "Calendar sync not found" });
        return;
      }

      const now = new Date().toISOString();
      const { accessToken, refreshToken, ...rest } = req.body;
      const updateData = { ...rest, updatedAt: now };
      await docRef.update(updateData);

      // Update tokens if provided
      if (accessToken || refreshToken) {
        const tokenUpdate: Record<string, unknown> = { updatedAt: now };
        if (accessToken) tokenUpdate.accessToken = accessToken;
        if (refreshToken) tokenUpdate.refreshToken = refreshToken;
        await db
          .collection("users")
          .doc(uid)
          .collection("calendarTokens")
          .doc(req.params.id)
          .update(tokenUpdate);
      }

      res.json({ id: doc.id, ...doc.data(), ...updateData });
    } catch {
      res.status(500).json({ error: "Failed to update calendar sync" });
    }
  }
);

// DELETE /calendar-sync/:id — delete sync config and events
router.delete("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = syncCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Calendar sync not found" });
      return;
    }

    const syncData = doc.data() as CalendarSyncDoc;
    const batch = db.batch();

    // Delete associated calendar events
    const eventsSnap = await eventsCollection(uid)
      .where("provider", "==", syncData.provider)
      .get();
    for (const eventDoc of eventsSnap.docs) {
      batch.delete(eventDoc.ref);
    }

    // Delete tokens
    batch.delete(
      db
        .collection("users")
        .doc(uid)
        .collection("calendarTokens")
        .doc(req.params.id)
    );

    // Delete sync config
    batch.delete(docRef);
    await batch.commit();

    res.status(204).send();
  } catch {
    res.status(500).json({ error: "Failed to delete calendar sync" });
  }
});

// POST /calendar-sync/:id/sync — trigger a manual sync
router.post("/:id/sync", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = syncCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Calendar sync not found" });
      return;
    }

    const syncData = doc.data() as CalendarSyncDoc;
    if (!syncData.syncEnabled) {
      res.status(400).json({ error: "Sync is disabled for this calendar" });
      return;
    }

    // Update last sync timestamp
    const now = new Date().toISOString();
    await docRef.update({ lastSyncAt: now, updatedAt: now });

    // In a real implementation, this would call the provider's API
    // to fetch/push events. For now, we mark sync as triggered.
    res.json({
      message: "Sync triggered",
      provider: syncData.provider,
      calendarId: syncData.calendarId,
      lastSyncAt: now,
    });
  } catch {
    res.status(500).json({ error: "Failed to trigger calendar sync" });
  }
});

// GET /calendar-sync/events — list synced calendar events
router.get("/events/list", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const { start, end, provider } = req.query;

    let query: FirebaseFirestore.Query = eventsCollection(uid);
    if (provider && typeof provider === "string") {
      query = query.where("provider", "==", provider);
    }
    if (start && typeof start === "string") {
      query = query.where("startTime", ">=", start);
    }
    if (end && typeof end === "string") {
      query = query.where("startTime", "<=", end);
    }

    const snapshot = await query.get();
    const events = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
    res.json({ events });
  } catch {
    res.status(500).json({ error: "Failed to fetch calendar events" });
  }
});

export default router;
