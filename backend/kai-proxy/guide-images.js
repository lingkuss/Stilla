import express from "express";
import OpenAI, { toFile } from "openai";
import crypto from "node:crypto";

export const guideImageModel = "gpt-image-2.5-sunburst";
const maxReferenceBytes = 1_500_000;
const pngSignature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

export function guideImageInput(body) {
    if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error("invalid_request");
    const description = typeof body.description === "string" ? body.description.trim() : "";
    if (description.length > 2000) throw new Error("invalid_request");
    let reference;
    if (body.referenceImage != null) {
        const value = body.referenceImage;
        if (typeof value !== "string" || value.length > 2_000_000 || !/^[A-Za-z0-9+/]+={0,2}$/.test(value)) {
            throw new Error("invalid_reference");
        }
        const bytes = Buffer.from(value, "base64");
        const jpeg = bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
        const png = bytes.subarray(0, 8).equals(pngSignature);
        if (!bytes.length || bytes.length > maxReferenceBytes || (!jpeg && !png)) throw new Error("invalid_reference");
        reference = { bytes, type: jpeg ? "image/jpeg" : "image/png", name: jpeg ? "reference.jpg" : "reference.png" };
    }
    if (!description && !reference) throw new Error("invalid_request");
    return { description, reference };
}

export function guideImagePrompt(description) {
    return `Create one original meditation guide for Vindla, as a reusable character asset.
The guide can be a human, animal, mythical creature, robot, plant spirit, or another imaginative being. Do not force nonhuman references into human faces.
If a reference image is supplied, use its subject, distinctive features, colours, and mood as inspiration. If it contains only a place or object, invent a character inspired by it. Discard the reference's background and original pose.
Show a single complete figure seated in a serene lotus / cross-legged meditation pose, adapted coherently to its anatomy. Front-facing, eye-level viewpoint, calm expression, balanced silhouette. Entire body, crossed legs, ears, tail, wings, and accessories must fit comfortably inside the frame with 8–10% clear padding. Centre the figure horizontally, with its seated base near the bottom.
Use refined, softly sculpted 3D illustration with natural materials and gentle, neutral lighting, suitable for a peaceful mountain world. Preserve imaginative details from the user's brief.
Deliver an isolated figure on a fully transparent background with clean alpha edges. No landscape, floor, pedestal, lettering, border, watermark, checkerboard, cast shadow, or coloured backdrop. Do not make the figure itself transparent.
The following is the user's character brief. Use it for the character's appearance, while retaining the asset composition and transparent background above:
${description || "Imagine a warm, creative meditation guide from the supplied reference."}`;
}

export function registerGuideImages(app, { apiKey, authorize, kv, client }) {
    // No automatic retries: a timeout must not silently create another paid image.
    const images = client ?? new OpenAI({ apiKey, maxRetries: 0, timeout: 150_000 }).images;
    app.post("/kai/guide/image", authorize, express.json({ limit: "2100kb" }), async (req, res) => {
        res.set("Cache-Control", "no-store");
        let input;
        try { input = guideImageInput(req.body); }
        catch (error) { return res.status(400).json({ code: error.message }); }
        if (!kv) return res.status(503).json({ code: "service_unavailable" });
        const owner = crypto.createHash("sha256").update(req.auth?.installationId || req.ip).digest("hex");
        const lockKey = `guide-image:active:${owner}`;
        const lock = crypto.randomUUID();
        let acquired = false;
        try {
            acquired = await kv.set(lockKey, lock, "EX", 180, "NX") === "OK";
            if (!acquired) return res.status(409).json({ code: "generation_in_progress" });
            const count = await kv.eval(`local n=redis.call('INCR',KEYS[1]); if n==1 then redis.call('EXPIRE',KEYS[1],3600) end; return n`, 1, `guide-image:hour:${owner}`);
            if (count > 15) return res.status(429).json({ code: "rate_limited" });
            const options = {
                model: guideImageModel, prompt: guideImagePrompt(input.description),
                size: "1024x1024", quality: "medium", background: "transparent", output_format: "png", n: 1,
            };
            const result = input.reference
                ? await images.edit({ ...options, image: await toFile(input.reference.bytes, input.reference.name, { type: input.reference.type }) })
                : await images.generate(options);
            const encoded = result.data?.[0]?.b64_json;
            const image = typeof encoded === "string" ? Buffer.from(encoded, "base64") : Buffer.alloc(0);
            // Keep the binary response below Vercel's response-size limit.
            if (image.length > 4_000_000 || !image.subarray(0, 8).equals(pngSignature)) {
                return res.status(502).json({ code: "invalid_image" });
            }
            console.info("[GuideImage]", { model: guideImageModel, bytes: image.length, reference: Boolean(input.reference) });
            return res.type("png").set("X-Guide-Image-Model", guideImageModel).send(image);
        } catch (error) {
            // Never log reference images, API keys, prompts, or provider response bodies.
            console.error("[GuideImage] failed", { status: error.status, code: error.code, type: error.name });
            const code = error.code === "moderation_blocked" ? "moderation_blocked"
                : error.code === "model_not_found" || error.status === 403 ? "model_unavailable"
                : error.status === 429 ? "provider_limit"
                : error.name === "APIConnectionTimeoutError" ? "generation_timeout" : "generation_failed";
            return res.status(error.status === 429 ? 429 : 502).json({ code });
        } finally {
            if (acquired) {
                try { await kv.eval(`if redis.call('GET',KEYS[1])==ARGV[1] then return redis.call('DEL',KEYS[1]) end; return 0`, 1, lockKey, lock); }
                catch { /* The lock expires automatically if Redis is unavailable. */ }
            }
        }
    });
    app.use("/kai/guide/image", (error, _req, res, _next) => {
        res.status(error.type === "entity.too.large" ? 413 : 400).json({ code: "invalid_request" });
    });
}
