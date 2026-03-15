import { Router } from "express";
import healthRouter from "./health";
import tasksRouter from "./tasks";
import subtasksRouter from "./subtasks";
import listsRouter from "./lists";
import tagsRouter from "./tags";
import habitsRouter from "./habits";
import pomodoroRouter from "./pomodoro";
import filtersRouter from "./filters";
import statisticsRouter from "./statistics";
import accountRouter from "./account";
import settingsRouter from "./settings";
import notesRouter from "./notes";
import subscriptionRouter from "./subscription";
import sharingRouter from "./sharing";
import notificationsRouter from "./notifications";
import { authMiddleware } from "../middleware/auth";
import { loadSubscription } from "../middleware/subscription";

const router = Router();

// Public routes
router.use("/health", healthRouter);

// Protected routes (require Firebase Auth + subscription loading)
router.use("/tasks", authMiddleware, loadSubscription, tasksRouter);
router.use("/tasks/:id/subtasks", authMiddleware, subtasksRouter);
router.use("/lists", authMiddleware, loadSubscription, listsRouter);
router.use("/tags", authMiddleware, tagsRouter);
router.use("/habits", authMiddleware, loadSubscription, habitsRouter);
router.use("/pomodoro", authMiddleware, pomodoroRouter);
router.use("/filters", authMiddleware, filtersRouter);
router.use("/statistics", authMiddleware, statisticsRouter);
router.use("/account", authMiddleware, accountRouter);
router.use("/settings", authMiddleware, settingsRouter);
router.use("/notes", authMiddleware, notesRouter);
router.use("/subscription", authMiddleware, loadSubscription, subscriptionRouter);
router.use("/shared-lists", authMiddleware, sharingRouter);
router.use("/notifications", authMiddleware, loadSubscription, notificationsRouter);

export default router;
