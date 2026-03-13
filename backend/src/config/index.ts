export const config = {
  port: parseInt(process.env.PORT || "3000", 10),
  nodeEnv: process.env.NODE_ENV || "development",
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID || "",
  stripeSecretKey: process.env.STRIPE_SECRET_KEY || "",
  stripeWebhookSecret: process.env.STRIPE_WEBHOOK_SECRET || "",
  stripePremiumPriceId: process.env.STRIPE_PREMIUM_PRICE_ID || "",
  appUrl: process.env.APP_URL || "https://app.example.com",
};
