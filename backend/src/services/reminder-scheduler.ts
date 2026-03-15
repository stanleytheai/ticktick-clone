import { Reminder, ReminderType } from "../models/schemas";

/**
 * Compute the absolute trigger time for a reminder based on task due date.
 */
export function computeTriggerAt(
  reminder: Reminder,
  dueDate: string | undefined
): string | null {
  if (reminder.type === "at_time") {
    // value is ignored; trigger at due date itself
    return dueDate ?? null;
  }

  if (!dueDate) return null;

  const due = new Date(dueDate);
  const offsetMinutes = getOffsetMinutes(reminder.type, reminder.value);
  const triggerTime = new Date(due.getTime() - offsetMinutes * 60_000);
  return triggerTime.toISOString();
}

function getOffsetMinutes(type: ReminderType, value: number): number {
  switch (type) {
    case "minutes_before":
      return value;
    case "hours_before":
      return value * 60;
    case "days_before":
      return value * 1440;
    case "at_time":
      return 0;
  }
}

/**
 * Compute trigger times for all reminders on a task.
 * Returns reminders with triggerAt populated.
 */
export function computeAllTriggerTimes(
  reminders: Reminder[],
  dueDate: string | undefined
): Reminder[] {
  return reminders.map((r) => ({
    ...r,
    triggerAt: computeTriggerAt(r, dueDate) ?? undefined,
  }));
}

/**
 * Check if current time falls within quiet hours.
 */
export function isInQuietHours(
  now: Date,
  enabled: boolean,
  start: string, // "HH:mm"
  end: string // "HH:mm"
): boolean {
  if (!enabled) return false;

  const [startH, startM] = start.split(":").map(Number);
  const [endH, endM] = end.split(":").map(Number);
  const currentMinutes = now.getHours() * 60 + now.getMinutes();
  const startMinutes = startH * 60 + startM;
  const endMinutes = endH * 60 + endM;

  if (startMinutes <= endMinutes) {
    // Same day range (e.g. 08:00 - 22:00)
    return currentMinutes >= startMinutes && currentMinutes < endMinutes;
  } else {
    // Crosses midnight (e.g. 22:00 - 07:00)
    return currentMinutes >= startMinutes || currentMinutes < endMinutes;
  }
}

/**
 * Get reminders that are due to fire now (trigger time has passed, not dismissed, not snoozed).
 */
export function getDueReminders(
  reminders: Reminder[],
  now: Date
): Reminder[] {
  const nowMs = now.getTime();
  return reminders.filter((r) => {
    if (r.dismissed) return false;
    if (r.snoozedUntil && new Date(r.snoozedUntil).getTime() > nowMs) {
      return false;
    }
    if (!r.triggerAt) return false;
    return new Date(r.triggerAt).getTime() <= nowMs;
  });
}

/**
 * Format a reminder for display text.
 */
export function formatReminderLabel(reminder: Reminder): string {
  switch (reminder.type) {
    case "at_time":
      return "At due time";
    case "minutes_before":
      return `${reminder.value} minute${reminder.value !== 1 ? "s" : ""} before`;
    case "hours_before":
      return `${reminder.value} hour${reminder.value !== 1 ? "s" : ""} before`;
    case "days_before":
      return `${reminder.value} day${reminder.value !== 1 ? "s" : ""} before`;
  }
}
