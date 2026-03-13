import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { getTierLimits } from "../middleware/subscription";
import { validate } from "../middleware/validate";
import {
  CreateHabitSchema,
  UpdateHabitSchema,
  CreateHabitLogSchema,
  HabitDoc,
} from "../models/schemas";

const router = Router();

function habitsCollection(uid: string) {
  return db.collection("users").doc(uid).collection("habits");
}

function logsCollection(uid: string, habitId: string) {
  return habitsCollection(uid).doc(habitId).collection("logs");
}

// GET /habits — list all habits
router.get("/", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const snapshot = await habitsCollection(uid).orderBy("sortOrder").get();
    const habits = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    res.json({ habits });
  } catch {
    res.status(500).json({ error: "Failed to fetch habits" });
  }
});

// POST /habits — create a habit
router.post("/", validate(CreateHabitSchema), async (req: Request, res: Response) => {
  const uid = getUid(res);
  const now = new Date().toISOString();
  try {
    // Enforce habit count limit
    const limits = getTierLimits(res);
    if (limits.maxHabits !== Infinity) {
      const snapshot = await habitsCollection(uid)
        .where("archived", "==", false)
        .count()
        .get();
      const count = snapshot.data().count;
      if (count >= limits.maxHabits) {
        res.status(403).json({
          error: "Habit limit reached",
          code: "LIMIT_EXCEEDED",
          limit: limits.maxHabits,
          current: count,
          upgrade: true,
        });
        return;
      }
    }

    const habitData: Omit<HabitDoc, "id"> = {
      ...req.body,
      archived: false,
      createdAt: now,
      updatedAt: now,
    };
    const docRef = await habitsCollection(uid).add(habitData);
    res.status(201).json({ id: docRef.id, ...habitData });
  } catch {
    res.status(500).json({ error: "Failed to create habit" });
  }
});

// GET /habits/:id — get a single habit
router.get("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const doc = await habitsCollection(uid).doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Habit not found" });
      return;
    }
    res.json({ id: doc.id, ...doc.data() });
  } catch {
    res.status(500).json({ error: "Failed to fetch habit" });
  }
});

// PUT /habits/:id — update a habit
router.put("/:id", validate(UpdateHabitSchema), async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = habitsCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Habit not found" });
      return;
    }
    const updateData = { ...req.body, updatedAt: new Date().toISOString() };
    await docRef.update(updateData);
    res.json({ id: doc.id, ...doc.data(), ...updateData });
  } catch {
    res.status(500).json({ error: "Failed to update habit" });
  }
});

// DELETE /habits/:id — delete a habit and its logs
router.delete("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = habitsCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Habit not found" });
      return;
    }
    // Delete all logs subcollection first
    const logs = await logsCollection(uid, req.params.id).get();
    const batch = db.batch();
    for (const logDoc of logs.docs) {
      batch.delete(logDoc.ref);
    }
    batch.delete(docRef);
    await batch.commit();
    res.status(204).send();
  } catch {
    res.status(500).json({ error: "Failed to delete habit" });
  }
});

// POST /habits/:id/log — log a habit completion
router.post("/:id/log", validate(CreateHabitLogSchema), async (req: Request, res: Response) => {
  const uid = getUid(res);
  const habitId = req.params.id;
  try {
    const habitDoc = await habitsCollection(uid).doc(habitId).get();
    if (!habitDoc.exists) {
      res.status(404).json({ error: "Habit not found" });
      return;
    }

    const { date, value, skipped } = req.body;

    // Use date as doc ID so one log per day per habit
    const logRef = logsCollection(uid, habitId).doc(date);
    const existing = await logRef.get();

    const logData = {
      date,
      value,
      skipped,
      createdAt: existing.exists
        ? (existing.data()?.createdAt ?? new Date().toISOString())
        : new Date().toISOString(),
    };
    await logRef.set(logData);
    res.status(201).json({ id: date, ...logData });
  } catch {
    res.status(500).json({ error: "Failed to log habit" });
  }
});

// GET /habits/:id/stats — get habit statistics
router.get("/:id/stats", async (req: Request, res: Response) => {
  const uid = getUid(res);
  const habitId = req.params.id;
  try {
    const habitDoc = await habitsCollection(uid).doc(habitId).get();
    if (!habitDoc.exists) {
      res.status(404).json({ error: "Habit not found" });
      return;
    }
    const habit = habitDoc.data() as Omit<HabitDoc, "id">;

    const logsSnapshot = await logsCollection(uid, habitId)
      .orderBy("date")
      .get();
    const logs = logsSnapshot.docs.map((d) => d.data());

    const completedLogs = logs.filter((l) => !l.skipped && l.value > 0);
    const totalDays = logs.length;
    const completedDays = completedLogs.length;
    const completionRate = totalDays > 0 ? completedDays / totalDays : 0;

    // Calculate streaks
    let currentStreak = 0;
    let longestStreak = 0;
    let tempStreak = 0;

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // Sort dates descending for current streak
    const sortedDates = completedLogs
      .map((l) => l.date as string)
      .sort()
      .reverse();

    if (sortedDates.length > 0) {
      // Check if today or yesterday has a log (streak is active)
      const lastDate = new Date(sortedDates[0]);
      const diffDays = Math.floor(
        (today.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24)
      );

      if (diffDays <= 1) {
        currentStreak = 1;
        for (let i = 1; i < sortedDates.length; i++) {
          const prev = new Date(sortedDates[i - 1]);
          const curr = new Date(sortedDates[i]);
          const gap = Math.floor(
            (prev.getTime() - curr.getTime()) / (1000 * 60 * 60 * 24)
          );
          if (gap === 1) {
            currentStreak++;
          } else {
            break;
          }
        }
      }
    }

    // Longest streak (ascending order)
    const ascending = completedLogs
      .map((l) => l.date as string)
      .sort();

    for (let i = 0; i < ascending.length; i++) {
      if (i === 0) {
        tempStreak = 1;
      } else {
        const prev = new Date(ascending[i - 1]);
        const curr = new Date(ascending[i]);
        const gap = Math.floor(
          (curr.getTime() - prev.getTime()) / (1000 * 60 * 60 * 24)
        );
        if (gap === 1) {
          tempStreak++;
        } else {
          tempStreak = 1;
        }
      }
      longestStreak = Math.max(longestStreak, tempStreak);
    }

    res.json({
      habitId,
      habitName: habit.name,
      totalDays,
      completedDays,
      completionRate: Math.round(completionRate * 100),
      currentStreak,
      longestStreak,
      logs,
    });
  } catch {
    res.status(500).json({ error: "Failed to fetch habit stats" });
  }
});

export default router;
