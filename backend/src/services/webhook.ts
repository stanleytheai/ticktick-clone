import * as crypto from "crypto";
import { db } from "../config/firebase";
import { WebhookDoc, WebhookEvent } from "../models/schemas";

function webhooksCollection(uid: string) {
  return db.collection("users").doc(uid).collection("webhooks");
}

export async function dispatchWebhooks(
  uid: string,
  event: WebhookEvent,
  payload: Record<string, unknown>
): Promise<void> {
  try {
    const snapshot = await webhooksCollection(uid)
      .where("active", "==", true)
      .get();

    const deliveries: Promise<void>[] = [];

    for (const doc of snapshot.docs) {
      const webhook = doc.data() as WebhookDoc;
      if (!webhook.events.includes(event)) continue;

      deliveries.push(deliverWebhook(webhook, event, payload));
    }

    // Fire and forget — don't block the main request
    await Promise.allSettled(deliveries);
  } catch (err) {
    console.error("Webhook dispatch error:", err);
  }
}

async function deliverWebhook(
  webhook: WebhookDoc,
  event: WebhookEvent,
  payload: Record<string, unknown>
): Promise<void> {
  const body = JSON.stringify({
    event,
    timestamp: new Date().toISOString(),
    data: payload,
  });

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "X-Webhook-Event": event,
  };

  if (webhook.secret) {
    const signature = crypto
      .createHmac("sha256", webhook.secret)
      .update(body)
      .digest("hex");
    headers["X-Webhook-Signature"] = `sha256=${signature}`;
  }

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10_000);

    await fetch(webhook.url, {
      method: "POST",
      headers,
      body,
      signal: controller.signal,
    });

    clearTimeout(timeout);
  } catch (err) {
    console.error(`Webhook delivery failed to ${webhook.url}:`, err);
  }
}
