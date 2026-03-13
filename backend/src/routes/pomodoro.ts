import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import {
  StartPomodoroSchema,
  StopPomodoroSchema,
  PomodoroSessionDoc,
} from "../models/schemas";

const router = Router();

function pomodoroCollection(uid: string) {
  return db.collection("users").doc(uid).collection("pomodoroSessions");
}

// POST /pomodoro/start — start a new pomodoro session
router.post(
  "/start",
  validate(StartPomodoroSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    const now = new Date().toISOString();
    try {
      const sessionData: Omit<PomodoroSessionDoc, "id"> = {
        taskId: req.body.taskId,
        sessionType: req.body.sessionType,
        durationMinutes: req.body.durationMinutes,
        startTime: now,
        completed: false,
        ambientSounds: req.body.ambientSounds,
        createdAt: now,
        updatedAt: now,
      };
      const docRef = await pomodoroCollection(uid).add(sessionData);
      res.status(201).json({ id: docRef.id, ...sessionData });
    } catch {
      res.status(500).json({ error: "Failed to start pomodoro session" });
    }
  }
);

// POST /pomodoro/:id/stop — stop/complete a pomodoro session
router.post(
  "/:id/stop",
  validate(StopPomodoroSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    try {
      const docRef = pomodoroCollection(uid).doc(req.params.id);
      const doc = await docRef.get();
      if (!doc.exists) {
        res.status(404).json({ error: "Pomodoro session not found" });
        return;
      }
      const now = new Date().toISOString();
      const updateData = {
        endTime: now,
        completed: req.body.completed ?? true,
        updatedAt: now,
      };
      await docRef.update(updateData);
      res.json({ id: doc.id, ...doc.data(), ...updateData });
    } catch {
      res.status(500).json({ error: "Failed to stop pomodoro session" });
    }
  }
);

// GET /pomodoro/history — get pomodoro session history
router.get("/history", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    let query = pomodoroCollection(uid).orderBy("startTime", "desc");

    // Optional date filtering
    if (req.query.from) {
      query = query.where("startTime", ">=", req.query.from as string);
    }
    if (req.query.to) {
      query = query.where("startTime", "<=", req.query.to as string);
    }

    const limit = Math.min(
      parseInt(req.query.limit as string) || 50,
      200
    );
    query = query.limit(limit);

    const snapshot = await query.get();
    const sessions = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
    res.json({ sessions });
  } catch {
    res.status(500).json({ error: "Failed to fetch pomodoro history" });
  }
});

// GET /pomodoro/stats — get focus statistics
router.get("/stats", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const period = (req.query.period as string) || "daily";
    const now = new Date();
    let startDate: Date;

    switch (period) {
      case "weekly":
        startDate = new Date(now);
        startDate.setDate(now.getDate() - 7);
        break;
      case "monthly":
        startDate = new Date(now);
        startDate.setMonth(now.getMonth() - 1);
        break;
      default: // daily
        startDate = new Date(
          now.getFullYear(),
          now.getMonth(),
          now.getDate()
        );
        break;
    }

    const snapshot = await pomodoroCollection(uid)
      .where("startTime", ">=", startDate.toISOString())
      .where("completed", "==", true)
      .get();

    let totalMinutes = 0;
    let totalSessions = 0;
    const taskMinutes: Record<string, number> = {};

    for (const doc of snapshot.docs) {
      const data = doc.data();
      if (data.sessionType === "work") {
        totalMinutes += data.durationMinutes || 0;
        totalSessions++;
        if (data.taskId) {
          taskMinutes[data.taskId] =
            (taskMinutes[data.taskId] || 0) + (data.durationMinutes || 0);
        }
      }
    }

    // Calculate streak (consecutive days with completed sessions)
    const todayStr = now.toISOString().slice(0, 10);
    const allCompleted = await pomodoroCollection(uid)
      .where("completed", "==", true)
      .where("sessionType", "==", "work")
      .orderBy("startTime", "desc")
      .limit(100)
      .get();

    const daysWithSessions = new Set<string>();
    for (const doc of allCompleted.docs) {
      const data = doc.data();
      daysWithSessions.add(data.startTime.slice(0, 10));
    }

    let streak = 0;
    const checkDate = new Date(now);
    // If no session today, start checking from yesterday
    if (!daysWithSessions.has(todayStr)) {
      checkDate.setDate(checkDate.getDate() - 1);
    }
    while (daysWithSessions.has(checkDate.toISOString().slice(0, 10))) {
      streak++;
      checkDate.setDate(checkDate.getDate() - 1);
    }

    res.json({
      period,
      totalMinutes,
      totalSessions,
      taskMinutes,
      streak,
    });
  } catch {
    res.status(500).json({ error: "Failed to fetch pomodoro stats" });
  }
});

export default router;
