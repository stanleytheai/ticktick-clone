export const config = {
  port: parseInt(process.env.PORT || "3000", 10),
  nodeEnv: process.env.NODE_ENV || "development",
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID || "",
};
