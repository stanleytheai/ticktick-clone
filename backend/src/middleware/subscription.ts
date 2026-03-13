import { Request, Response, NextFunction } from "express";
import { db } from "../config/firebase";
import { getUid } from "./auth";
import {
  UserDoc,
  SubscriptionTier,
  FREE_TIER_LIMITS,
  PREMIUM_TIER_LIMITS,
} from "../models/schemas";

function userDocRef(uid: string) {
  return db.collection("users").doc(uid);
}

export async function loadSubscription(
  _req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const uid = getUid(res);
  try {
    const doc = await userDocRef(uid).get();
    if (doc.exists) {
      const data = doc.data() as UserDoc;
      res.locals.subscriptionTier = data.subscriptionTier;
      res.locals.subscriptionStatus = data.subscriptionStatus;
    } else {
      // Create default free-tier user doc on first access
      const now = new Date().toISOString();
      const userData: Omit<UserDoc, "id"> = {
        subscriptionTier: "free",
        createdAt: now,
        updatedAt: now,
      };
      await userDocRef(uid).set(userData);
      res.locals.subscriptionTier = "free";
    }
    next();
  } catch {
    res.status(500).json({ error: "Failed to load subscription status" });
  }
}

export function getUserTier(res: Response): SubscriptionTier {
  return (res.locals.subscriptionTier as SubscriptionTier) || "free";
}

export function isPremium(res: Response): boolean {
  const tier = getUserTier(res);
  const status = res.locals.subscriptionStatus;
  return tier === "premium" && (!status || status === "active");
}

export function getTierLimits(res: Response) {
  return isPremium(res) ? PREMIUM_TIER_LIMITS : FREE_TIER_LIMITS;
}
