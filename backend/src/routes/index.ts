import { Router } from "express";
import healthRouter from "./health";
import tasksRouter from "./tasks";
import subtasksRouter from "./subtasks";
import listsRouter from "./lists";
import tagsRouter from "./tags";
import habitsRouter from "./habits";
import pomodoroRouter from "./pomodoro";
import statisticsRouter from "./statistics";
import { authMiddleware } from "../middleware/auth";

const router = Router();

// Public routes
router.use("/health", healthRouter);

// Protected routes (require Firebase Auth)
router.use("/tasks", authMiddleware, tasksRouter);
router.use("/tasks/:id/subtasks", authMiddleware, subtasksRouter);
router.use("/lists", authMiddleware, listsRouter);
router.use("/tags", authMiddleware, tagsRouter);
router.use("/habits", authMiddleware, habitsRouter);
router.use("/pomodoro", authMiddleware, pomodoroRouter);
router.use("/statistics", authMiddleware, statisticsRouter);

export default router;
