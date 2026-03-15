import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import { z } from "zod";

const router = Router();

// ── Todoist Import Schema ──────────────────────────────
// Todoist JSON export format
const TodoistProjectSchema = z.object({
  name: z.string(),
  color: z.string().optional(),
  id: z.union([z.string(), z.number()]),
});

const TodoistItemSchema = z.object({
  content: z.string(),
  description: z.string().optional().default(""),
  priority: z.number().optional().default(1), // 1=normal, 2=medium, 3=high, 4=urgent
  due: z.object({
    date: z.string().optional(),
    datetime: z.string().optional(),
    is_recurring: z.boolean().optional(),
  }).nullable().optional(),
  checked: z.union([z.boolean(), z.number()]).optional().default(false),
  project_id: z.union([z.string(), z.number()]).optional(),
  labels: z.array(z.string()).optional().default([]),
});

const TodoistImportSchema = z.object({
  projects: z.array(TodoistProjectSchema).optional().default([]),
  items: z.array(TodoistItemSchema).optional().default([]),
});

// ── Microsoft To Do Import Schema ──────────────────────
// Microsoft To Do CSV-like JSON format
const MsTodoTaskSchema = z.object({
  subject: z.string().optional().default(""),
  "Subject": z.string().optional(),
  body: z.string().optional().default(""),
  "Body": z.string().optional(),
  importance: z.string().optional().default("normal"),
  "Importance": z.string().optional(),
  status: z.string().optional().default("Not started"),
  "Status": z.string().optional(),
  dueDate: z.string().optional(),
  "Due Date": z.string().optional(),
  categories: z.string().optional().default(""),
  "Categories": z.string().optional(),
  listName: z.string().optional().default("Tasks"),
  "List Name": z.string().optional(),
});

const MsTodoImportSchema = z.object({
  tasks: z.array(MsTodoTaskSchema).min(1).max(5000),
});

// ── Apple Reminders Import Schema ──────────────────────
// Simplified ICS-like JSON format (pre-parsed from .ics)
const AppleReminderSchema = z.object({
  summary: z.string().optional().default(""),
  SUMMARY: z.string().optional(),
  description: z.string().optional().default(""),
  DESCRIPTION: z.string().optional(),
  due: z.string().optional(),
  DUE: z.string().optional(),
  priority: z.number().optional().default(0),
  PRIORITY: z.number().optional(),
  completed: z.boolean().optional().default(false),
  STATUS: z.string().optional(),
  categories: z.array(z.string()).optional().default([]),
  CATEGORIES: z.array(z.string()).optional(),
  listName: z.string().optional().default("Reminders"),
});

const AppleRemindersImportSchema = z.object({
  reminders: z.array(AppleReminderSchema).min(1).max(5000),
});

// ── Helpers ────────────────────────────────────────────

function mapTodoistPriority(p: number): "none" | "low" | "medium" | "high" {
  // Todoist: 1=normal, 2=medium, 3=high, 4=urgent
  if (p >= 4) return "high";
  if (p === 3) return "medium";
  if (p === 2) return "low";
  return "none";
}

function mapMsTodoPriority(importance: string): "none" | "low" | "medium" | "high" {
  const lower = importance.toLowerCase();
  if (lower === "high") return "high";
  if (lower === "low") return "low";
  if (lower === "normal") return "medium";
  return "none";
}

function mapApplePriority(p: number): "none" | "low" | "medium" | "high" {
  // Apple: 0=none, 1-4=high, 5=medium, 6-9=low
  if (p === 0) return "none";
  if (p <= 4) return "high";
  if (p === 5) return "medium";
  return "low";
}

function parseDateSafe(dateStr: string | undefined): string | undefined {
  if (!dateStr) return undefined;
  try {
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return undefined;
    return d.toISOString();
  } catch {
    return undefined;
  }
}

async function getOrCreateList(
  uid: string,
  listName: string,
  listCache: Map<string, string>
): Promise<string | undefined> {
  if (!listName || listName === "Inbox") return undefined;

  const cacheKey = listName.toLowerCase();
  if (listCache.has(cacheKey)) return listCache.get(cacheKey)!;

  const userRef = db.collection("users").doc(uid);
  const existing = await userRef
    .collection("lists")
    .where("name", "==", listName)
    .limit(1)
    .get();

  if (!existing.empty) {
    const id = existing.docs[0].id;
    listCache.set(cacheKey, id);
    return id;
  }

  const now = new Date().toISOString();
  const newListRef = userRef.collection("lists").doc();
  await newListRef.set({
    name: listName,
    sortOrder: 0,
    archived: false,
    createdAt: now,
    updatedAt: now,
  });

  listCache.set(cacheKey, newListRef.id);
  return newListRef.id;
}

async function getOrCreateTag(
  uid: string,
  tagName: string,
  tagCache: Map<string, string>
): Promise<string> {
  const cacheKey = tagName.toLowerCase();
  if (tagCache.has(cacheKey)) return tagCache.get(cacheKey)!;

  const userRef = db.collection("users").doc(uid);
  const existing = await userRef
    .collection("tags")
    .where("name", "==", tagName)
    .limit(1)
    .get();

  if (!existing.empty) {
    const name = (existing.docs[0].data().name as string) || tagName;
    tagCache.set(cacheKey, name);
    return name;
  }

  const now = new Date().toISOString();
  await userRef.collection("tags").doc().set({
    name: tagName,
    createdAt: now,
    updatedAt: now,
  });

  tagCache.set(cacheKey, tagName);
  return tagName;
}

// POST /import/todoist - Import from Todoist JSON export
router.post(
  "/todoist",
  validate(TodoistImportSchema),
  async (req: Request, res: Response) => {
    try {
      const uid = getUid(res);
      const { projects, items } = req.body;
      const userRef = db.collection("users").doc(uid);
      const now = new Date().toISOString();
      const listCache = new Map<string, string>();
      const tagCache = new Map<string, string>();

      // Build project ID -> name mapping
      const projectMap = new Map<string, string>();
      for (const proj of projects) {
        projectMap.set(String(proj.id), proj.name);
        // Pre-create lists for projects
        await getOrCreateList(uid, proj.name, listCache);
      }

      // Import tasks in batches
      let imported = 0;
      const batchSize = 100;
      for (let i = 0; i < items.length; i += batchSize) {
        const batch = db.batch();
        const chunk = items.slice(i, i + batchSize);

        for (const item of chunk) {
          const projectName = item.project_id
            ? projectMap.get(String(item.project_id))
            : undefined;
          const listId = projectName
            ? await getOrCreateList(uid, projectName, listCache)
            : undefined;

          // Resolve tags
          const tags: string[] = [];
          for (const label of item.labels || []) {
            tags.push(await getOrCreateTag(uid, label, tagCache));
          }

          const dueDate = item.due
            ? parseDateSafe(item.due.datetime || item.due.date)
            : undefined;

          const isChecked = typeof item.checked === "number"
            ? item.checked === 1
            : !!item.checked;

          const taskRef = userRef.collection("tasks").doc();
          batch.set(taskRef, {
            title: item.content,
            description: item.description || "",
            dueDate: dueDate || null,
            priority: mapTodoistPriority(item.priority || 1),
            tags,
            listId: listId || null,
            completed: isChecked,
            completedAt: isChecked ? now : null,
            sortOrder: imported,
            createdAt: now,
            updatedAt: now,
          });
          imported++;
        }

        await batch.commit();
      }

      res.json({
        message: "Todoist import complete",
        imported: { tasks: imported, lists: listCache.size, tags: tagCache.size },
      });
    } catch (error) {
      res.status(500).json({ error: "Failed to import Todoist data" });
    }
  }
);

// POST /import/microsoft-todo - Import from Microsoft To Do
router.post(
  "/microsoft-todo",
  validate(MsTodoImportSchema),
  async (req: Request, res: Response) => {
    try {
      const uid = getUid(res);
      const { tasks } = req.body;
      const userRef = db.collection("users").doc(uid);
      const now = new Date().toISOString();
      const listCache = new Map<string, string>();
      const tagCache = new Map<string, string>();

      let imported = 0;
      const batchSize = 100;

      for (let i = 0; i < tasks.length; i += batchSize) {
        const batch = db.batch();
        const chunk = tasks.slice(i, i + batchSize);

        for (const task of chunk) {
          const subject = task.subject || task.Subject || "";
          if (!subject) continue;

          const body = task.body || task.Body || "";
          const importance = task.importance || task.Importance || "normal";
          const status = task.status || task.Status || "Not started";
          const dueStr = task.dueDate || task["Due Date"];
          const categories = task.categories || task.Categories || "";
          const listName = task.listName || task["List Name"] || "Tasks";

          const listId = await getOrCreateList(uid, listName, listCache);
          const isCompleted = status.toLowerCase() === "completed";

          // Parse categories as tags
          const tagNames = categories
            .split(",")
            .map((c: string) => c.trim())
            .filter((c: string) => c.length > 0);
          const tags: string[] = [];
          for (const tagName of tagNames) {
            tags.push(await getOrCreateTag(uid, tagName, tagCache));
          }

          const taskRef = userRef.collection("tasks").doc();
          batch.set(taskRef, {
            title: subject,
            description: body,
            dueDate: parseDateSafe(dueStr) || null,
            priority: mapMsTodoPriority(importance),
            tags,
            listId: listId || null,
            completed: isCompleted,
            completedAt: isCompleted ? now : null,
            sortOrder: imported,
            createdAt: now,
            updatedAt: now,
          });
          imported++;
        }

        await batch.commit();
      }

      res.json({
        message: "Microsoft To Do import complete",
        imported: { tasks: imported, lists: listCache.size, tags: tagCache.size },
      });
    } catch (error) {
      res.status(500).json({ error: "Failed to import Microsoft To Do data" });
    }
  }
);

// POST /import/apple-reminders - Import from Apple Reminders
router.post(
  "/apple-reminders",
  validate(AppleRemindersImportSchema),
  async (req: Request, res: Response) => {
    try {
      const uid = getUid(res);
      const { reminders } = req.body;
      const userRef = db.collection("users").doc(uid);
      const now = new Date().toISOString();
      const listCache = new Map<string, string>();
      const tagCache = new Map<string, string>();

      let imported = 0;
      const batchSize = 100;

      for (let i = 0; i < reminders.length; i += batchSize) {
        const batch = db.batch();
        const chunk = reminders.slice(i, i + batchSize);

        for (const reminder of chunk) {
          const summary = reminder.summary || reminder.SUMMARY || "";
          if (!summary) continue;

          const description = reminder.description || reminder.DESCRIPTION || "";
          const dueStr = reminder.due || reminder.DUE;
          const priority = reminder.priority || reminder.PRIORITY || 0;
          const isCompleted =
            reminder.completed || (reminder.STATUS || "").toUpperCase() === "COMPLETED";
          const categories = reminder.categories?.length
            ? reminder.categories
            : reminder.CATEGORIES || [];
          const listName = reminder.listName || "Reminders";

          const listId = await getOrCreateList(uid, listName, listCache);

          const tags: string[] = [];
          for (const cat of categories) {
            tags.push(await getOrCreateTag(uid, cat, tagCache));
          }

          const taskRef = userRef.collection("tasks").doc();
          batch.set(taskRef, {
            title: summary,
            description,
            dueDate: parseDateSafe(dueStr) || null,
            priority: mapApplePriority(priority),
            tags,
            listId: listId || null,
            completed: isCompleted,
            completedAt: isCompleted ? now : null,
            sortOrder: imported,
            createdAt: now,
            updatedAt: now,
          });
          imported++;
        }

        await batch.commit();
      }

      res.json({
        message: "Apple Reminders import complete",
        imported: { tasks: imported, lists: listCache.size, tags: tagCache.size },
      });
    } catch (error) {
      res.status(500).json({ error: "Failed to import Apple Reminders data" });
    }
  }
);

export default router;
