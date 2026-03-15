import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { getUid } from "../middleware/auth";
import { validate } from "../middleware/validate";
import { z } from "zod";
import * as crypto from "crypto";

const router = Router();

// ── Schemas ────────────────────────────────────────────

const CreateApiClientSchema = z.object({
  name: z.string().min(1).max(200),
  redirectUris: z.array(z.string().url()).min(1).max(10),
  scopes: z.array(
    z.enum([
      "tasks:read",
      "tasks:write",
      "lists:read",
      "lists:write",
      "tags:read",
      "tags:write",
      "habits:read",
      "habits:write",
      "notes:read",
      "notes:write",
      "profile:read",
    ])
  ).min(1),
  description: z.string().max(500).optional(),
});

const UpdateApiClientSchema = z.object({
  name: z.string().min(1).max(200).optional(),
  redirectUris: z.array(z.string().url()).min(1).max(10).optional(),
  scopes: z.array(z.string()).min(1).optional(),
  description: z.string().max(500).optional(),
});

const AuthorizeSchema = z.object({
  clientId: z.string(),
  redirectUri: z.string().url(),
  scope: z.string(),
  state: z.string().optional(),
  responseType: z.enum(["code"]),
});

const TokenSchema = z.object({
  grantType: z.enum(["authorization_code", "refresh_token"]),
  code: z.string().optional(),
  refreshToken: z.string().optional(),
  clientId: z.string(),
  clientSecret: z.string(),
  redirectUri: z.string().url().optional(),
});

// ── Helpers ────────────────────────────────────────────

function generateSecret(length: number = 32): string {
  return crypto.randomBytes(length).toString("hex");
}

function generateToken(length: number = 48): string {
  return crypto.randomBytes(length).toString("base64url");
}

function apiClientsRef(uid: string) {
  return db.collection("users").doc(uid).collection("apiClients");
}

// ── OAuth Client Management ────────────────────────────

// POST /api-clients - Register a new OAuth client
router.post(
  "/",
  validate(CreateApiClientSchema),
  async (req: Request, res: Response) => {
    try {
      const uid = getUid(res);
      const { name, redirectUris, scopes, description } = req.body;
      const now = new Date().toISOString();

      const clientId = `tc_${generateSecret(16)}`;
      const clientSecret = generateSecret(32);

      const clientRef = apiClientsRef(uid).doc();
      await clientRef.set({
        clientId,
        clientSecret,
        name,
        redirectUris,
        scopes,
        description: description || "",
        ownerId: uid,
        active: true,
        createdAt: now,
        updatedAt: now,
      });

      res.status(201).json({
        id: clientRef.id,
        clientId,
        clientSecret, // Only shown once at creation
        name,
        redirectUris,
        scopes,
        createdAt: now,
      });
    } catch (error) {
      res.status(500).json({ error: "Failed to create API client" });
    }
  }
);

// GET /api-clients - List user's OAuth clients
router.get("/", async (_req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const snap = await apiClientsRef(uid).orderBy("createdAt", "desc").get();

    res.json(
      snap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          clientId: data.clientId,
          name: data.name,
          redirectUris: data.redirectUris,
          scopes: data.scopes,
          description: data.description,
          active: data.active,
          createdAt: data.createdAt,
        };
      })
    );
  } catch (error) {
    res.status(500).json({ error: "Failed to list API clients" });
  }
});

// GET /api-clients/:id - Get single client details
router.get("/:id", async (req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const doc = await apiClientsRef(uid).doc(req.params.id).get();

    if (!doc.exists) {
      res.status(404).json({ error: "API client not found" });
      return;
    }

    const data = doc.data()!;
    res.json({
      id: doc.id,
      clientId: data.clientId,
      name: data.name,
      redirectUris: data.redirectUris,
      scopes: data.scopes,
      description: data.description,
      active: data.active,
      createdAt: data.createdAt,
    });
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch API client" });
  }
});

// PUT /api-clients/:id - Update client
router.put(
  "/:id",
  validate(UpdateApiClientSchema),
  async (req: Request, res: Response) => {
    try {
      const uid = getUid(res);
      const docRef = apiClientsRef(uid).doc(req.params.id);
      const doc = await docRef.get();

      if (!doc.exists) {
        res.status(404).json({ error: "API client not found" });
        return;
      }

      const updates: Record<string, unknown> = {
        updatedAt: new Date().toISOString(),
      };
      if (req.body.name !== undefined) updates.name = req.body.name;
      if (req.body.redirectUris !== undefined)
        updates.redirectUris = req.body.redirectUris;
      if (req.body.scopes !== undefined) updates.scopes = req.body.scopes;
      if (req.body.description !== undefined)
        updates.description = req.body.description;

      await docRef.update(updates);
      res.json({ message: "API client updated", id: req.params.id });
    } catch (error) {
      res.status(500).json({ error: "Failed to update API client" });
    }
  }
);

// DELETE /api-clients/:id - Delete client and revoke tokens
router.delete("/:id", async (req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const docRef = apiClientsRef(uid).doc(req.params.id);
    const doc = await docRef.get();

    if (!doc.exists) {
      res.status(404).json({ error: "API client not found" });
      return;
    }

    const clientId = doc.data()!.clientId;

    // Revoke all tokens for this client
    const tokensSnap = await db
      .collection("oauthTokens")
      .where("clientId", "==", clientId)
      .get();

    if (!tokensSnap.empty) {
      const batch = db.batch();
      for (const tokenDoc of tokensSnap.docs) {
        batch.delete(tokenDoc.ref);
      }
      await batch.commit();
    }

    // Revoke authorization codes
    const codesSnap = await db
      .collection("oauthCodes")
      .where("clientId", "==", clientId)
      .get();

    if (!codesSnap.empty) {
      const batch = db.batch();
      for (const codeDoc of codesSnap.docs) {
        batch.delete(codeDoc.ref);
      }
      await batch.commit();
    }

    await docRef.delete();
    res.json({ message: "API client deleted" });
  } catch (error) {
    res.status(500).json({ error: "Failed to delete API client" });
  }
});

// POST /api-clients/:id/rotate-secret - Rotate client secret
router.post("/:id/rotate-secret", async (req: Request, res: Response) => {
  try {
    const uid = getUid(res);
    const docRef = apiClientsRef(uid).doc(req.params.id);
    const doc = await docRef.get();

    if (!doc.exists) {
      res.status(404).json({ error: "API client not found" });
      return;
    }

    const newSecret = generateSecret(32);
    await docRef.update({
      clientSecret: newSecret,
      updatedAt: new Date().toISOString(),
    });

    res.json({ clientSecret: newSecret });
  } catch (error) {
    res.status(500).json({ error: "Failed to rotate client secret" });
  }
});

// ── OAuth 2.0 Authorization Flow ──────────────────────

// POST /api-clients/oauth/authorize - Issue authorization code
router.post(
  "/oauth/authorize",
  validate(AuthorizeSchema),
  async (req: Request, res: Response) => {
    try {
      const uid = getUid(res);
      const { clientId, redirectUri, scope, state } = req.body;

      // Find client across all users
      const clientSnap = await db
        .collectionGroup("apiClients")
        .where("clientId", "==", clientId)
        .where("active", "==", true)
        .limit(1)
        .get();

      if (clientSnap.empty) {
        res.status(400).json({ error: "Invalid client_id" });
        return;
      }

      const client = clientSnap.docs[0].data();

      // Verify redirect URI
      if (!client.redirectUris.includes(redirectUri)) {
        res.status(400).json({ error: "Invalid redirect_uri" });
        return;
      }

      // Verify requested scopes
      const requestedScopes = scope.split(" ");
      const invalidScopes = requestedScopes.filter(
        (s: string) => !client.scopes.includes(s)
      );
      if (invalidScopes.length > 0) {
        res.status(400).json({
          error: "Invalid scopes",
          invalidScopes,
        });
        return;
      }

      // Generate authorization code
      const code = generateToken(32);
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString(); // 10 min

      await db.collection("oauthCodes").doc().set({
        code,
        clientId,
        userId: uid,
        redirectUri,
        scopes: requestedScopes,
        expiresAt,
        used: false,
        createdAt: new Date().toISOString(),
      });

      res.json({
        code,
        state: state || null,
        redirectUri,
      });
    } catch (error) {
      res.status(500).json({ error: "Failed to authorize" });
    }
  }
);

// POST /api-clients/oauth/token - Exchange code for tokens
router.post(
  "/oauth/token",
  validate(TokenSchema),
  async (req: Request, res: Response) => {
    try {
      const { grantType, code, refreshToken, clientId, clientSecret, redirectUri } =
        req.body;

      // Verify client credentials
      const clientSnap = await db
        .collectionGroup("apiClients")
        .where("clientId", "==", clientId)
        .where("clientSecret", "==", clientSecret)
        .where("active", "==", true)
        .limit(1)
        .get();

      if (clientSnap.empty) {
        res.status(401).json({ error: "Invalid client credentials" });
        return;
      }

      if (grantType === "authorization_code") {
        if (!code || !redirectUri) {
          res.status(400).json({ error: "code and redirectUri required" });
          return;
        }

        // Find and validate auth code
        const codeSnap = await db
          .collection("oauthCodes")
          .where("code", "==", code)
          .where("clientId", "==", clientId)
          .where("used", "==", false)
          .limit(1)
          .get();

        if (codeSnap.empty) {
          res.status(400).json({ error: "Invalid or expired authorization code" });
          return;
        }

        const codeData = codeSnap.docs[0].data();

        // Verify expiry
        if (new Date(codeData.expiresAt) < new Date()) {
          await codeSnap.docs[0].ref.delete();
          res.status(400).json({ error: "Authorization code expired" });
          return;
        }

        // Verify redirect URI matches
        if (codeData.redirectUri !== redirectUri) {
          res.status(400).json({ error: "redirect_uri mismatch" });
          return;
        }

        // Mark code as used
        await codeSnap.docs[0].ref.update({ used: true });

        // Generate tokens
        const accessToken = generateToken(48);
        const newRefreshToken = generateToken(48);
        const now = new Date().toISOString();
        const expiresAt = new Date(
          Date.now() + 3600 * 1000
        ).toISOString(); // 1 hour

        await db.collection("oauthTokens").doc().set({
          accessToken,
          refreshToken: newRefreshToken,
          clientId,
          userId: codeData.userId,
          scopes: codeData.scopes,
          expiresAt,
          createdAt: now,
        });

        res.json({
          access_token: accessToken,
          token_type: "Bearer",
          expires_in: 3600,
          refresh_token: newRefreshToken,
          scope: codeData.scopes.join(" "),
        });
      } else if (grantType === "refresh_token") {
        if (!refreshToken) {
          res.status(400).json({ error: "refresh_token required" });
          return;
        }

        // Find existing token
        const tokenSnap = await db
          .collection("oauthTokens")
          .where("refreshToken", "==", refreshToken)
          .where("clientId", "==", clientId)
          .limit(1)
          .get();

        if (tokenSnap.empty) {
          res.status(400).json({ error: "Invalid refresh token" });
          return;
        }

        const tokenData = tokenSnap.docs[0].data();

        // Generate new tokens
        const newAccessToken = generateToken(48);
        const newRefreshToken = generateToken(48);
        const now = new Date().toISOString();
        const expiresAt = new Date(Date.now() + 3600 * 1000).toISOString();

        // Replace old token
        await tokenSnap.docs[0].ref.update({
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          expiresAt,
          updatedAt: now,
        });

        res.json({
          access_token: newAccessToken,
          token_type: "Bearer",
          expires_in: 3600,
          refresh_token: newRefreshToken,
          scope: tokenData.scopes.join(" "),
        });
      } else {
        res.status(400).json({ error: "Unsupported grant type" });
      }
    } catch (error) {
      res.status(500).json({ error: "Token exchange failed" });
    }
  }
);

// POST /api-clients/oauth/revoke - Revoke a token
router.post("/oauth/revoke", async (req: Request, res: Response) => {
  try {
    const { token } = req.body;
    if (!token) {
      res.status(400).json({ error: "token required" });
      return;
    }

    // Try to find by access token
    let snap = await db
      .collection("oauthTokens")
      .where("accessToken", "==", token)
      .limit(1)
      .get();

    if (snap.empty) {
      // Try by refresh token
      snap = await db
        .collection("oauthTokens")
        .where("refreshToken", "==", token)
        .limit(1)
        .get();
    }

    if (!snap.empty) {
      await snap.docs[0].ref.delete();
    }

    // Always return 200 per OAuth spec
    res.json({ message: "Token revoked" });
  } catch (error) {
    res.status(500).json({ error: "Failed to revoke token" });
  }
});

export default router;
