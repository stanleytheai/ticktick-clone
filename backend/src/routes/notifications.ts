import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import {
  SnoozeReminderSchema,
  DismissReminderSchema,
  RegisterFcmTokenSchema,
  NotificationDoc,
  Reminder,
} from "../models/schemas";

const router = Router();

function notificationsCollection(uid: string) {
  return db.collection("users").doc(uid).collection("notifications");
}

function tasksCollection(uid: string) {
  return db.collection("users").doc(uid).collection("tasks");
}

// GET /notifications — list all notifications (newest first)
router.get("/", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const limit = Math.min(parseInt(req.query.limit as string) || 50, 100);
    const snapshot = await notificationsCollection(uid)
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();
    const notifications = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
    const unreadCount = notifications.filter(
      (n) => !(n as NotificationDoc).read
    ).length;
    res.json({ notifications, unreadCount });
  } catch {
    res.status(500).json({ error: "Failed to fetch notifications" });
  }
});

// PATCH /notifications/:id/read — mark notification as read
router.patch("/:id/read", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = notificationsCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Notification not found" });
      return;
    }
    await docRef.update({ read: true });
    res.json({ id: doc.id, ...doc.data(), read: true });
  } catch {
    res.status(500).json({ error: "Failed to mark notification as read" });
  }
});

// POST /notifications/read-all — mark all notifications as read
router.post("/read-all", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const snapshot = await notificationsCollection(uid)
      .where("read", "==", false)
      .get();
    if (snapshot.empty) {
      res.json({ updated: 0 });
      return;
    }
    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.update(doc.ref, { read: true });
    }
    await batch.commit();
    res.json({ updated: snapshot.size });
  } catch {
    res.status(500).json({ error: "Failed to mark all as read" });
  }
});

// DELETE /notifications/:id — delete a notification
router.delete("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = notificationsCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Notification not found" });
      return;
    }
    await docRef.delete();
    res.status(204).send();
  } catch {
    res.status(500).json({ error: "Failed to delete notification" });
  }
});

// DELETE /notifications — clear all notifications
router.delete("/", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const snapshot = await notificationsCollection(uid).get();
    if (snapshot.empty) {
      res.json({ deleted: 0 });
      return;
    }
    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    res.json({ deleted: snapshot.size });
  } catch {
    res.status(500).json({ error: "Failed to clear notifications" });
  }
});

// POST /notifications/snooze — snooze a reminder on a task
router.post(
  "/snooze",
  validate(SnoozeReminderSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    try {
      const { reminderId, snoozeDurationMinutes } = req.body;
      // Find the task with this reminder
      const tasksSnap = await tasksCollection(uid).get();
      let found = false;

      for (const taskDoc of tasksSnap.docs) {
        const data = taskDoc.data();
        const reminders: Reminder[] = data.reminders ?? [];
        const idx = reminders.findIndex((r) => r.id === reminderId);
        if (idx === -1) continue;

        const snoozedUntil = new Date(
          Date.now() + snoozeDurationMinutes * 60_000
        ).toISOString();
        reminders[idx] = { ...reminders[idx], snoozedUntil };

        await taskDoc.ref.update({
          reminders,
          updatedAt: new Date().toISOString(),
        });
        found = true;
        res.json({
          taskId: taskDoc.id,
          reminder: reminders[idx],
          snoozedUntil,
        });
        break;
      }

      if (!found) {
        res.status(404).json({ error: "Reminder not found" });
      }
    } catch {
      res.status(500).json({ error: "Failed to snooze reminder" });
    }
  }
);

// POST /notifications/dismiss — dismiss a reminder on a task
router.post(
  "/dismiss",
  validate(DismissReminderSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    try {
      const { reminderId } = req.body;
      const tasksSnap = await tasksCollection(uid).get();
      let found = false;

      for (const taskDoc of tasksSnap.docs) {
        const data = taskDoc.data();
        const reminders: Reminder[] = data.reminders ?? [];
        const idx = reminders.findIndex((r) => r.id === reminderId);
        if (idx === -1) continue;

        reminders[idx] = { ...reminders[idx], dismissed: true };

        await taskDoc.ref.update({
          reminders,
          updatedAt: new Date().toISOString(),
        });
        found = true;
        res.json({ taskId: taskDoc.id, reminder: reminders[idx] });
        break;
      }

      if (!found) {
        res.status(404).json({ error: "Reminder not found" });
      }
    } catch {
      res.status(500).json({ error: "Failed to dismiss reminder" });
    }
  }
);

// POST /notifications/register-token — register FCM token for push notifications
router.post(
  "/register-token",
  validate(RegisterFcmTokenSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    try {
      const { token, platform } = req.body;
      const userRef = db.collection("users").doc(uid);

      // Store token in user's fcmTokens subcollection
      await userRef
        .collection("fcmTokens")
        .doc(token)
        .set({
          token,
          platform,
          updatedAt: new Date().toISOString(),
        });

      res.json({ registered: true });
    } catch {
      res.status(500).json({ error: "Failed to register FCM token" });
    }
  }
);

// POST /notifications/check-reminders — trigger check for due reminders
// This would typically be called by Cloud Scheduler on a cron schedule
router.post("/check-reminders", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const now = new Date();
    const tasksSnap = await tasksCollection(uid)
      .where("completed", "==", false)
      .get();

    const triggered: Array<{ taskId: string; taskTitle: string; reminderId: string }> = [];

    for (const taskDoc of tasksSnap.docs) {
      const data = taskDoc.data();
      const reminders: Reminder[] = data.reminders ?? [];
      let updated = false;

      for (let i = 0; i < reminders.length; i++) {
        const r = reminders[i];
        if (r.dismissed) continue;
        if (r.snoozedUntil && new Date(r.snoozedUntil).getTime() > now.getTime()) continue;
        if (!r.triggerAt) continue;
        if (new Date(r.triggerAt).getTime() > now.getTime()) continue;

        // This reminder is due — create notification
        await notificationsCollection(uid).add({
          type: "reminder",
          title: `Reminder: ${data.title}`,
          body: formatReminderBody(r, data.title),
          taskId: taskDoc.id,
          read: false,
          createdAt: now.toISOString(),
        });

        // Mark as dismissed so it doesn't fire again
        reminders[i] = { ...r, dismissed: true };
        updated = true;
        triggered.push({
          taskId: taskDoc.id,
          taskTitle: data.title,
          reminderId: r.id,
        });
      }

      if (updated) {
        await taskDoc.ref.update({
          reminders,
          updatedAt: now.toISOString(),
        });
      }
    }

    res.json({ triggered, count: triggered.length });
  } catch {
    res.status(500).json({ error: "Failed to check reminders" });
  }
});

function formatReminderBody(reminder: Reminder, taskTitle: string): string {
  switch (reminder.type) {
    case "at_time":
      return `"${taskTitle}" is due now`;
    case "minutes_before":
      return `"${taskTitle}" is due in ${reminder.value} minute${reminder.value !== 1 ? "s" : ""}`;
    case "hours_before":
      return `"${taskTitle}" is due in ${reminder.value} hour${reminder.value !== 1 ? "s" : ""}`;
    case "days_before":
      return `"${taskTitle}" is due in ${reminder.value} day${reminder.value !== 1 ? "s" : ""}`;
  }
}

export default router;
