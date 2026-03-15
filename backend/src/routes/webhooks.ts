import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import { z } from "zod";
import * as crypto from "crypto";

const router = Router();

// ── Schemas ────────────────────────────────────────────

const WebhookEventEnum = z.enum([
  "task.created",
  "task.updated",
  "task.completed",
  "task.deleted",
  "list.created",
  "list.updated",
  "list.deleted",
  "habit.logged",
  "note.created",
  "note.updated",
]);
export type WebhookEvent = z.infer<typeof WebhookEventEnum>;

const CreateWebhookSchema = z.object({
  url: z.string().url(),
  events: z.array(WebhookEventEnum).min(1),
  description: z.string().max(500).optional(),
  active: z.boolean().default(true),
});

const UpdateWebhookSchema = z.object({
  url: z.string().url().optional(),
  events: z.array(WebhookEventEnum).min(1).optional(),
  description: z.string().max(500).optional(),
  active: z.boolean().optional(),
});

// ── Helpers ────────────────────────────────────────────

function webhooksRef(uid: string) {
  return db.collection("users").doc(uid).collection("webhooks");
}

function webhookLogsRef(uid: string) {
  return db.collection("users").doc(uid).collection("webhookLogs");
}

function generateSigningSecret(): string {
  return crypto.randomBytes(32).toString("hex");
}

/**
 * Compute HMAC-SHA256 signature for webhook payload.
 * Consumers verify the X-Webhook-Signature header using their signing secret.
 */
export function computeWebhookSignature(
  payload: string,
  secret: string
): string {
  return crypto.createHmac("sha256", secret).update(payload).digest("hex");
}

/**
 * Deliver a webhook event to all matching subscriptions for a user.
 * Called from route handlers when events occur.
 */
export async function deliverWebhook(
  uid: string,
  event: string,
  data: Record<string, unknown>
): Promise<void> {
  try {
    const snap = await webhooksRef(uid)
      .where("active", "==", true)
      .get();

    for (const doc of snap.docs) {
      const webhook = doc.data();
      if (!webhook.events.includes(event)) continue;

      const payload = JSON.stringify({
        event,
        data,
        timestamp: new Date().toISOString(),
        webhookId: doc.id,
      });

      const signature = computeWebhookSignature(payload, webhook.signingSecret);

      // Record delivery attempt — actual HTTP delivery would use a queue
      // (Cloud Tasks / Pub/Sub) in production for reliability
      await webhookLogsRef(uid).doc().set({
        webhookId: doc.id,
        event,
        url: webhook.url,
        payload,
        signature,
        status: "queued",
        attempts: 0,
        createdAt: new Date().toISOString(),
      });
    }
  } catch {
    // Webhook delivery failures should not break the main operation
  }
}

// POST /webhooks - Register a new webhook
router.post(
  "/",
  validate(CreateWebhookSchema),
  async (req: Request, res: Response) => {
    try {
      const uid = getUid(res);
      const { url, events, description, active } = req.body;
      const now = new Date().toISOString();

      // Limit to 10 webhooks per user
      const existing = await webhooksRef(uid).get();
      if (existing.size >= 10) {
        res.status(400).json({
          error: "Maximum of 10 webhooks per user",
          code: "LIMIT_EXCEEDED",
        });
        return;
      }

      const signingSecret = generateSigningSecret();

      const ref = webhooksRef(uid).doc();
      await ref.set({
        url,
        events,
        description: description || "",
        active,
        signingSecret,
        createdAt: now,
        updatedAt: now,
      });

      res.status(201).json({
        id: ref.id,
        url,
        events,
        description: description || "",
        active,
        signingSecret, // Only shown once at creation
        createdAt: now,
      });
    } catch (error) {
      res.status(500).json({ error: "Failed to create webhook" });
    }
  }
);

// GET /webhooks - List all webhooks
router.get("/", async (_req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const snap = await webhooksRef(uid).orderBy("createdAt", "desc").get();

    res.json(
      snap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          url: data.url,
          events: data.events,
          description: data.description,
          active: data.active,
          createdAt: data.createdAt,
          updatedAt: data.updatedAt,
        };
      })
    );
  } catch (error) {
    res.status(500).json({ error: "Failed to list webhooks" });
  }
});

// GET /webhooks/:id - Get webhook details
router.get("/:id", async (req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const doc = await webhooksRef(uid).doc(req.params.id).get();

    if (!doc.exists) {
      res.status(404).json({ error: "Webhook not found" });
      return;
    }

    const data = doc.data()!;
    res.json({
      id: doc.id,
      url: data.url,
      events: data.events,
      description: data.description,
      active: data.active,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    });
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch webhook" });
  }
});

// PUT /webhooks/:id - Update webhook
router.put(
  "/:id",
  validate(UpdateWebhookSchema),
  async (req: Request, res: Response) => {
    try {
      const uid = getUid(res);
      const docRef = webhooksRef(uid).doc(req.params.id);
      const doc = await docRef.get();

      if (!doc.exists) {
        res.status(404).json({ error: "Webhook not found" });
        return;
      }

      const updates: Record<string, unknown> = {
        updatedAt: new Date().toISOString(),
      };
      if (req.body.url !== undefined) updates.url = req.body.url;
      if (req.body.events !== undefined) updates.events = req.body.events;
      if (req.body.description !== undefined)
        updates.description = req.body.description;
      if (req.body.active !== undefined) updates.active = req.body.active;

      await docRef.update(updates);

      res.json({ message: "Webhook updated", id: req.params.id });
    } catch (error) {
      res.status(500).json({ error: "Failed to update webhook" });
    }
  }
);

// DELETE /webhooks/:id - Delete webhook
router.delete("/:id", async (req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const docRef = webhooksRef(uid).doc(req.params.id);
    const doc = await docRef.get();

    if (!doc.exists) {
      res.status(404).json({ error: "Webhook not found" });
      return;
    }

    await docRef.delete();
    res.json({ message: "Webhook deleted" });
  } catch (error) {
    res.status(500).json({ error: "Failed to delete webhook" });
  }
});

// GET /webhooks/:id/logs - Get delivery logs
router.get("/:id/logs", async (req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const webhookDoc = await webhooksRef(uid).doc(req.params.id).get();

    if (!webhookDoc.exists) {
      res.status(404).json({ error: "Webhook not found" });
      return;
    }

    const snap = await webhookLogsRef(uid)
      .where("webhookId", "==", req.params.id)
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();

    res.json(
      snap.docs.map((d) => ({
        id: d.id,
        event: d.data().event,
        status: d.data().status,
        attempts: d.data().attempts,
        createdAt: d.data().createdAt,
      }))
    );
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch webhook logs" });
  }
});

// POST /webhooks/:id/test - Send a test webhook
router.post("/:id/test", async (req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const doc = await webhooksRef(uid).doc(req.params.id).get();

    if (!doc.exists) {
      res.status(404).json({ error: "Webhook not found" });
      return;
    }

    const webhook = doc.data()!;
    const payload = JSON.stringify({
      event: "test",
      data: { message: "This is a test webhook delivery" },
      timestamp: new Date().toISOString(),
      webhookId: doc.id,
    });

    const signature = computeWebhookSignature(payload, webhook.signingSecret);

    // Log the test delivery
    await webhookLogsRef(uid).doc().set({
      webhookId: doc.id,
      event: "test",
      url: webhook.url,
      payload,
      signature,
      status: "queued",
      attempts: 0,
      createdAt: new Date().toISOString(),
    });

    res.json({
      message: "Test webhook queued",
      payload: JSON.parse(payload),
      signature,
    });
  } catch (error) {
    res.status(500).json({ error: "Failed to send test webhook" });
  }
});

export default router;
