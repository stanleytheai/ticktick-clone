import { z } from "zod";

// Task priority levels
export const PriorityEnum = z.enum(["none", "low", "medium", "high"]);
export type Priority = z.infer<typeof PriorityEnum>;

// Recurrence frequency
export const RecurrenceFrequencyEnum = z.enum([
  "daily",
  "weekly",
  "monthly",
  "yearly",
]);
export type RecurrenceFrequency = z.infer<typeof RecurrenceFrequencyEnum>;

// Recurrence rule (rrule-like config stored on task document)
export const RecurrenceRuleSchema = z.object({
  frequency: RecurrenceFrequencyEnum,
  interval: z.number().int().min(1).max(999).default(1),
  daysOfWeek: z
    .array(z.number().int().min(0).max(6))
    .min(1)
    .max(7)
    .optional(), // 0=Sun..6=Sat, for weekly
  dayOfMonth: z.number().int().min(1).max(31).optional(), // for monthly
  monthOfYear: z.number().int().min(1).max(12).optional(), // for yearly
  endDate: z.string().datetime().optional(), // stop recurring after this date
  endAfterCount: z.number().int().min(1).max(999).optional(), // stop after N occurrences
  afterCompletion: z.boolean().default(false), // next date relative to completion, not due date
});

export type RecurrenceRule = z.infer<typeof RecurrenceRuleSchema>;

// Task schemas
export const CreateTaskSchema = z.object({
  title: z.string().min(1).max(500),
  description: z.string().max(10000).optional(),
  dueDate: z.string().datetime().optional(),
  startDate: z.string().datetime().optional(),
  duration: z.number().int().min(0).optional(),
  dependsOn: z.array(z.string()).default([]),
  priority: PriorityEnum.default("none"),
  tags: z.array(z.string()).default([]),
  listId: z.string().optional(),
  sortOrder: z.number().default(0),
  recurrence: RecurrenceRuleSchema.optional(),
});

export const UpdateTaskSchema = CreateTaskSchema.partial();

export const BatchTaskSchema = z.object({
  tasks: z.array(CreateTaskSchema).min(1).max(100),
});

// Subtask schemas
export const CreateSubtaskSchema = z.object({
  title: z.string().min(1).max(500),
  completed: z.boolean().default(false),
  sortOrder: z.number().default(0),
});

export const UpdateSubtaskSchema = CreateSubtaskSchema.partial();

// List schemas
export const CreateListSchema = z.object({
  name: z.string().min(1).max(200),
  color: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
  icon: z.string().max(50).optional(),
  folderId: z.string().optional(),
  sortOrder: z.number().default(0),
});

export const UpdateListSchema = CreateListSchema.partial();

// Tag schemas
export const CreateTagSchema = z.object({
  name: z.string().min(1).max(100),
  color: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
  parentId: z.string().optional(),
});

export const UpdateTagSchema = CreateTagSchema.partial();

// Pomodoro session type
export const PomodoroSessionTypeEnum = z.enum(["work", "short_break", "long_break"]);
export type PomodoroSessionType = z.infer<typeof PomodoroSessionTypeEnum>;

// Ambient sound type
export const AmbientSoundEnum = z.enum([
  "rain",
  "forest",
  "cafe",
  "ocean",
  "fireplace",
]);
export type AmbientSound = z.infer<typeof AmbientSoundEnum>;

// Pomodoro schemas
export const StartPomodoroSchema = z.object({
  taskId: z.string().optional(),
  sessionType: PomodoroSessionTypeEnum.default("work"),
  durationMinutes: z.number().int().min(1).max(120).default(25),
  ambientSounds: z.array(AmbientSoundEnum).default([]),
});

export const StopPomodoroSchema = z.object({
  completed: z.boolean().default(true),
});

export const PomodoroStatsQuerySchema = z.object({
  period: z.enum(["daily", "weekly", "monthly"]).default("daily"),
  date: z.string().datetime().optional(),
});

// Firestore document types
export interface PomodoroSessionDoc {
  id: string;
  taskId?: string;
  sessionType: PomodoroSessionType;
  durationMinutes: number;
  startTime: string;
  endTime?: string;
  completed: boolean;
  ambientSounds: string[];
  createdAt: string;
  updatedAt: string;
}

export interface TaskDoc {
  id: string;
  title: string;
  description?: string;
  dueDate?: string;
  startDate?: string;
  duration?: number;
  dependsOn: string[];
  priority: Priority;
  tags: string[];
  listId?: string;
  completed: boolean;
  completedAt?: string;
  sortOrder: number;
  recurrence?: RecurrenceRule;
  recurrenceSourceId?: string; // links to the original recurring task
  recurrenceCount?: number; // how many occurrences have been created
  createdAt: string;
  updatedAt: string;
}

export interface SubtaskDoc {
  id: string;
  title: string;
  completed: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

export interface ListDoc {
  id: string;
  name: string;
  color?: string;
  icon?: string;
  folderId?: string;
  sortOrder: number;
  archived: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface TagDoc {
  id: string;
  name: string;
  color?: string;
  parentId?: string;
  createdAt: string;
  updatedAt: string;
}

// Habit schemas
export const FrequencyEnum = z.enum(["daily", "weekly", "monthly"]);
export type Frequency = z.infer<typeof FrequencyEnum>;

export const GoalTypeEnum = z.enum(["yes_no", "count"]);
export type GoalType = z.infer<typeof GoalTypeEnum>;

export const SectionEnum = z.enum(["morning", "afternoon", "evening", "anytime"]);
export type Section = z.infer<typeof SectionEnum>;

export const CreateHabitSchema = z.object({
  name: z.string().min(1).max(200),
  icon: z.string().max(50).optional(),
  frequency: FrequencyEnum.default("daily"),
  frequencyDays: z.array(z.number().int().min(0).max(6)).optional(),
  frequencyCount: z.number().int().min(1).optional(),
  goalType: GoalTypeEnum.default("yes_no"),
  goalCount: z.number().int().min(1).optional(),
  reminderTime: z.string().optional(),
  section: SectionEnum.default("anytime"),
  sortOrder: z.number().default(0),
});

export const UpdateHabitSchema = CreateHabitSchema.partial();

export const CreateHabitLogSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  value: z.number().default(1),
  skipped: z.boolean().default(false),
});

export interface HabitDoc {
  id: string;
  name: string;
  icon?: string;
  frequency: Frequency;
  frequencyDays?: number[];
  frequencyCount?: number;
  goalType: GoalType;
  goalCount?: number;
  reminderTime?: string;
  section: Section;
  sortOrder: number;
  archived: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface HabitLogDoc {
  id: string;
  date: string;
  value: number;
  skipped: boolean;
  createdAt: string;
}
