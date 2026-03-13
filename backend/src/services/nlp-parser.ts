import { Priority, RecurrenceRule, RecurrenceFrequency } from "../models/schemas";

export interface ParsedTask {
  title: string; // cleaned title with parsed tokens removed
  dueDate?: string; // ISO datetime
  priority: Priority;
  tags: string[];
  listName?: string; // raw name (caller resolves to listId)
  recurrence?: RecurrenceRule;
}

// Day name → JS day number (0=Sun..6=Sat)
const DAY_MAP: Record<string, number> = {
  sunday: 0,
  sun: 0,
  monday: 1,
  mon: 1,
  tuesday: 2,
  tue: 2,
  tues: 2,
  wednesday: 3,
  wed: 3,
  thursday: 4,
  thu: 4,
  thurs: 4,
  friday: 5,
  fri: 5,
  saturday: 6,
  sat: 6,
};

/**
 * Parse a task title string and extract structured fields.
 *
 * Supported syntax:
 *   Dates/times: "tomorrow", "today", "tonight", "tomorrow at 3pm",
 *                "next Monday", "next week", "in 2 hours", "in 3 days",
 *                "Monday", "Friday at 5pm"
 *   Priority:    "!!" = high, "!" = medium
 *   Tags:        "#work", "#personal"
 *   List:        "/projectname"
 *   Recurrence:  "every day", "every Monday", "daily", "weekly", "monthly",
 *                "every 3 days", "every 2 weeks"
 *
 * @param input  raw task title text
 * @param now    optional reference date for relative calculations (defaults to Date.now())
 * @returns ParsedTask with cleaned title and extracted fields
 */
export function parseTaskInput(input: string, now?: Date): ParsedTask {
  const refDate = now ?? new Date();
  let text = input;
  let dueDate: Date | undefined;
  let priority: Priority = "none";
  const tags: string[] = [];
  let listName: string | undefined;
  let recurrence: RecurrenceRule | undefined;

  // --- Extract tags (#word) ---
  text = text.replace(/#(\w[\w-]*)/g, (_match, tag: string) => {
    tags.push(tag);
    return "";
  });

  // --- Extract list assignment (/listname) ---
  text = text.replace(/\/(\w[\w-]*)/g, (_match, name: string) => {
    listName = name;
    return "";
  });

  // --- Extract priority (!! or !) ---
  // Must check !! before ! to avoid partial match
  if (/\s!!(?:\s|$)/.test(text) || text.startsWith("!! ") || text === "!!") {
    priority = "high";
    text = text.replace(/!!/g, "");
  } else if (/\s!(?:\s|$)/.test(text) || text.startsWith("! ") || text === "!") {
    priority = "medium";
    text = text.replace(/(?<![!])!(?![!])/g, "");
  }

  // --- Extract recurrence (must be before date parsing since "every Monday" contains a day) ---
  const recurrenceResult = parseRecurrence(text);
  if (recurrenceResult) {
    recurrence = recurrenceResult.rule;
    text = recurrenceResult.remaining;
    // If recurrence specifies a day, set the initial due date to the next occurrence
    if (recurrenceResult.initialDay !== undefined && !dueDate) {
      dueDate = getNextDayOfWeek(refDate, recurrenceResult.initialDay);
    }
  }

  // --- Extract date/time ---
  const dateResult = parseDate(text, refDate);
  if (dateResult) {
    dueDate = dateResult.date;
    text = dateResult.remaining;
  }

  // Clean up extra whitespace
  const title = text.replace(/\s+/g, " ").trim();

  const result: ParsedTask = { title, priority, tags };
  if (dueDate) {
    result.dueDate = dueDate.toISOString();
  }
  if (listName) {
    result.listName = listName;
  }
  if (recurrence) {
    result.recurrence = recurrence;
  }
  return result;
}

interface DateParseResult {
  date: Date;
  remaining: string;
}

interface RecurrenceParseResult {
  rule: RecurrenceRule;
  remaining: string;
  initialDay?: number; // day of week for initial due date
}

function parseRecurrence(text: string): RecurrenceParseResult | null {
  let remaining = text;

  // "every N days/weeks/months/years"
  const everyNPattern =
    /\bevery\s+(\d+)\s+(day|days|week|weeks|month|months|year|years)\b/i;
  const everyNMatch = remaining.match(everyNPattern);
  if (everyNMatch) {
    const interval = parseInt(everyNMatch[1], 10);
    const unit = everyNMatch[2].toLowerCase().replace(/s$/, "");
    const freqMap: Record<string, RecurrenceFrequency> = {
      day: "daily",
      week: "weekly",
      month: "monthly",
      year: "yearly",
    };
    remaining = remaining.replace(everyNPattern, "");
    return {
      rule: { frequency: freqMap[unit], interval, afterCompletion: false },
      remaining,
    };
  }

  // "every Monday", "every Tuesday and Thursday", etc.
  const everyDayPattern = /\bevery\s+((?:(?:and|,)\s*)?(?:sun(?:day)?|mon(?:day)?|tue(?:s(?:day)?)?|wed(?:nesday)?|thu(?:rs(?:day)?)?|fri(?:day)?|sat(?:urday)?)(?:\s*(?:,|and)\s*(?:sun(?:day)?|mon(?:day)?|tue(?:s(?:day)?)?|wed(?:nesday)?|thu(?:rs(?:day)?)?|fri(?:day)?|sat(?:urday)?))*)\b/i;
  const everyDayMatch = remaining.match(everyDayPattern);
  if (everyDayMatch) {
    const dayStr = everyDayMatch[1];
    const days = parseDayList(dayStr);
    if (days.length > 0) {
      remaining = remaining.replace(everyDayPattern, "");
      return {
        rule: { frequency: "weekly", interval: 1, daysOfWeek: days, afterCompletion: false },
        remaining,
        initialDay: days[0],
      };
    }
  }

  // "every day" / "daily"
  const dailyPattern = /\b(?:every\s+day|daily)\b/i;
  if (dailyPattern.test(remaining)) {
    remaining = remaining.replace(dailyPattern, "");
    return { rule: { frequency: "daily", interval: 1, afterCompletion: false }, remaining };
  }

  // "weekly"
  const weeklyPattern = /\bweekly\b/i;
  if (weeklyPattern.test(remaining)) {
    remaining = remaining.replace(weeklyPattern, "");
    return { rule: { frequency: "weekly", interval: 1, afterCompletion: false }, remaining };
  }

  // "monthly"
  const monthlyPattern = /\bmonthly\b/i;
  if (monthlyPattern.test(remaining)) {
    remaining = remaining.replace(monthlyPattern, "");
    return { rule: { frequency: "monthly", interval: 1, afterCompletion: false }, remaining };
  }

  // "yearly"
  const yearlyPattern = /\byearly\b/i;
  if (yearlyPattern.test(remaining)) {
    remaining = remaining.replace(yearlyPattern, "");
    return { rule: { frequency: "yearly", interval: 1, afterCompletion: false }, remaining };
  }

  return null;
}

function parseDayList(text: string): number[] {
  const days: number[] = [];
  // Split on comma, "and", or whitespace clusters
  const parts = text.split(/\s*(?:,|and)\s*/i);
  for (const part of parts) {
    const trimmed = part.trim().toLowerCase();
    if (trimmed && DAY_MAP[trimmed] !== undefined) {
      days.push(DAY_MAP[trimmed]);
    }
  }
  return [...new Set(days)].sort((a, b) => a - b);
}

function parseDate(text: string, refDate: Date): DateParseResult | null {
  let remaining = text;

  // "today" / "today at HH:MM" / "today at Hpm"
  const todayPattern = /\btoday(?:\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?)?/i;
  const todayMatch = remaining.match(todayPattern);
  if (todayMatch) {
    const date = new Date(refDate);
    if (todayMatch[1]) {
      applyTime(date, todayMatch[1], todayMatch[2], todayMatch[3]);
    } else {
      date.setHours(23, 59, 0, 0);
    }
    remaining = remaining.replace(todayPattern, "");
    return { date, remaining };
  }

  // "tonight"
  const tonightPattern = /\btonight\b/i;
  const tonightMatch = remaining.match(tonightPattern);
  if (tonightMatch) {
    const date = new Date(refDate);
    date.setHours(21, 0, 0, 0);
    remaining = remaining.replace(tonightPattern, "");
    return { date, remaining };
  }

  // "tomorrow" / "tomorrow at 3pm"
  const tomorrowPattern =
    /\btomorrow(?:\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?)?/i;
  const tomorrowMatch = remaining.match(tomorrowPattern);
  if (tomorrowMatch) {
    const date = new Date(refDate);
    date.setDate(date.getDate() + 1);
    if (tomorrowMatch[1]) {
      applyTime(date, tomorrowMatch[1], tomorrowMatch[2], tomorrowMatch[3]);
    } else {
      date.setHours(23, 59, 0, 0);
    }
    remaining = remaining.replace(tomorrowPattern, "");
    return { date, remaining };
  }

  // "next week" (next Monday)
  const nextWeekPattern = /\bnext\s+week\b/i;
  const nextWeekMatch = remaining.match(nextWeekPattern);
  if (nextWeekMatch) {
    const date = getNextDayOfWeek(refDate, 1); // next Monday
    date.setHours(9, 0, 0, 0);
    remaining = remaining.replace(nextWeekPattern, "");
    return { date, remaining };
  }

  // "next Monday", "next Friday at 5pm"
  const nextDayPattern =
    /\bnext\s+(sunday|sun|monday|mon|tuesday|tue|tues|wednesday|wed|thursday|thu|thurs|friday|fri|saturday|sat)(?:\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?)?\b/i;
  const nextDayMatch = remaining.match(nextDayPattern);
  if (nextDayMatch) {
    const dayName = nextDayMatch[1].toLowerCase();
    const targetDay = DAY_MAP[dayName];
    const date = getNextDayOfWeek(refDate, targetDay, true); // force next week
    if (nextDayMatch[2]) {
      applyTime(date, nextDayMatch[2], nextDayMatch[3], nextDayMatch[4]);
    } else {
      date.setHours(9, 0, 0, 0);
    }
    remaining = remaining.replace(nextDayPattern, "");
    return { date, remaining };
  }

  // "in N hours/minutes/days/weeks"
  const inNPattern =
    /\bin\s+(\d+)\s+(hour|hours|minute|minutes|min|mins|day|days|week|weeks)\b/i;
  const inNMatch = remaining.match(inNPattern);
  if (inNMatch) {
    const n = parseInt(inNMatch[1], 10);
    const unit = inNMatch[2].toLowerCase().replace(/s$/, "");
    const date = new Date(refDate);
    switch (unit) {
      case "hour":
        date.setHours(date.getHours() + n);
        break;
      case "minute":
      case "min":
        date.setMinutes(date.getMinutes() + n);
        break;
      case "day":
        date.setDate(date.getDate() + n);
        break;
      case "week":
        date.setDate(date.getDate() + n * 7);
        break;
    }
    remaining = remaining.replace(inNPattern, "");
    return { date, remaining };
  }

  // Bare day name: "Monday", "Friday at 5pm" (meaning this coming occurrence)
  const bareDayPattern =
    /\b(sunday|sun|monday|mon|tuesday|tue|tues|wednesday|wed|thursday|thu|thurs|friday|fri|saturday|sat)(?:\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?)?\b/i;
  const bareDayMatch = remaining.match(bareDayPattern);
  if (bareDayMatch) {
    const dayName = bareDayMatch[1].toLowerCase();
    const targetDay = DAY_MAP[dayName];
    // Only match if the day name stands on its own (not part of another word)
    const date = getNextDayOfWeek(refDate, targetDay);
    if (bareDayMatch[2]) {
      applyTime(date, bareDayMatch[2], bareDayMatch[3], bareDayMatch[4]);
    } else {
      date.setHours(9, 0, 0, 0);
    }
    remaining = remaining.replace(bareDayPattern, "");
    return { date, remaining };
  }

  return null;
}

function applyTime(
  date: Date,
  hourStr: string,
  minuteStr?: string,
  ampm?: string
): void {
  let hour = parseInt(hourStr, 10);
  const minute = minuteStr ? parseInt(minuteStr, 10) : 0;
  if (ampm) {
    const isPm = ampm.toLowerCase() === "pm";
    if (isPm && hour < 12) hour += 12;
    if (!isPm && hour === 12) hour = 0;
  } else if (hour < 8) {
    // Assume PM for small numbers without explicit am/pm (e.g., "at 3" → 3pm)
    hour += 12;
  }
  date.setHours(hour, minute, 0, 0);
}

function getNextDayOfWeek(
  refDate: Date,
  targetDay: number,
  forceNextWeek = false
): Date {
  const date = new Date(refDate);
  const currentDay = date.getDay();
  let daysAhead = targetDay - currentDay;
  if (daysAhead <= 0 || forceNextWeek) {
    daysAhead += 7;
  }
  if (forceNextWeek && daysAhead <= 7) {
    // "next Monday" when today is Sunday should go to Monday after this week
    // If daysAhead is exactly 7, that's fine (next week's same day)
  }
  date.setDate(date.getDate() + daysAhead);
  return date;
}
