import { RecurrenceRule } from "../models/schemas";

/**
 * Calculate the next due date based on a recurrence rule.
 * All arithmetic uses UTC methods to avoid DST issues.
 *
 * @param baseDate - The date to calculate from (due date or completion date)
 * @param rule - The recurrence rule
 * @returns The next due date as ISO string, or null if recurrence has ended
 */
export function calculateNextDueDate(
  baseDate: string,
  rule: RecurrenceRule
): string | null {
  const date = new Date(baseDate);
  const interval = rule.interval ?? 1;

  switch (rule.frequency) {
    case "daily":
      date.setUTCDate(date.getUTCDate() + interval);
      break;

    case "weekly":
      if (rule.daysOfWeek && rule.daysOfWeek.length > 0) {
        advanceToNextDayOfWeek(date, rule.daysOfWeek, interval);
      } else {
        date.setUTCDate(date.getUTCDate() + 7 * interval);
      }
      break;

    case "monthly":
      if (rule.dayOfMonth) {
        advanceMonth(date, interval, rule.dayOfMonth);
      } else {
        advanceMonth(date, interval, date.getUTCDate());
      }
      break;

    case "yearly":
      if (rule.monthOfYear) {
        date.setUTCFullYear(date.getUTCFullYear() + interval);
        date.setUTCMonth(rule.monthOfYear - 1); // 1-indexed to 0-indexed
      } else {
        date.setUTCFullYear(date.getUTCFullYear() + interval);
      }
      break;
  }

  // Check end date
  if (rule.endDate && date.toISOString() > rule.endDate) {
    return null;
  }

  return date.toISOString();
}

/**
 * Advance to the next matching day of week (UTC). If the current week has
 * remaining matching days, pick the next one. Otherwise, skip `interval` weeks
 * and pick the first matching day.
 */
function advanceToNextDayOfWeek(
  date: Date,
  daysOfWeek: number[],
  interval: number
): void {
  const sorted = [...daysOfWeek].sort((a, b) => a - b);
  const currentDay = date.getUTCDay();

  // Find the next day in the current week
  const nextInWeek = sorted.find((d) => d > currentDay);
  if (nextInWeek !== undefined) {
    date.setUTCDate(date.getUTCDate() + (nextInWeek - currentDay));
  } else {
    // Jump to the first day of the next interval-th week
    const daysUntilNextWeek = 7 - currentDay + sorted[0];
    const extraWeeks = (interval - 1) * 7;
    date.setUTCDate(date.getUTCDate() + daysUntilNextWeek + extraWeeks);
  }
}

/**
 * Advance by N months in UTC, pinning to a specific day. If the target month
 * has fewer days, clamp to the last day of that month.
 */
function advanceMonth(date: Date, interval: number, dayOfMonth: number): void {
  // Set to day 1 first to avoid month overflow (e.g. Jan 31 -> Feb 31 = Mar 3)
  date.setUTCDate(1);
  date.setUTCMonth(date.getUTCMonth() + interval);
  const maxDay = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 0)
  ).getUTCDate();
  date.setUTCDate(Math.min(dayOfMonth, maxDay));
}

/**
 * Check whether a recurring task should generate another occurrence.
 *
 * @param rule - The recurrence rule
 * @param currentCount - How many occurrences have been created so far
 * @param nextDate - The calculated next due date
 * @returns true if a new occurrence should be created
 */
export function shouldCreateNextOccurrence(
  rule: RecurrenceRule,
  currentCount: number,
  nextDate: string | null
): boolean {
  if (nextDate === null) return false;
  if (rule.endAfterCount && currentCount >= rule.endAfterCount) return false;
  if (rule.endDate && nextDate > rule.endDate) return false;
  return true;
}
