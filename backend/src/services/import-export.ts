import { ImportSource, TaskDoc, ListDoc } from "../models/schemas";

// Common parsed task structure from imports
interface ParsedTask {
  title: string;
  description?: string;
  dueDate?: string;
  priority: "none" | "low" | "medium" | "high";
  tags: string[];
  listName?: string;
  completed: boolean;
  completedAt?: string;
}

interface ImportResult {
  tasks: ParsedTask[];
  lists: string[]; // unique list names found
  errors: string[];
}

// ---------- Todoist CSV Import ----------

function parseTodoistCsv(data: string): ImportResult {
  const lines = data.split("\n");
  if (lines.length < 2) {
    return { tasks: [], lists: [], errors: ["Empty or invalid CSV"] };
  }

  const headers = parseCsvLine(lines[0]);
  const headerMap = new Map(headers.map((h, i) => [h.toLowerCase().trim(), i]));

  const tasks: ParsedTask[] = [];
  const listNames = new Set<string>();
  const errors: string[] = [];

  for (let i = 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;

    try {
      const cols = parseCsvLine(line);
      const get = (name: string) => {
        const idx = headerMap.get(name);
        return idx !== undefined ? cols[idx]?.trim() : undefined;
      };

      const title = get("content") || get("task name") || get("title");
      if (!title) {
        errors.push(`Line ${i + 1}: missing title`);
        continue;
      }

      const priorityRaw = get("priority");
      const priority = mapTodoistPriority(priorityRaw);
      const dueDate = get("due date") || get("date");
      const listName = get("project") || get("list");
      const status = get("status") || get("completed");
      const completed = status === "completed" || status === "true" || status === "1";
      const description = get("description") || get("notes");

      if (listName) listNames.add(listName);

      tasks.push({
        title,
        description: description || undefined,
        dueDate: dueDate ? normalizeDate(dueDate) : undefined,
        priority,
        tags: [],
        listName: listName || undefined,
        completed,
        completedAt: completed ? new Date().toISOString() : undefined,
      });
    } catch {
      errors.push(`Line ${i + 1}: parse error`);
    }
  }

  return { tasks, lists: Array.from(listNames), errors };
}

function mapTodoistPriority(raw?: string): ParsedTask["priority"] {
  if (!raw) return "none";
  const p = raw.toLowerCase().trim();
  // Todoist uses p1=highest, p4=lowest (inverted from our system)
  if (p === "1" || p === "p1") return "high";
  if (p === "2" || p === "p2") return "medium";
  if (p === "3" || p === "p3") return "low";
  return "none";
}

// ---------- Microsoft To Do Import ----------
// Microsoft To Do exports as plain text or JSON-like lists

function parseMicrosoftTodo(data: string): ImportResult {
  // Try JSON first
  try {
    const json = JSON.parse(data);
    return parseMicrosoftTodoJson(json);
  } catch {
    // Fall back to text-based parsing
    return parseMicrosoftTodoText(data);
  }
}

function parseMicrosoftTodoJson(json: unknown): ImportResult {
  const tasks: ParsedTask[] = [];
  const listNames = new Set<string>();
  const errors: string[] = [];

  if (!Array.isArray(json)) {
    // Might be wrapped in an object
    const obj = json as Record<string, unknown>;
    const items = obj.value || obj.tasks || obj.items;
    if (Array.isArray(items)) {
      return parseMicrosoftTodoJson(items);
    }
    return { tasks: [], lists: [], errors: ["Unexpected JSON structure"] };
  }

  for (const item of json) {
    try {
      const obj = item as Record<string, unknown>;
      const title = (obj.title || obj.subject || obj.displayName) as string;
      if (!title) continue;

      const listName = obj.parentList
        ? ((obj.parentList as Record<string, unknown>).displayName as string)
        : undefined;
      if (listName) listNames.add(listName);

      const status = obj.status as string | undefined;
      const completed = status === "completed" || obj.isCompleted === true;

      const dueDate = obj.dueDateTime
        ? ((obj.dueDateTime as Record<string, unknown>).dateTime as string)
        : (obj.dueDate as string | undefined);

      const importance = obj.importance as string | undefined;
      let priority: ParsedTask["priority"] = "none";
      if (importance === "high") priority = "high";
      else if (importance === "normal") priority = "medium";
      else if (importance === "low") priority = "low";

      const body = obj.body
        ? ((obj.body as Record<string, unknown>).content as string)
        : (obj.note as string | undefined);

      tasks.push({
        title,
        description: body || undefined,
        dueDate: dueDate ? normalizeDate(dueDate) : undefined,
        priority,
        tags: [],
        listName: listName || undefined,
        completed,
        completedAt: completed ? new Date().toISOString() : undefined,
      });
    } catch {
      errors.push("Failed to parse a Microsoft To Do item");
    }
  }

  return { tasks, lists: Array.from(listNames), errors };
}

function parseMicrosoftTodoText(data: string): ImportResult {
  const tasks: ParsedTask[] = [];
  const listNames = new Set<string>();
  const errors: string[] = [];
  let currentList: string | undefined;

  const lines = data.split("\n");
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;

    // Detect list headers (lines ending with ":")
    if (trimmed.endsWith(":") && !trimmed.startsWith("-") && !trimmed.startsWith("[")) {
      currentList = trimmed.slice(0, -1).trim();
      if (currentList) listNames.add(currentList);
      continue;
    }

    // Parse task lines: "- [x] Task title" or "- Task title" or "[ ] Task"
    const taskMatch = trimmed.match(/^[-*]?\s*\[([xX ])\]\s*(.+)$/) ||
                      trimmed.match(/^[-*]\s+(.?)(.+)$/);
    if (taskMatch) {
      const completed = taskMatch[1] === "x" || taskMatch[1] === "X";
      const title = (taskMatch[2] || "").trim();
      if (title) {
        tasks.push({
          title,
          priority: "none",
          tags: [],
          listName: currentList,
          completed,
          completedAt: completed ? new Date().toISOString() : undefined,
        });
      }
    } else {
      // Treat plain text lines as tasks
      tasks.push({
        title: trimmed,
        priority: "none",
        tags: [],
        listName: currentList,
        completed: false,
      });
    }
  }

  if (tasks.length === 0) {
    errors.push("No tasks found in text");
  }

  return { tasks, lists: Array.from(listNames), errors };
}

// ---------- Apple Reminders Import ----------
// Apple Reminders exports as ICS (iCalendar) format

function parseAppleReminders(data: string): ImportResult {
  const tasks: ParsedTask[] = [];
  const listNames = new Set<string>();
  const errors: string[] = [];

  // Parse VTODO components from ICS
  const todoBlocks = data.split("BEGIN:VTODO");
  for (let i = 1; i < todoBlocks.length; i++) {
    const block = todoBlocks[i].split("END:VTODO")[0];
    if (!block) continue;

    try {
      const title = extractIcsField(block, "SUMMARY");
      if (!title) {
        errors.push(`VTODO block ${i}: missing SUMMARY`);
        continue;
      }

      const description = extractIcsField(block, "DESCRIPTION");
      const due = extractIcsField(block, "DUE");
      const status = extractIcsField(block, "STATUS");
      const completed = status === "COMPLETED";
      const completedDate = extractIcsField(block, "COMPLETED");
      const priorityRaw = extractIcsField(block, "PRIORITY");
      const categories = extractIcsField(block, "CATEGORIES");
      const listName = extractIcsField(block, "X-APPLE-CALENDAR");

      if (listName) listNames.add(listName);

      let priority: ParsedTask["priority"] = "none";
      if (priorityRaw) {
        const p = parseInt(priorityRaw, 10);
        // iCal priority: 1-4 = high, 5 = medium, 6-9 = low
        if (p >= 1 && p <= 4) priority = "high";
        else if (p === 5) priority = "medium";
        else if (p >= 6 && p <= 9) priority = "low";
      }

      const tags = categories ? categories.split(",").map((t) => t.trim()) : [];

      tasks.push({
        title,
        description: description ? unescapeIcs(description) : undefined,
        dueDate: due ? normalizeIcsDate(due) : undefined,
        priority,
        tags,
        listName: listName || undefined,
        completed,
        completedAt: completedDate
          ? normalizeIcsDate(completedDate)
          : completed
            ? new Date().toISOString()
            : undefined,
      });
    } catch {
      errors.push(`VTODO block ${i}: parse error`);
    }
  }

  return { tasks, lists: Array.from(listNames), errors };
}

// ---------- Export Functions ----------

export function exportToCsv(tasks: TaskDoc[], lists: ListDoc[]): string {
  const listMap = new Map(lists.map((l) => [l.id, l.name]));
  const headers = [
    "Title",
    "Description",
    "Due Date",
    "Priority",
    "Tags",
    "List",
    "Completed",
    "Created",
  ];
  const rows = [headers.join(",")];

  for (const task of tasks) {
    const row = [
      csvEscape(task.title),
      csvEscape(task.description || ""),
      task.dueDate || "",
      task.priority,
      csvEscape(task.tags.join("; ")),
      csvEscape(task.listId ? (listMap.get(task.listId) || "") : ""),
      task.completed ? "Yes" : "No",
      task.createdAt || "",
    ];
    rows.push(row.join(","));
  }

  return rows.join("\n");
}

export function exportToJson(
  tasks: TaskDoc[],
  lists: ListDoc[],
  tags: { id: string; name: string }[]
): string {
  return JSON.stringify(
    {
      exportedAt: new Date().toISOString(),
      version: "1.0",
      lists,
      tags,
      tasks,
    },
    null,
    2
  );
}

export function exportToText(tasks: TaskDoc[], lists: ListDoc[]): string {
  const listMap = new Map(lists.map((l) => [l.id, l.name]));
  const grouped = new Map<string, TaskDoc[]>();

  for (const task of tasks) {
    const listName = task.listId ? (listMap.get(task.listId) || "Uncategorized") : "Inbox";
    if (!grouped.has(listName)) grouped.set(listName, []);
    grouped.get(listName)!.push(task);
  }

  const lines: string[] = [];
  for (const [listName, listTasks] of grouped) {
    lines.push(`${listName}:`);
    for (const task of listTasks) {
      const checkbox = task.completed ? "[x]" : "[ ]";
      const due = task.dueDate ? ` (due: ${task.dueDate.split("T")[0]})` : "";
      const prio =
        task.priority !== "none" ? ` !${task.priority}` : "";
      lines.push(`  ${checkbox} ${task.title}${prio}${due}`);
    }
    lines.push("");
  }

  return lines.join("\n");
}

// ---------- Main Import Dispatcher ----------

export function parseImportData(source: ImportSource, data: string): ImportResult {
  switch (source) {
    case "todoist":
      return parseTodoistCsv(data);
    case "microsoft_todo":
      return parseMicrosoftTodo(data);
    case "apple_reminders":
      return parseAppleReminders(data);
  }
}

// ---------- Utilities ----------

function parseCsvLine(line: string): string[] {
  const result: string[] = [];
  let current = "";
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (inQuotes) {
      if (ch === '"') {
        if (i + 1 < line.length && line[i + 1] === '"') {
          current += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        current += ch;
      }
    } else {
      if (ch === '"') {
        inQuotes = true;
      } else if (ch === ",") {
        result.push(current);
        current = "";
      } else {
        current += ch;
      }
    }
  }
  result.push(current);
  return result;
}

function csvEscape(value: string): string {
  if (value.includes(",") || value.includes('"') || value.includes("\n")) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

function normalizeDate(dateStr: string): string | undefined {
  try {
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return undefined;
    return d.toISOString();
  } catch {
    return undefined;
  }
}

function extractIcsField(block: string, field: string): string | undefined {
  // Handle folded lines (lines starting with space/tab are continuations)
  const unfolded = block.replace(/\r?\n[ \t]/g, "");
  const regex = new RegExp(`^${field}(?:;[^:]*)?:(.*)$`, "m");
  const match = unfolded.match(regex);
  return match ? match[1].trim() : undefined;
}

function normalizeIcsDate(value: string): string | undefined {
  // Formats: 20240315T120000Z, 20240315, DATE:20240315
  const clean = value.replace(/^(VALUE=DATE(-TIME)?:)/, "");
  try {
    if (clean.length === 8) {
      // YYYYMMDD
      const y = clean.slice(0, 4);
      const m = clean.slice(4, 6);
      const d = clean.slice(6, 8);
      return new Date(`${y}-${m}-${d}`).toISOString();
    }
    // YYYYMMDDTHHmmssZ or YYYYMMDDTHHmmss
    const y = clean.slice(0, 4);
    const m = clean.slice(4, 6);
    const d = clean.slice(6, 8);
    const h = clean.slice(9, 11) || "00";
    const mi = clean.slice(11, 13) || "00";
    const s = clean.slice(13, 15) || "00";
    const iso = `${y}-${m}-${d}T${h}:${mi}:${s}Z`;
    const date = new Date(iso);
    if (isNaN(date.getTime())) return undefined;
    return date.toISOString();
  } catch {
    return undefined;
  }
}

function unescapeIcs(value: string): string {
  return value
    .replace(/\\n/g, "\n")
    .replace(/\\,/g, ",")
    .replace(/\\;/g, ";")
    .replace(/\\\\/g, "\\");
}
