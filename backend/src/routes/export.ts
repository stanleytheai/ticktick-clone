import { Router, Request, Response } from "express";
import { db, auth } from "../config/firebase";
import { getUid } from "../middleware/auth";

const router = Router();

// ── Helpers ────────────────────────────────────────────

function escapeCsv(value: string): string {
  if (value.includes(",") || value.includes('"') || value.includes("\n")) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

function formatDate(iso: string | null | undefined): string {
  if (!iso) return "";
  try {
    return new Date(iso).toISOString().split("T")[0];
  } catch {
    return "";
  }
}

async function gatherAllUserData(uid: string) {
  const userRef = db.collection("users").doc(uid);

  const [
    tasksSnap,
    listsSnap,
    tagsSnap,
    habitsSnap,
    notesSnap,
    filtersSnap,
    pomodoroSnap,
    settingsSnap,
  ] = await Promise.all([
    userRef.collection("tasks").get(),
    userRef.collection("lists").get(),
    userRef.collection("tags").get(),
    userRef.collection("habits").get(),
    userRef.collection("notes").get(),
    userRef.collection("filters").get(),
    userRef.collection("pomodoroSessions").get(),
    userRef.collection("settings").doc("preferences").get(),
  ]);

  // Gather subtasks for each task
  const tasksWithSubtasks = await Promise.all(
    tasksSnap.docs.map(async (taskDoc) => {
      const subtasksSnap = await taskDoc.ref.collection("subtasks").get();
      return {
        ...taskDoc.data(),
        id: taskDoc.id,
        subtasks: subtasksSnap.docs.map((s) => ({ id: s.id, ...s.data() })),
      };
    })
  );

  // Gather habit logs
  const habitsWithLogs = await Promise.all(
    habitsSnap.docs.map(async (habitDoc) => {
      const logsSnap = await habitDoc.ref.collection("logs").get();
      return {
        ...habitDoc.data(),
        id: habitDoc.id,
        logs: logsSnap.docs.map((l) => ({ id: l.id, ...l.data() })),
      };
    })
  );

  return {
    tasks: tasksWithSubtasks,
    lists: listsSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
    tags: tagsSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
    habits: habitsWithLogs,
    notes: notesSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
    filters: filtersSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
    pomodoroSessions: pomodoroSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
    settings: settingsSnap.exists ? settingsSnap.data() : null,
  };
}

// POST /export/json - Full JSON backup
router.post("/json", async (_req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const userRecord = await auth.getUser(uid);
    const data = await gatherAllUserData(uid);

    res.json({
      format: "ticktick-clone-backup",
      version: "1.0",
      exportedAt: new Date().toISOString(),
      profile: {
        email: userRecord.email,
        displayName: userRecord.displayName,
        createdAt: userRecord.metadata.creationTime,
      },
      ...data,
    });
  } catch (error) {
    res.status(500).json({ error: "Failed to export data as JSON" });
  }
});

// POST /export/csv - Export tasks as CSV
router.post("/csv", async (_req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const userRef = db.collection("users").doc(uid);

    const [tasksSnap, listsSnap] = await Promise.all([
      userRef.collection("tasks").get(),
      userRef.collection("lists").get(),
    ]);

    // Build list name lookup
    const listNames = new Map<string, string>();
    for (const doc of listsSnap.docs) {
      listNames.set(doc.id, doc.data().name || "");
    }

    const headers = [
      "Title",
      "Description",
      "List",
      "Priority",
      "Due Date",
      "Start Date",
      "Tags",
      "Completed",
      "Completed At",
      "Created At",
    ];

    const rows: string[] = [headers.join(",")];

    for (const doc of tasksSnap.docs) {
      const t = doc.data();
      const listName = t.listId ? (listNames.get(t.listId) || "") : "";
      const tags = (t.tags || []).join(";");

      rows.push(
        [
          escapeCsv(t.title || ""),
          escapeCsv(t.description || ""),
          escapeCsv(listName),
          t.priority || "none",
          formatDate(t.dueDate),
          formatDate(t.startDate),
          escapeCsv(tags),
          t.completed ? "Yes" : "No",
          formatDate(t.completedAt),
          formatDate(t.createdAt),
        ].join(",")
      );
    }

    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="ticktick-export-${new Date().toISOString().split("T")[0]}.csv"`
    );
    res.send(rows.join("\n"));
  } catch (error) {
    res.status(500).json({ error: "Failed to export data as CSV" });
  }
});

// POST /export/text - Export tasks as plain text
router.post("/text", async (_req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const userRef = db.collection("users").doc(uid);

    const [tasksSnap, listsSnap] = await Promise.all([
      userRef.collection("tasks").get(),
      userRef.collection("lists").get(),
    ]);

    // Build list name lookup
    const listNames = new Map<string, string>();
    for (const doc of listsSnap.docs) {
      listNames.set(doc.id, doc.data().name || "");
    }

    // Group tasks by list
    const tasksByList = new Map<string, Array<Record<string, unknown>>>();
    for (const doc of tasksSnap.docs) {
      const t = doc.data();
      const listName = t.listId ? (listNames.get(t.listId) || "Uncategorized") : "Inbox";
      if (!tasksByList.has(listName)) {
        tasksByList.set(listName, []);
      }
      tasksByList.get(listName)!.push(t);
    }

    const lines: string[] = [
      `TickTick Clone Export - ${new Date().toISOString().split("T")[0]}`,
      "=".repeat(50),
      "",
    ];

    for (const [listName, tasks] of tasksByList) {
      lines.push(`## ${listName}`);
      lines.push("");

      for (const t of tasks) {
        const check = t.completed ? "[x]" : "[ ]";
        const priority =
          t.priority && t.priority !== "none" ? ` !${String(t.priority).charAt(0).toUpperCase()}` : "";
        const due = t.dueDate ? ` (due: ${formatDate(t.dueDate as string)})` : "";
        lines.push(`  ${check} ${t.title}${priority}${due}`);
        if (t.description) {
          lines.push(`      ${t.description}`);
        }
      }

      lines.push("");
    }

    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="ticktick-export-${new Date().toISOString().split("T")[0]}.txt"`
    );
    res.send(lines.join("\n"));
  } catch (error) {
    res.status(500).json({ error: "Failed to export data as text" });
  }
});

export default router;
