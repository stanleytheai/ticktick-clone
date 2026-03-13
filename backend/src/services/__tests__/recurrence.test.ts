import {
  calculateNextDueDate,
  shouldCreateNextOccurrence,
} from "../recurrence";
import { RecurrenceRule } from "../../models/schemas";

describe("calculateNextDueDate", () => {
  const base = "2026-03-13T10:00:00.000Z";

  describe("daily", () => {
    it("advances by 1 day with default interval", () => {
      const rule: RecurrenceRule = { frequency: "daily", interval: 1, afterCompletion: false };
      expect(calculateNextDueDate(base, rule)).toBe("2026-03-14T10:00:00.000Z");
    });

    it("advances by N days", () => {
      const rule: RecurrenceRule = { frequency: "daily", interval: 3, afterCompletion: false };
      expect(calculateNextDueDate(base, rule)).toBe("2026-03-16T10:00:00.000Z");
    });
  });

  describe("weekly", () => {
    it("advances by 1 week with no daysOfWeek", () => {
      const rule: RecurrenceRule = { frequency: "weekly", interval: 1, afterCompletion: false };
      expect(calculateNextDueDate(base, rule)).toBe("2026-03-20T10:00:00.000Z");
    });

    it("advances by 2 weeks", () => {
      const rule: RecurrenceRule = { frequency: "weekly", interval: 2, afterCompletion: false };
      expect(calculateNextDueDate(base, rule)).toBe("2026-03-27T10:00:00.000Z");
    });

    it("picks next matching day in same week", () => {
      // 2026-03-13 is a Friday (day 5)
      const rule: RecurrenceRule = {
        frequency: "weekly",
        interval: 1,
        daysOfWeek: [1, 3, 6], // Mon, Wed, Sat
        afterCompletion: false,
      };
      // Next after Friday(5) in [1,3,6] is Saturday(6)
      expect(calculateNextDueDate(base, rule)).toBe("2026-03-14T10:00:00.000Z");
    });

    it("wraps to next week's first matching day", () => {
      // 2026-03-13 is a Friday (day 5)
      const rule: RecurrenceRule = {
        frequency: "weekly",
        interval: 1,
        daysOfWeek: [1, 3], // Mon, Wed
        afterCompletion: false,
      };
      // Next Mon after Friday = 2 days to Sunday + 1 = Monday 2026-03-16
      expect(calculateNextDueDate(base, rule)).toBe("2026-03-16T10:00:00.000Z");
    });
  });

  describe("monthly", () => {
    it("advances by 1 month", () => {
      const rule: RecurrenceRule = { frequency: "monthly", interval: 1, afterCompletion: false };
      expect(calculateNextDueDate(base, rule)).toBe("2026-04-13T10:00:00.000Z");
    });

    it("advances by N months", () => {
      const rule: RecurrenceRule = { frequency: "monthly", interval: 3, afterCompletion: false };
      expect(calculateNextDueDate(base, rule)).toBe("2026-06-13T10:00:00.000Z");
    });

    it("pins to dayOfMonth", () => {
      const rule: RecurrenceRule = {
        frequency: "monthly",
        interval: 1,
        dayOfMonth: 15,
        afterCompletion: false,
      };
      expect(calculateNextDueDate(base, rule)).toBe("2026-04-15T10:00:00.000Z");
    });

    it("clamps dayOfMonth to last day of short month", () => {
      const jan31 = "2026-01-31T10:00:00.000Z";
      const rule: RecurrenceRule = {
        frequency: "monthly",
        interval: 1,
        dayOfMonth: 31,
        afterCompletion: false,
      };
      // February 2026 has 28 days
      expect(calculateNextDueDate(jan31, rule)).toBe("2026-02-28T10:00:00.000Z");
    });
  });

  describe("yearly", () => {
    it("advances by 1 year", () => {
      const rule: RecurrenceRule = { frequency: "yearly", interval: 1, afterCompletion: false };
      expect(calculateNextDueDate(base, rule)).toBe("2027-03-13T10:00:00.000Z");
    });

    it("pins to monthOfYear", () => {
      const rule: RecurrenceRule = {
        frequency: "yearly",
        interval: 1,
        monthOfYear: 6,
        afterCompletion: false,
      };
      expect(calculateNextDueDate(base, rule)).toBe("2027-06-13T10:00:00.000Z");
    });
  });

  describe("endDate", () => {
    it("returns null if next date exceeds endDate", () => {
      const rule: RecurrenceRule = {
        frequency: "daily",
        interval: 1,
        endDate: "2026-03-13T23:59:59.000Z",
        afterCompletion: false,
      };
      expect(calculateNextDueDate(base, rule)).toBeNull();
    });

    it("returns date if within endDate", () => {
      const rule: RecurrenceRule = {
        frequency: "daily",
        interval: 1,
        endDate: "2026-03-15T00:00:00.000Z",
        afterCompletion: false,
      };
      expect(calculateNextDueDate(base, rule)).toBe("2026-03-14T10:00:00.000Z");
    });
  });
});

describe("shouldCreateNextOccurrence", () => {
  it("returns false when nextDate is null", () => {
    const rule: RecurrenceRule = { frequency: "daily", interval: 1, afterCompletion: false };
    expect(shouldCreateNextOccurrence(rule, 0, null)).toBe(false);
  });

  it("returns false when count meets endAfterCount", () => {
    const rule: RecurrenceRule = {
      frequency: "daily",
      interval: 1,
      endAfterCount: 5,
      afterCompletion: false,
    };
    expect(shouldCreateNextOccurrence(rule, 5, "2026-03-14T10:00:00.000Z")).toBe(false);
  });

  it("returns true when count is below endAfterCount", () => {
    const rule: RecurrenceRule = {
      frequency: "daily",
      interval: 1,
      endAfterCount: 5,
      afterCompletion: false,
    };
    expect(shouldCreateNextOccurrence(rule, 4, "2026-03-14T10:00:00.000Z")).toBe(true);
  });

  it("returns false when nextDate exceeds endDate", () => {
    const rule: RecurrenceRule = {
      frequency: "daily",
      interval: 1,
      endDate: "2026-03-13T00:00:00.000Z",
      afterCompletion: false,
    };
    expect(shouldCreateNextOccurrence(rule, 0, "2026-03-14T10:00:00.000Z")).toBe(false);
  });

  it("returns true for valid occurrence", () => {
    const rule: RecurrenceRule = { frequency: "daily", interval: 1, afterCompletion: false };
    expect(shouldCreateNextOccurrence(rule, 0, "2026-03-14T10:00:00.000Z")).toBe(true);
  });
});
