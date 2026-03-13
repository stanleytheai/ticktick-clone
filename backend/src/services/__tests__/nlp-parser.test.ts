import { parseTaskInput, ParsedTask } from "../nlp-parser";

// Fixed reference date: Wednesday 2026-03-11 10:00 AM local time
const REF = new Date(2026, 2, 11, 10, 0, 0, 0); // Month is 0-indexed

describe("parseTaskInput", () => {
  describe("basic title passthrough", () => {
    it("returns the title unchanged when no tokens present", () => {
      const result = parseTaskInput("Buy groceries", REF);
      expect(result.title).toBe("Buy groceries");
      expect(result.priority).toBe("none");
      expect(result.tags).toEqual([]);
      expect(result.dueDate).toBeUndefined();
      expect(result.listName).toBeUndefined();
      expect(result.recurrence).toBeUndefined();
    });
  });

  describe("priority parsing", () => {
    it("parses !! as high priority", () => {
      const result = parseTaskInput("Fix bug !! urgently", REF);
      expect(result.priority).toBe("high");
      expect(result.title).toBe("Fix bug urgently");
    });

    it("parses ! as medium priority", () => {
      const result = parseTaskInput("Review PR ! soon", REF);
      expect(result.priority).toBe("medium");
      expect(result.title).toBe("Review PR soon");
    });

    it("does not parse ! inside words (URLs etc)", () => {
      const result = parseTaskInput("Check site.com/path", REF);
      expect(result.priority).toBe("none");
    });

    it("handles !! at start of string", () => {
      const result = parseTaskInput("!! Critical fix", REF);
      expect(result.priority).toBe("high");
      expect(result.title).toBe("Critical fix");
    });
  });

  describe("tag parsing", () => {
    it("extracts single tag", () => {
      const result = parseTaskInput("Write report #work", REF);
      expect(result.tags).toEqual(["work"]);
      expect(result.title).toBe("Write report");
    });

    it("extracts multiple tags", () => {
      const result = parseTaskInput("#urgent Review #work docs #q1", REF);
      expect(result.tags).toEqual(["urgent", "work", "q1"]);
      expect(result.title).toBe("Review docs");
    });

    it("handles hyphenated tags", () => {
      const result = parseTaskInput("Task #follow-up", REF);
      expect(result.tags).toEqual(["follow-up"]);
    });
  });

  describe("list assignment", () => {
    it("extracts /listname", () => {
      const result = parseTaskInput("Call dentist /personal", REF);
      expect(result.listName).toBe("personal");
      expect(result.title).toBe("Call dentist");
    });

    it("last /list wins when multiple present", () => {
      const result = parseTaskInput("Task /work /personal", REF);
      expect(result.listName).toBe("personal");
    });
  });

  describe("date parsing — today/tomorrow/tonight", () => {
    it("parses 'today'", () => {
      const result = parseTaskInput("Do laundry today", REF);
      expect(result.dueDate).toBeDefined();
      const due = new Date(result.dueDate!);
      expect(due.getFullYear()).toBe(2026);
      expect(due.getMonth()).toBe(2); // March
      expect(due.getDate()).toBe(11);
      expect(result.title).toBe("Do laundry");
    });

    it("parses 'today at 3pm'", () => {
      const result = parseTaskInput("Meeting today at 3pm", REF);
      const due = new Date(result.dueDate!);
      expect(due.getDate()).toBe(11);
      expect(due.getHours()).toBe(15);
      expect(due.getMinutes()).toBe(0);
      expect(result.title).toBe("Meeting");
    });

    it("parses 'tonight'", () => {
      const result = parseTaskInput("Read book tonight", REF);
      const due = new Date(result.dueDate!);
      expect(due.getDate()).toBe(11);
      expect(due.getHours()).toBe(21);
    });

    it("parses 'tomorrow'", () => {
      const result = parseTaskInput("Dentist tomorrow", REF);
      const due = new Date(result.dueDate!);
      expect(due.getDate()).toBe(12);
    });

    it("parses 'tomorrow at 2pm'", () => {
      const result = parseTaskInput("Meeting tomorrow at 2pm", REF);
      const due = new Date(result.dueDate!);
      expect(due.getDate()).toBe(12);
      expect(due.getHours()).toBe(14);
      expect(result.title).toBe("Meeting");
    });

    it("parses 'tomorrow at 9am'", () => {
      const result = parseTaskInput("Standup tomorrow at 9am", REF);
      const due = new Date(result.dueDate!);
      expect(due.getHours()).toBe(9);
    });

    it("parses 'tomorrow at 10:30'", () => {
      const result = parseTaskInput("Call tomorrow at 10:30", REF);
      const due = new Date(result.dueDate!);
      expect(due.getHours()).toBe(10);
      expect(due.getMinutes()).toBe(30);
    });
  });

  describe("date parsing — relative", () => {
    it("parses 'in 2 hours'", () => {
      const result = parseTaskInput("Check results in 2 hours", REF);
      const due = new Date(result.dueDate!);
      expect(due.getHours()).toBe(12);
      expect(result.title).toBe("Check results");
    });

    it("parses 'in 30 minutes'", () => {
      const result = parseTaskInput("Take pill in 30 minutes", REF);
      const due = new Date(result.dueDate!);
      expect(due.getMinutes()).toBe(30);
    });

    it("parses 'in 3 days'", () => {
      const result = parseTaskInput("Follow up in 3 days", REF);
      const due = new Date(result.dueDate!);
      expect(due.getDate()).toBe(14);
    });

    it("parses 'in 2 weeks'", () => {
      const result = parseTaskInput("Review in 2 weeks", REF);
      const due = new Date(result.dueDate!);
      expect(due.getDate()).toBe(25);
    });
  });

  describe("date parsing — day names", () => {
    // REF is Wednesday March 11, 2026
    it("parses 'Friday' as this coming Friday", () => {
      const result = parseTaskInput("Submit report Friday", REF);
      const due = new Date(result.dueDate!);
      expect(due.getDay()).toBe(5); // Friday
      expect(due.getDate()).toBe(13); // March 13
    });

    it("parses 'Monday' as next Monday (since today is Wed)", () => {
      const result = parseTaskInput("Meeting Monday", REF);
      const due = new Date(result.dueDate!);
      expect(due.getDay()).toBe(1); // Monday
      expect(due.getDate()).toBe(16); // March 16
    });

    it("parses 'next Monday'", () => {
      const result = parseTaskInput("Planning next Monday", REF);
      const due = new Date(result.dueDate!);
      expect(due.getDay()).toBe(1);
      expect(due.getDate()).toBe(16); // next week Monday, skipping this week
    });

    it("parses 'Friday at 5pm'", () => {
      const result = parseTaskInput("Happy hour Friday at 5pm", REF);
      const due = new Date(result.dueDate!);
      expect(due.getDay()).toBe(5);
      expect(due.getHours()).toBe(17);
    });

    it("parses 'next week' as next Monday", () => {
      const result = parseTaskInput("Plan next week", REF);
      const due = new Date(result.dueDate!);
      expect(due.getDay()).toBe(1); // Monday
      expect(due.getDate()).toBe(16);
    });
  });

  describe("recurrence parsing", () => {
    it("parses 'daily'", () => {
      const result = parseTaskInput("Standup daily", REF);
      expect(result.recurrence).toEqual({ frequency: "daily", interval: 1, afterCompletion: false });
      expect(result.title).toBe("Standup");
    });

    it("parses 'every day'", () => {
      const result = parseTaskInput("Journal every day", REF);
      expect(result.recurrence).toEqual({ frequency: "daily", interval: 1, afterCompletion: false });
    });

    it("parses 'weekly'", () => {
      const result = parseTaskInput("Review weekly", REF);
      expect(result.recurrence).toEqual({ frequency: "weekly", interval: 1, afterCompletion: false });
    });

    it("parses 'monthly'", () => {
      const result = parseTaskInput("Rent monthly", REF);
      expect(result.recurrence).toEqual({ frequency: "monthly", interval: 1, afterCompletion: false });
    });

    it("parses 'yearly'", () => {
      const result = parseTaskInput("Birthday yearly", REF);
      expect(result.recurrence).toEqual({ frequency: "yearly", interval: 1, afterCompletion: false });
    });

    it("parses 'every 3 days'", () => {
      const result = parseTaskInput("Water plants every 3 days", REF);
      expect(result.recurrence).toEqual({ frequency: "daily", interval: 3, afterCompletion: false });
    });

    it("parses 'every 2 weeks'", () => {
      const result = parseTaskInput("Retro every 2 weeks", REF);
      expect(result.recurrence).toEqual({ frequency: "weekly", interval: 2, afterCompletion: false });
    });

    it("parses 'every Monday'", () => {
      const result = parseTaskInput("Standup every Monday", REF);
      expect(result.recurrence).toEqual({
        frequency: "weekly",
        interval: 1,
        daysOfWeek: [1],
        afterCompletion: false,
      });
      // Should set initial due date to next Monday
      const due = new Date(result.dueDate!);
      expect(due.getDay()).toBe(1);
    });

    it("parses 'every Monday and Wednesday'", () => {
      const result = parseTaskInput("Gym every Monday and Wednesday", REF);
      expect(result.recurrence).toEqual({
        frequency: "weekly",
        interval: 1,
        daysOfWeek: [1, 3],
        afterCompletion: false,
      });
    });
  });

  describe("combined parsing", () => {
    it("parses title + date + priority + tag + list", () => {
      const result = parseTaskInput(
        "Review PR tomorrow at 3pm !! #work /engineering",
        REF
      );
      expect(result.title).toBe("Review PR");
      expect(result.priority).toBe("high");
      expect(result.tags).toEqual(["work"]);
      expect(result.listName).toBe("engineering");
      const due = new Date(result.dueDate!);
      expect(due.getDate()).toBe(12);
      expect(due.getHours()).toBe(15);
    });

    it("parses recurrence + tag", () => {
      const result = parseTaskInput("Standup every Monday #work", REF);
      expect(result.recurrence).toBeDefined();
      expect(result.tags).toEqual(["work"]);
      expect(result.title).toBe("Standup");
    });

    it("handles everything together", () => {
      const result = parseTaskInput(
        "Deploy release !! #deploy /ops every 2 weeks",
        REF
      );
      expect(result.title).toBe("Deploy release");
      expect(result.priority).toBe("high");
      expect(result.tags).toEqual(["deploy"]);
      expect(result.listName).toBe("ops");
      expect(result.recurrence).toEqual({ frequency: "weekly", interval: 2, afterCompletion: false });
    });
  });

  describe("time inference", () => {
    it("assumes PM for ambiguous low numbers (at 3 → 3pm)", () => {
      const result = parseTaskInput("Call today at 3", REF);
      const due = new Date(result.dueDate!);
      expect(due.getHours()).toBe(15);
    });

    it("keeps AM for numbers >= 8 without am/pm", () => {
      const result = parseTaskInput("Call today at 10", REF);
      const due = new Date(result.dueDate!);
      expect(due.getHours()).toBe(10);
    });

    it("handles explicit am correctly", () => {
      const result = parseTaskInput("Alarm tomorrow at 6am", REF);
      const due = new Date(result.dueDate!);
      expect(due.getHours()).toBe(6);
    });

    it("handles 12pm as noon", () => {
      const result = parseTaskInput("Lunch today at 12pm", REF);
      const due = new Date(result.dueDate!);
      expect(due.getHours()).toBe(12);
    });

    it("handles 12am as midnight", () => {
      const result = parseTaskInput("Reset today at 12am", REF);
      const due = new Date(result.dueDate!);
      expect(due.getHours()).toBe(0);
    });
  });

  describe("edge cases", () => {
    it("handles empty string", () => {
      const result = parseTaskInput("", REF);
      expect(result.title).toBe("");
      expect(result.priority).toBe("none");
    });

    it("handles only tokens (no real title)", () => {
      const result = parseTaskInput("!! #work /personal tomorrow", REF);
      expect(result.priority).toBe("high");
      expect(result.tags).toEqual(["work"]);
      expect(result.listName).toBe("personal");
      expect(result.dueDate).toBeDefined();
    });

    it("preserves title content that is not a token", () => {
      const result = parseTaskInput(
        "Email john@example.com about the Q2 budget",
        REF
      );
      expect(result.title).toBe("Email john@example.com about the Q2 budget");
    });
  });
});
