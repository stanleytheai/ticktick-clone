import { z } from "zod";

// Task priority levels
export const PriorityEnum = z.enum(["none", "low", "medium", "high"]);
export type Priority = z.infer<typeof PriorityEnum>;

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

// Firestore document types
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
