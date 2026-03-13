import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";

const router = Router();

function tasksCollection(uid: string) {
  return db.collection("users").doc(uid).collection("tasks");
}

function focusSessionsCollection(uid: string) {
  return db.collection("users").doc(uid).collection("focusSessions");
}

function habitsCollection(uid: string) {
  return db.collection("users").doc(uid).collection("habits");
}

// GET /statistics — aggregated statistics dashboard
router.get("/", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const now = new Date();
    const todayStart = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate()
    ).toISOString();
    const weekStart = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate() - now.getDay() + 1
    ).toISOString();
    const monthStart = new Date(
      now.getFullYear(),
      now.getMonth(),
      1
    ).toISOString();

    // Fetch all tasks
    const tasksSnap = await tasksCollection(uid).get();
    const tasks = tasksSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

    const completed = tasks.filter((t: Record<string, unknown>) => t.completed);
    const incomplete = tasks.filter(
      (t: Record<string, unknown>) => !t.completed
    );

    // Task counts by period
    const completedToday = completed.filter((t: Record<string, unknown>) => {
      const date = (t.completedAt as string) || (t.updatedAt as string);
      return date >= todayStart;
    }).length;

    const completedThisWeek = completed.filter(
      (t: Record<string, unknown>) => {
        const date = (t.completedAt as string) || (t.updatedAt as string);
        return date >= weekStart;
      }
    ).length;

    const completedThisMonth = completed.filter(
      (t: Record<string, unknown>) => {
        const date = (t.completedAt as string) || (t.updatedAt as string);
        return date >= monthStart;
      }
    ).length;

    // Overdue tasks
    const overdueCount = incomplete.filter((t: Record<string, unknown>) => {
      return t.dueDate && (t.dueDate as string) < todayStart;
    }).length;

    // Priority breakdown
    const byPriority: Record<string, number> = {};
    for (const t of completed) {
      const p = (t as Record<string, unknown>).priority as string;
      byPriority[p] = (byPriority[p] || 0) + 1;
    }

    // Fetch focus sessions
    const focusSnap = await focusSessionsCollection(uid).get();
    const sessions = focusSnap.docs.map((d) => d.data());
    const totalFocusMinutes = sessions.reduce(
      (s, sess) => s + ((sess.durationMinutes as number) || 0),
      0
    );

    // Fetch habits
    const habitsSnap = await habitsCollection(uid).get();
    const habitsCount = habitsSnap.size;

    res.json({
      tasks: {
        completedToday,
        completedThisWeek,
        completedThisMonth,
        completedAllTime: completed.length,
        overdueCount,
        totalTasks: tasks.length,
        byPriority,
      },
      focus: {
        totalSessions: sessions.length,
        totalMinutes: totalFocusMinutes,
      },
      habits: {
        totalHabits: habitsCount,
      },
    });
  } catch {
    res.status(500).json({ error: "Failed to fetch statistics" });
  }
});

export default router;
