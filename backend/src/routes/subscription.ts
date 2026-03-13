import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { getUserTier, isPremium } from "../middleware/subscription";
import { FREE_TIER_LIMITS, PREMIUM_TIER_LIMITS, UserDoc } from "../models/schemas";

const router = Router();

function userDocRef(uid: string) {
  return db.collection("users").doc(uid);
}

// GET /subscription — get current user's subscription info
router.get("/", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const doc = await userDocRef(uid).get();
    const tier = getUserTier(res);
    const premium = isPremium(res);
    const limits = premium ? PREMIUM_TIER_LIMITS : FREE_TIER_LIMITS;

    const data = doc.exists ? doc.data() : {};
    res.json({
      tier,
      isPremium: premium,
      limits: {
        maxLists: limits.maxLists === Infinity ? null : limits.maxLists,
        maxTasksPerList:
          limits.maxTasksPerList === Infinity ? null : limits.maxTasksPerList,
        maxRemindersPerTask: limits.maxRemindersPerTask,
        maxHabits: limits.maxHabits === Infinity ? null : limits.maxHabits,
      },
      subscriptionStatus: (data as Partial<UserDoc>)?.subscriptionStatus ?? null,
      subscriptionEndDate: (data as Partial<UserDoc>)?.subscriptionEndDate ?? null,
    });
  } catch {
    res.status(500).json({ error: "Failed to fetch subscription" });
  }
});

// POST /subscription/checkout — create a Stripe checkout session for upgrade
router.post("/checkout", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    if (isPremium(res)) {
      res.status(400).json({ error: "Already subscribed to Premium" });
      return;
    }

    const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
    if (!stripeSecretKey) {
      res.status(503).json({ error: "Payment processing not configured" });
      return;
    }

    // Dynamic import to avoid requiring stripe when not configured
    const Stripe = (await import("stripe")).default;
    const stripe = new Stripe(stripeSecretKey);

    // Get or create Stripe customer
    const userDoc = await userDocRef(uid).get();
    let customerId = userDoc.data()?.stripeCustomerId;

    if (!customerId) {
      const customer = await stripe.customers.create({
        metadata: { firebaseUid: uid },
      });
      customerId = customer.id;
      await userDocRef(uid).update({ stripeCustomerId: customerId });
    }

    const priceId = process.env.STRIPE_PREMIUM_PRICE_ID;
    if (!priceId) {
      res.status(503).json({ error: "Premium price not configured" });
      return;
    }

    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      mode: "subscription",
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: `${process.env.APP_URL || "https://app.example.com"}/subscription/success`,
      cancel_url: `${process.env.APP_URL || "https://app.example.com"}/subscription/cancel`,
      metadata: { firebaseUid: uid },
    });

    res.json({ checkoutUrl: session.url });
  } catch {
    res.status(500).json({ error: "Failed to create checkout session" });
  }
});

// POST /subscription/webhook — Stripe webhook handler
router.post("/webhook", async (req: Request, res: Response) => {
  const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  if (!stripeSecretKey || !webhookSecret) {
    res.status(503).json({ error: "Stripe not configured" });
    return;
  }

  try {
    const Stripe = (await import("stripe")).default;
    const stripe = new Stripe(stripeSecretKey);

    const sig = req.headers["stripe-signature"] as string;
    const event = stripe.webhooks.constructEvent(
      req.body,
      sig,
      webhookSecret
    );

    const now = new Date().toISOString();

    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as { customer: string; subscription: string; metadata?: { firebaseUid?: string } };
        const uid = session.metadata?.firebaseUid;
        if (uid) {
          await userDocRef(uid).update({
            subscriptionTier: "premium",
            subscriptionStatus: "active",
            stripeSubscriptionId: session.subscription,
            subscriptionStartDate: now,
            updatedAt: now,
          });
        }
        break;
      }

      case "customer.subscription.updated": {
        const subscription = event.data.object as unknown as {
          id: string;
          status: string;
          current_period_end: number;
        };
        // Find user by subscription ID
        const usersSnapshot = await db
          .collection("users")
          .where("stripeSubscriptionId", "==", subscription.id)
          .limit(1)
          .get();
        if (!usersSnapshot.empty) {
          const userRef = usersSnapshot.docs[0].ref;
          const status = subscription.status === "active" ? "active" : "past_due";
          await userRef.update({
            subscriptionStatus: status,
            subscriptionEndDate: new Date(
              subscription.current_period_end * 1000
            ).toISOString(),
            updatedAt: now,
          });
        }
        break;
      }

      case "customer.subscription.deleted": {
        const subscription = event.data.object as { id: string };
        const usersSnapshot = await db
          .collection("users")
          .where("stripeSubscriptionId", "==", subscription.id)
          .limit(1)
          .get();
        if (!usersSnapshot.empty) {
          const userRef = usersSnapshot.docs[0].ref;
          await userRef.update({
            subscriptionTier: "free",
            subscriptionStatus: "expired",
            updatedAt: now,
          });
        }
        break;
      }
    }

    res.json({ received: true });
  } catch {
    res.status(400).json({ error: "Webhook processing failed" });
  }
});

// POST /subscription/cancel — cancel subscription
router.post("/cancel", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    if (!isPremium(res)) {
      res.status(400).json({ error: "No active subscription to cancel" });
      return;
    }

    const userDoc = await userDocRef(uid).get();
    const subscriptionId = userDoc.data()?.stripeSubscriptionId;

    if (!subscriptionId) {
      res.status(400).json({ error: "No subscription found" });
      return;
    }

    const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
    if (!stripeSecretKey) {
      res.status(503).json({ error: "Payment processing not configured" });
      return;
    }

    const Stripe = (await import("stripe")).default;
    const stripe = new Stripe(stripeSecretKey);

    // Cancel at period end so user keeps premium until billing period ends
    await stripe.subscriptions.update(subscriptionId, {
      cancel_at_period_end: true,
    });

    await userDocRef(uid).update({
      subscriptionStatus: "canceled",
      updatedAt: new Date().toISOString(),
    });

    res.json({ message: "Subscription will cancel at end of billing period" });
  } catch {
    res.status(500).json({ error: "Failed to cancel subscription" });
  }
});

export default router;
