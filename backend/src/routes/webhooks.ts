import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import {
  CreateWebhookSchema,
  UpdateWebhookSchema,
  WebhookDoc,
} from "../models/schemas";

const router = Router();

function webhooksCollection(uid: string) {
  return db.collection("users").doc(uid).collection("webhooks");
}

// GET /webhooks — list all webhooks
router.get("/", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const snapshot = await webhooksCollection(uid).get();
    const webhooks = snapshot.docs.map((doc) => {
      const { secret: _secret, id: _id, ...rest } = doc.data() as WebhookDoc;
      return { id: doc.id, ...rest };
    });
    res.json({ webhooks });
  } catch {
    res.status(500).json({ error: "Failed to fetch webhooks" });
  }
});

// POST /webhooks — create a webhook
router.post(
  "/",
  validate(CreateWebhookSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    const now = new Date().toISOString();
    try {
      const webhookData: Omit<WebhookDoc, "id"> = {
        ...req.body,
        createdAt: now,
        updatedAt: now,
      };
      const docRef = await webhooksCollection(uid).add(webhookData);
      // Omit secret from response
      const { secret: _secret, ...rest } = webhookData;
      res.status(201).json({ id: docRef.id, ...rest });
    } catch {
      res.status(500).json({ error: "Failed to create webhook" });
    }
  }
);

// GET /webhooks/:id — get a single webhook
router.get("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const doc = await webhooksCollection(uid).doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Webhook not found" });
      return;
    }
    const { secret: _secret, id: _id, ...rest } = doc.data() as WebhookDoc;
    res.json({ id: doc.id, ...rest });
  } catch {
    res.status(500).json({ error: "Failed to fetch webhook" });
  }
});

// PUT /webhooks/:id — update a webhook
router.put(
  "/:id",
  validate(UpdateWebhookSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    try {
      const docRef = webhooksCollection(uid).doc(req.params.id);
      const doc = await docRef.get();
      if (!doc.exists) {
        res.status(404).json({ error: "Webhook not found" });
        return;
      }
      const updateData = { ...req.body, updatedAt: new Date().toISOString() };
      await docRef.update(updateData);
      const { secret: _secret, ...rest } = { ...doc.data(), ...updateData };
      res.json({ id: doc.id, ...rest });
    } catch {
      res.status(500).json({ error: "Failed to update webhook" });
    }
  }
);

// DELETE /webhooks/:id — delete a webhook
router.delete("/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = webhooksCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "Webhook not found" });
      return;
    }
    await docRef.delete();
    res.status(204).send();
  } catch {
    res.status(500).json({ error: "Failed to delete webhook" });
  }
});

export default router;
