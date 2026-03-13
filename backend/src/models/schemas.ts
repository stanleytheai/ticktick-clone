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

// Import source types
export const ImportSourceEnum = z.enum([
  "todoist",
  "microsoft_todo",
  "apple_reminders",
]);
export type ImportSource = z.infer<typeof ImportSourceEnum>;

// Export format types
export const ExportFormatEnum = z.enum(["csv", "json", "text"]);
export type ExportFormat = z.infer<typeof ExportFormatEnum>;

// Import schema
export const ImportDataSchema = z.object({
  source: ImportSourceEnum,
  data: z.string().min(1).max(10_000_000), // raw file content (up to 10MB)
});

// Export schema
export const ExportRequestSchema = z.object({
  format: ExportFormatEnum,
  listIds: z.array(z.string()).optional(), // filter by lists, or all if omitted
  includeCompleted: z.boolean().default(true),
});

// Webhook event types
export const WebhookEventEnum = z.enum([
  "task.created",
  "task.updated",
  "task.completed",
  "task.deleted",
  "list.created",
  "list.updated",
  "list.deleted",
]);
export type WebhookEvent = z.infer<typeof WebhookEventEnum>;

// Webhook schemas
export const CreateWebhookSchema = z.object({
  url: z.string().url().max(2000),
  events: z.array(WebhookEventEnum).min(1),
  secret: z.string().min(16).max(256).optional(), // optional shared secret for HMAC
  active: z.boolean().default(true),
});

export const UpdateWebhookSchema = CreateWebhookSchema.partial();

export interface WebhookDoc {
  id: string;
  url: string;
  events: WebhookEvent[];
  secret?: string;
  active: boolean;
  createdAt: string;
  updatedAt: string;
}

// OAuth client schemas
export const CreateOAuthClientSchema = z.object({
  name: z.string().min(1).max(200),
  redirectUris: z.array(z.string().url()).min(1).max(10),
  scopes: z.array(z.string()).min(1),
});

export interface OAuthClientDoc {
  id: string;
  name: string;
  clientSecret: string;
  redirectUris: string[];
  scopes: string[];
  ownerId: string;
  createdAt: string;
  updatedAt: string;
}

// Calendar sync schemas
export const CalendarSyncProviderEnum = z.enum(["google", "outlook", "apple"]);
export type CalendarSyncProvider = z.infer<typeof CalendarSyncProviderEnum>;

export const CreateCalendarSyncSchema = z.object({
  provider: CalendarSyncProviderEnum,
  accessToken: z.string().min(1),
  refreshToken: z.string().optional(),
  calendarId: z.string().min(1),
  syncEnabled: z.boolean().default(true),
});

export const UpdateCalendarSyncSchema = z.object({
  accessToken: z.string().min(1).optional(),
  refreshToken: z.string().optional(),
  calendarId: z.string().min(1).optional(),
  syncEnabled: z.boolean().optional(),
});

export interface CalendarSyncDoc {
  id: string;
  provider: CalendarSyncProvider;
  calendarId: string;
  syncEnabled: boolean;
  lastSyncAt?: string;
  syncToken?: string; // provider-specific incremental sync token
  createdAt: string;
  updatedAt: string;
}

export interface CalendarEventDoc {
  id: string;
  externalId: string; // ID from the calendar provider
  provider: CalendarSyncProvider;
  title: string;
  description?: string;
  startTime: string;
  endTime: string;
  allDay: boolean;
  taskId?: string; // linked task if synced from our system
  createdAt: string;
  updatedAt: string;
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
