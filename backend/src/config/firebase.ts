import * as admin from "firebase-admin";

const app = admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: process.env.FIREBASE_PROJECT_ID || "ticktick-clone-local",
});

export const db = admin.firestore();
export const auth = admin.auth();
export default app;
