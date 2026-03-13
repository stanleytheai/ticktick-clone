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

// User profile schemas
export const UpdateProfileSchema = z.object({
  displayName: z.string().min(1).max(100).optional(),
  photoURL: z.string().url().optional(),
});

// User settings schemas
export const UserSettingsSchema = z.object({
  theme: z.enum(["light", "dark", "system"]).default("system"),
  fontSize: z.enum(["small", "medium", "large"]).default("medium"),
  defaultListId: z.string().optional(),
  defaultReminderMinutes: z.number().int().min(0).max(10080).default(0), // 0 = no reminder, max 1 week
  weekStartDay: z.number().int().min(0).max(1).default(0), // 0=Sunday, 1=Monday
  dateFormat: z.enum(["MMM d, yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "MM/dd/yyyy"]).default("MMM d, yyyy"),
  timeFormat: z.enum(["12h", "24h"]).default("12h"),
  language: z.enum(["en", "es", "fr", "de", "ja", "zh", "pt", "ko"]).default("en"),
  soundEnabled: z.boolean().default(true),
  notificationsEnabled: z.boolean().default(true),
});

export const UpdateUserSettingsSchema = UserSettingsSchema.partial();

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

export interface UserSettingsDoc {
  theme: string;
  fontSize: string;
  defaultListId?: string;
  defaultReminderMinutes: number;
  weekStartDay: number;
  dateFormat: string;
  timeFormat: string;
  language: string;
  soundEnabled: boolean;
  notificationsEnabled: boolean;
  updatedAt: string;
}

export interface TaskDoc {
  id: string;
  title: string;
  description?: string;
  dueDate?: string;
  startDate?: string;
  duration?: number;
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

// Filter criteria types
export const FilterCriterionTypeEnum = z.enum([
  "dueDate",
  "priority",
  "tag",
  "list",
  "completed",
  "keyword",
  "createdDate",
]);
export type FilterCriterionType = z.infer<typeof FilterCriterionTypeEnum>;

export const FilterOperatorEnum = z.enum([
  "equals",
  "notEquals",
  "before",
  "after",
  "between",
  "contains",
  "isSet",
  "isNotSet",
]);
export type FilterOperator = z.infer<typeof FilterOperatorEnum>;

export const FilterCriterionSchema = z.object({
  type: FilterCriterionTypeEnum,
  operator: FilterOperatorEnum,
  value: z.union([z.string(), z.number(), z.boolean(), z.array(z.string())]).optional(),
  valueTo: z.string().optional(), // for "between" operator
});

export type FilterCriterion = z.infer<typeof FilterCriterionSchema>;

export const FilterLogicEnum = z.enum(["and", "or"]);
export type FilterLogic = z.infer<typeof FilterLogicEnum>;

export const CreateFilterSchema = z.object({
  name: z.string().min(1).max(200),
  criteria: z.array(FilterCriterionSchema).min(1).max(20),
  logic: FilterLogicEnum.default("and"),
  icon: z.string().max(50).optional(),
  color: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
  pinned: z.boolean().default(false),
  sortOrder: z.number().default(0),
});

export const UpdateFilterSchema = CreateFilterSchema.partial();

export interface FilterDoc {
  id: string;
  name: string;
  criteria: FilterCriterion[];
  logic: FilterLogic;
  icon?: string;
  color?: string;
  pinned: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

// Note folder schemas
export const CreateNoteFolderSchema = z.object({
  name: z.string().min(1).max(200),
  color: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
  sortOrder: z.number().default(0),
});

export const UpdateNoteFolderSchema = CreateNoteFolderSchema.partial();

export interface NoteFolderDoc {
  id: string;
  name: string;
  color?: string;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

// Note schemas
export const CreateNoteSchema = z.object({
  title: z.string().min(1).max(500),
  content: z.string().max(50000).default(""),
  folderId: z.string().optional(),
  sortOrder: z.number().default(0),
});

export const UpdateNoteSchema = CreateNoteSchema.partial();

export interface NoteDoc {
  id: string;
  title: string;
  content: string;
  folderId?: string;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

// Subscription tier
export const SubscriptionTierEnum = z.enum(["free", "premium"]);
export type SubscriptionTier = z.infer<typeof SubscriptionTierEnum>;

export const SubscriptionStatusEnum = z.enum([
  "active",
  "canceled",
  "past_due",
  "expired",
]);
export type SubscriptionStatus = z.infer<typeof SubscriptionStatusEnum>;

export interface UserDoc {
  id: string;
  email?: string;
  displayName?: string;
  subscriptionTier: SubscriptionTier;
  subscriptionStatus?: SubscriptionStatus;
  stripeCustomerId?: string;
  stripeSubscriptionId?: string;
  subscriptionStartDate?: string;
  subscriptionEndDate?: string;
  createdAt: string;
  updatedAt: string;
}

// Free tier limits
export const FREE_TIER_LIMITS = {
  maxLists: 9,
  maxTasksPerList: 19,
  maxRemindersPerTask: 2,
  maxHabits: 5,
  maxMembersPerList: 1,
  maxCalendarSubscriptions: 1,
} as const;

export const PREMIUM_TIER_LIMITS = {
  maxLists: Infinity,
  maxTasksPerList: Infinity,
  maxRemindersPerTask: 5,
  maxHabits: Infinity,
  maxMembersPerList: 29,
  maxCalendarSubscriptions: Infinity,
} as const;
