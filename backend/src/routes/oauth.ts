import { Router, Request, Response } from "express";
import * as crypto from "crypto";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import { CreateOAuthClientSchema, OAuthClientDoc } from "../models/schemas";

const router = Router();

function clientsCollection(uid: string) {
  return db.collection("users").doc(uid).collection("oauthClients");
}

function generateSecret(): string {
  return crypto.randomBytes(32).toString("hex");
}

// GET /oauth/clients — list OAuth clients created by this user
router.get("/clients", async (_req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const snapshot = await clientsCollection(uid).get();
    const clients = snapshot.docs.map((doc) => {
      const data = doc.data();
      // Mask secret in listing
      return {
        id: doc.id,
        name: data.name,
        redirectUris: data.redirectUris,
        scopes: data.scopes,
        createdAt: data.createdAt,
        updatedAt: data.updatedAt,
      };
    });
    res.json({ clients });
  } catch {
    res.status(500).json({ error: "Failed to fetch OAuth clients" });
  }
});

// POST /oauth/clients — register a new OAuth client
router.post(
  "/clients",
  validate(CreateOAuthClientSchema),
  async (req: Request, res: Response) => {
    const uid = getUid(res);
    const now = new Date().toISOString();
    try {
      const clientSecret = generateSecret();
      const clientData: Omit<OAuthClientDoc, "id"> = {
        name: req.body.name,
        clientSecret,
        redirectUris: req.body.redirectUris,
        scopes: req.body.scopes,
        ownerId: uid,
        createdAt: now,
        updatedAt: now,
      };
      const docRef = await clientsCollection(uid).add(clientData);

      // Return full secret only on creation
      res.status(201).json({
        id: docRef.id,
        name: clientData.name,
        clientId: docRef.id,
        clientSecret,
        redirectUris: clientData.redirectUris,
        scopes: clientData.scopes,
        createdAt: now,
      });
    } catch {
      res.status(500).json({ error: "Failed to create OAuth client" });
    }
  }
);

// DELETE /oauth/clients/:id — revoke/delete an OAuth client
router.delete("/clients/:id", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = clientsCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "OAuth client not found" });
      return;
    }
    await docRef.delete();
    res.status(204).send();
  } catch {
    res.status(500).json({ error: "Failed to delete OAuth client" });
  }
});

// POST /oauth/clients/:id/rotate-secret — rotate client secret
router.post("/clients/:id/rotate-secret", async (req: Request, res: Response) => {
  const uid = getUid(res);
  try {
    const docRef = clientsCollection(uid).doc(req.params.id);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: "OAuth client not found" });
      return;
    }

    const newSecret = generateSecret();
    const now = new Date().toISOString();
    await docRef.update({
      clientSecret: newSecret,
      updatedAt: now,
    });

    res.json({
      id: doc.id,
      clientSecret: newSecret,
      rotatedAt: now,
    });
  } catch {
    res.status(500).json({ error: "Failed to rotate secret" });
  }
});

export default router;
