import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import { UpdateUserSettingsSchema, UserSettingsDoc } from "../models/schemas";

const router = Router();

const DEFAULT_SETTINGS: Omit<UserSettingsDoc, "updatedAt"> = {
  theme: "system",
  fontSize: "medium",
  defaultReminderMinutes: 0,
  weekStartDay: 0,
  dateFormat: "MMM d, yyyy",
  timeFormat: "12h",
  language: "en",
  soundEnabled: true,
  notificationsEnabled: true,
  quietHoursEnabled: false,
  quietHoursStart: "22:00",
  quietHoursEnd: "07:00",
};

function settingsRef(uid: string) {
  return db.collection("users").doc(uid).collection("settings").doc("preferences");
}

// GET /settings - Get user settings
router.get("/", async (_req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const doc = await settingsRef(uid).get();

    if (!doc.exists) {
      // Return defaults if no settings saved yet
      res.json({ ...DEFAULT_SETTINGS, updatedAt: null });
      return;
    }

    res.json(doc.data());
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch settings" });
  }
});

// PUT /settings - Update user settings (partial update)
router.put(
  "/",
  validate(UpdateUserSettingsSchema),
  async (req: Request, res: Response) => {
    try {
      const uid = getUid(res);
      const ref = settingsRef(uid);

      const updateData = {
        ...req.body,
        updatedAt: new Date().toISOString(),
      };

      await ref.set(updateData, { merge: true });

      const updated = await ref.get();
      res.json(updated.data());
    } catch (error) {
      res.status(500).json({ error: "Failed to update settings" });
    }
  }
);

export default router;
