import {
  computeTriggerAt,
  computeAllTriggerTimes,
  isInQuietHours,
  getDueReminders,
  formatReminderLabel,
} from "../reminder-scheduler";
import { Reminder } from "../../models/schemas";

describe("computeTriggerAt", () => {
  const dueDate = "2026-03-15T14:00:00.000Z";

  test("at_time returns due date", () => {
    const reminder: Reminder = { id: "r1", type: "at_time", value: 0, dismissed: false };
    expect(computeTriggerAt(reminder, dueDate)).toBe(dueDate);
  });

  test("at_time returns null when no due date", () => {
    const reminder: Reminder = { id: "r1", type: "at_time", value: 0, dismissed: false };
    expect(computeTriggerAt(reminder, undefined)).toBeNull();
  });

  test("minutes_before computes correct offset", () => {
    const reminder: Reminder = { id: "r1", type: "minutes_before", value: 30, dismissed: false };
    const result = computeTriggerAt(reminder, dueDate);
    expect(result).toBe("2026-03-15T13:30:00.000Z");
  });

  test("hours_before computes correct offset", () => {
    const reminder: Reminder = { id: "r1", type: "hours_before", value: 2, dismissed: false };
    const result = computeTriggerAt(reminder, dueDate);
    expect(result).toBe("2026-03-15T12:00:00.000Z");
  });

  test("days_before computes correct offset", () => {
    const reminder: Reminder = { id: "r1", type: "days_before", value: 1, dismissed: false };
    const result = computeTriggerAt(reminder, dueDate);
    expect(result).toBe("2026-03-14T14:00:00.000Z");
  });

  test("returns null for offset types without due date", () => {
    const reminder: Reminder = { id: "r1", type: "minutes_before", value: 30, dismissed: false };
    expect(computeTriggerAt(reminder, undefined)).toBeNull();
  });
});

describe("computeAllTriggerTimes", () => {
  test("computes trigger times for multiple reminders", () => {
    const dueDate = "2026-03-15T14:00:00.000Z";
    const reminders: Reminder[] = [
      { id: "r1", type: "at_time", value: 0, dismissed: false },
      { id: "r2", type: "minutes_before", value: 15, dismissed: false },
      { id: "r3", type: "hours_before", value: 1, dismissed: false },
    ];

    const result = computeAllTriggerTimes(reminders, dueDate);
    expect(result).toHaveLength(3);
    expect(result[0].triggerAt).toBe(dueDate);
    expect(result[1].triggerAt).toBe("2026-03-15T13:45:00.000Z");
    expect(result[2].triggerAt).toBe("2026-03-15T13:00:00.000Z");
  });

  test("handles empty reminders array", () => {
    const result = computeAllTriggerTimes([], "2026-03-15T14:00:00.000Z");
    expect(result).toEqual([]);
  });

  test("handles undefined due date", () => {
    const reminders: Reminder[] = [
      { id: "r1", type: "minutes_before", value: 30, dismissed: false },
    ];
    const result = computeAllTriggerTimes(reminders, undefined);
    expect(result[0].triggerAt).toBeUndefined();
  });
});

describe("isInQuietHours", () => {
  test("returns false when disabled", () => {
    expect(
      isInQuietHours(new Date("2026-03-15T23:00:00"), false, "22:00", "07:00")
    ).toBe(false);
  });

  test("detects quiet hours crossing midnight", () => {
    // 23:00 is between 22:00 and 07:00
    expect(
      isInQuietHours(new Date("2026-03-15T23:00:00"), true, "22:00", "07:00")
    ).toBe(true);
  });

  test("detects quiet hours before midnight", () => {
    expect(
      isInQuietHours(new Date("2026-03-15T22:30:00"), true, "22:00", "07:00")
    ).toBe(true);
  });

  test("detects quiet hours after midnight", () => {
    expect(
      isInQuietHours(new Date("2026-03-15T03:00:00"), true, "22:00", "07:00")
    ).toBe(true);
  });

  test("returns false outside quiet hours", () => {
    expect(
      isInQuietHours(new Date("2026-03-15T12:00:00"), true, "22:00", "07:00")
    ).toBe(false);
  });

  test("handles same-day range", () => {
    expect(
      isInQuietHours(new Date("2026-03-15T10:00:00"), true, "08:00", "18:00")
    ).toBe(true);
  });

  test("returns false outside same-day range", () => {
    expect(
      isInQuietHours(new Date("2026-03-15T20:00:00"), true, "08:00", "18:00")
    ).toBe(false);
  });
});

describe("getDueReminders", () => {
  const now = new Date("2026-03-15T14:00:00.000Z");

  test("returns reminders with passed trigger time", () => {
    const reminders: Reminder[] = [
      {
        id: "r1",
        type: "at_time",
        value: 0,
        triggerAt: "2026-03-15T13:00:00.000Z",
        dismissed: false,
      },
    ];
    expect(getDueReminders(reminders, now)).toHaveLength(1);
  });

  test("excludes dismissed reminders", () => {
    const reminders: Reminder[] = [
      {
        id: "r1",
        type: "at_time",
        value: 0,
        triggerAt: "2026-03-15T13:00:00.000Z",
        dismissed: true,
      },
    ];
    expect(getDueReminders(reminders, now)).toHaveLength(0);
  });

  test("excludes snoozed reminders", () => {
    const reminders: Reminder[] = [
      {
        id: "r1",
        type: "at_time",
        value: 0,
        triggerAt: "2026-03-15T13:00:00.000Z",
        snoozedUntil: "2026-03-15T15:00:00.000Z",
        dismissed: false,
      },
    ];
    expect(getDueReminders(reminders, now)).toHaveLength(0);
  });

  test("includes reminders past snooze time", () => {
    const reminders: Reminder[] = [
      {
        id: "r1",
        type: "at_time",
        value: 0,
        triggerAt: "2026-03-15T13:00:00.000Z",
        snoozedUntil: "2026-03-15T13:30:00.000Z",
        dismissed: false,
      },
    ];
    expect(getDueReminders(reminders, now)).toHaveLength(1);
  });

  test("excludes future reminders", () => {
    const reminders: Reminder[] = [
      {
        id: "r1",
        type: "at_time",
        value: 0,
        triggerAt: "2026-03-15T15:00:00.000Z",
        dismissed: false,
      },
    ];
    expect(getDueReminders(reminders, now)).toHaveLength(0);
  });

  test("excludes reminders with no trigger time", () => {
    const reminders: Reminder[] = [
      { id: "r1", type: "at_time", value: 0, dismissed: false },
    ];
    expect(getDueReminders(reminders, now)).toHaveLength(0);
  });
});

describe("formatReminderLabel", () => {
  test("at_time", () => {
    expect(
      formatReminderLabel({ id: "r1", type: "at_time", value: 0, dismissed: false })
    ).toBe("At due time");
  });

  test("minutes_before singular", () => {
    expect(
      formatReminderLabel({
        id: "r1",
        type: "minutes_before",
        value: 1,
        dismissed: false,
      })
    ).toBe("1 minute before");
  });

  test("minutes_before plural", () => {
    expect(
      formatReminderLabel({
        id: "r1",
        type: "minutes_before",
        value: 30,
        dismissed: false,
      })
    ).toBe("30 minutes before");
  });

  test("hours_before", () => {
    expect(
      formatReminderLabel({
        id: "r1",
        type: "hours_before",
        value: 2,
        dismissed: false,
      })
    ).toBe("2 hours before");
  });

  test("days_before", () => {
    expect(
      formatReminderLabel({
        id: "r1",
        type: "days_before",
        value: 1,
        dismissed: false,
      })
    ).toBe("1 day before");
  });
});
