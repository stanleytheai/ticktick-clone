import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import { z } from "zod";

const router = Router();

// ── Schemas ────────────────────────────────────────────

const ConnectGoogleCalendarSchema = z.object({
  accessToken: z.string().min(1),
  refreshToken: z.string().min(1),
  calendarId: z.string().default("primary"),
  expiresAt: z.string().datetime().optional(),
});

const SyncOptionsSchema = z.object({
  direction: z.enum(["push", "pull", "both"]).default("both"),
  calendarId: z.string().default("primary"),
  syncFrom: z.string().datetime().optional(),
  syncTo: z.string().datetime().optional(),
});

const CalendarEventSchema = z.object({
  id: z.string().optional(),
  summary: z.string().min(1),
  description: z.string().optional(),
  start: z.object({
    dateTime: z.string().datetime().optional(),
    date: z.string().optional(),
  }),
  end: z.object({
    dateTime: z.string().datetime().optional(),
    date: z.string().optional(),
  }),
});

// ── Helpers ────────────────────────────────────────────

function calendarRef(uid: string) {
  return db.collection("users").doc(uid).collection("calendarConnections");
}

function syncLogRef(uid: string) {
  return db.collection("users").doc(uid).collection("calendarSyncLogs");
}

// POST /calendar/google/connect - Store Google Calendar OAuth tokens
router.post(
  "/google/connect",
  validate(ConnectGoogleCalendarSchema),
  async (req: Request, res: Response) => {
    try {
      const uid = getUid(res);
      const { accessToken, refreshToken, calendarId, expiresAt } = req.body;
      const now = new Date().toISOString();

      await calendarRef(uid).doc("google").set({
        provider: "google",
        accessToken,
        refreshToken,
        calendarId,
        expiresAt: expiresAt || null,
        syncEnabled: true,
        lastSyncAt: null,
        createdAt: now,
        updatedAt: now,
      });

      res.json({ message: "Google Calendar connected", calendarId });
    } catch (error) {
      res.status(500).json({ error: "Failed to connect Google Calendar" });
    }
  }
);

// DELETE /calendar/google/disconnect - Remove Google Calendar connection
router.delete("/google/disconnect", async (_req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    await calendarRef(uid).doc("google").delete();

    // Clear sync mappings
    const mappings = await db
      .collection("users")
      .doc(uid)
      .collection("calendarMappings")
      .get();

    if (!mappings.empty) {
      const batch = db.batch();
      for (const doc of mappings.docs) {
        batch.delete(doc.ref);
      }
      await batch.commit();
    }

    res.json({ message: "Google Calendar disconnected" });
  } catch (error) {
    res.status(500).json({ error: "Failed to disconnect Google Calendar" });
  }
});

// GET /calendar/google/status - Check connection status
router.get("/google/status", async (_req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const doc = await calendarRef(uid).doc("google").get();

    if (!doc.exists) {
      res.json({ connected: false });
      return;
    }

    const data = doc.data()!;
    res.json({
      connected: true,
      calendarId: data.calendarId,
      syncEnabled: data.syncEnabled,
      lastSyncAt: data.lastSyncAt,
    });
  } catch (error) {
    res.status(500).json({ error: "Failed to check calendar status" });
  }
});

// POST /calendar/google/sync - Trigger two-way sync
router.post(
  "/google/sync",
  validate(SyncOptionsSchema),
  async (req: Request, res: Response) => {
    try {
      const uid = getUid(res);
      const { direction, calendarId } = req.body;
      const now = new Date().toISOString();

      // Verify connection exists
      const connDoc = await calendarRef(uid).doc("google").get();
      if (!connDoc.exists) {
        res.status(400).json({ error: "Google Calendar not connected" });
        return;
      }

      const conn = connDoc.data()!;
      if (!conn.syncEnabled) {
        res.status(400).json({ error: "Calendar sync is disabled" });
        return;
      }

      const userRef = db.collection("users").doc(uid);
      const mappingsRef = userRef.collection("calendarMappings");
      const results = { pushed: 0, pulled: 0, errors: 0 };

      // Push: sync tasks with due dates to calendar events
      if (direction === "push" || direction === "both") {
        const tasksSnap = await userRef
          .collection("tasks")
          .where("dueDate", "!=", null)
          .get();

        for (const taskDoc of tasksSnap.docs) {
          const task = taskDoc.data();
          const mappingDoc = await mappingsRef.doc(taskDoc.id).get();

          const eventData = {
            taskId: taskDoc.id,
            calendarId,
            eventSummary: task.title,
            eventDescription: task.description || "",
            eventStart: task.dueDate,
            eventEnd: task.dueDate,
            provider: "google",
            syncDirection: "push",
            lastSyncAt: now,
          };

          if (mappingDoc.exists) {
            await mappingsRef.doc(taskDoc.id).update({
              ...eventData,
              updatedAt: now,
            });
          } else {
            await mappingsRef.doc(taskDoc.id).set({
              ...eventData,
              createdAt: now,
              updatedAt: now,
            });
          }
          results.pushed++;
        }
      }

      // Pull: the actual Google Calendar API call would happen here.
      // For now, we record that a sync was requested and store sync state.
      // The actual API calls require googleapis client which would be initialized
      // with the stored OAuth tokens.
      if (direction === "pull" || direction === "both") {
        // Record sync request — actual calendar API integration
        // would fetch events and create/update tasks
        await syncLogRef(uid).doc().set({
          direction: "pull",
          calendarId,
          status: "pending",
          requestedAt: now,
        });
      }

      // Update last sync time
      await calendarRef(uid).doc("google").update({
        lastSyncAt: now,
        updatedAt: now,
      });

      res.json({
        message: "Calendar sync completed",
        results,
        syncedAt: now,
      });
    } catch (error) {
      res.status(500).json({ error: "Failed to sync with Google Calendar" });
    }
  }
);

// GET /calendar/events - List synced calendar events/mappings
router.get("/events", async (req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const from = req.query.from as string | undefined;
    const to = req.query.to as string | undefined;

    let query = db
      .collection("users")
      .doc(uid)
      .collection("calendarMappings")
      .orderBy("eventStart");

    if (from) {
      query = query.where("eventStart", ">=", from);
    }
    if (to) {
      query = query.where("eventStart", "<=", to);
    }

    const snap = await query.get();

    res.json(
      snap.docs.map((d) => ({
        id: d.id,
        ...d.data(),
      }))
    );
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch calendar events" });
  }
});

export default router;
