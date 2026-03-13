import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import {
  ImportDataSchema,
  ExportRequestSchema,
  TaskDoc,
  ListDoc,
  TagDoc,
} from "../models/schemas";
import {
  parseImportData,
  exportToCsv,
  exportToJson,
  exportToText,
} from "../services/import-export";

const router = Router();

function tasksCollection(uid: string) {
  return db.collection("users").doc(uid).collection("tasks");
}

function listsCollection(uid: string) {
  return db.collection("users").doc(uid).collection("lists");
}

function tagsCollection(uid: string) {
  return db.collection("users").doc(uid).collection("tags");
}

// POST /import — import tasks from external service
router.post(
  "/import",
  validate(ImportDataSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    const { source, data } = req.body;

    try {
      const result = parseImportData(source, data);

      if (result.tasks.length === 0) {
        res.status(400).json({
          error: "No tasks found in import data",
          parseErrors: result.errors,
        });
        return;
      }

      const now = new Date().toISOString();

      // Create lists that don't exist yet
      const existingListsSnap = await listsCollection(uid).get();
      const existingLists = new Map(
        existingListsSnap.docs.map((doc) => [
          (doc.data().name as string).toLowerCase(),
          doc.id,
        ])
      );

      const listIdMap = new Map<string, string>();
      let batch = db.batch();
      let batchCount = 0;

      for (const listName of result.lists) {
        const existing = existingLists.get(listName.toLowerCase());
        if (existing) {
          listIdMap.set(listName, existing);
        } else {
          const listRef = listsCollection(uid).doc();
          batch.set(listRef, {
            name: listName,
            sortOrder: existingListsSnap.size + listIdMap.size,
            archived: false,
            createdAt: now,
            updatedAt: now,
          });
          listIdMap.set(listName, listRef.id);
          batchCount++;
        }
      }

      // Create tasks
      const importedTasks: { id: string; title: string }[] = [];
      for (const task of result.tasks) {
        const taskRef = tasksCollection(uid).doc();
        const taskData: Omit<TaskDoc, "id"> = {
          title: task.title,
          description: task.description,
          dueDate: task.dueDate,
          priority: task.priority,
          tags: task.tags,
          listId: task.listName ? listIdMap.get(task.listName) : undefined,
          completed: task.completed,
          completedAt: task.completedAt,
          sortOrder: importedTasks.length,
          createdAt: now,
          updatedAt: now,
        };
        batch.set(taskRef, taskData);
        importedTasks.push({ id: taskRef.id, title: task.title });
        batchCount++;

        // Firestore batch limit is 500 — commit and start new batch
        if (batchCount >= 490) {
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      res.status(201).json({
        imported: {
          tasks: importedTasks.length,
          lists: result.lists.length,
        },
        parseErrors: result.errors,
      });
    } catch {
      res.status(500).json({ error: "Failed to import data" });
    }
  }
);

// POST /export — export tasks to various formats
router.post(
  "/export",
  validate(ExportRequestSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    const { format, listIds, includeCompleted } = req.body;

    try {
      // Fetch tasks
      let query: FirebaseFirestore.Query = tasksCollection(uid);
      if (!includeCompleted) {
        query = query.where("completed", "==", false);
      }
      const tasksSnap = await query.get();
      let tasks = tasksSnap.docs.map(
        (doc) => ({ id: doc.id, ...doc.data() } as TaskDoc)
      );

      // Filter by lists if specified
      if (listIds && listIds.length > 0) {
        const listIdSet = new Set(listIds);
        tasks = tasks.filter((t) => t.listId && listIdSet.has(t.listId));
      }

      // Fetch lists and tags for context
      const [listsSnap, tagsSnap] = await Promise.all([
        listsCollection(uid).get(),
        tagsCollection(uid).get(),
      ]);
      const lists = listsSnap.docs.map(
        (doc) => ({ id: doc.id, ...doc.data() } as ListDoc)
      );
      const tags = tagsSnap.docs.map((doc) => ({
        id: doc.id,
        name: doc.data().name as string,
      }));

      let content: string;
      let contentType: string;
      let filename: string;

      if (format === "csv") {
        content = exportToCsv(tasks, lists);
        contentType = "text/csv";
        filename = "ticktick-export.csv";
      } else if (format === "json") {
        content = exportToJson(tasks, lists, tags);
        contentType = "application/json";
        filename = "ticktick-backup.json";
      } else {
        content = exportToText(tasks, lists);
        contentType = "text/plain";
        filename = "ticktick-export.txt";
      }

      res.setHeader("Content-Type", contentType);
      res.setHeader("Content-Disposition", `attachment; filename="${filename}"`);
      res.send(content);
    } catch {
      res.status(500).json({ error: "Failed to export data" });
    }
  }
);

export default router;
