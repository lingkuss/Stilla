import express from "express";
import OpenAI from "openai";
import rateLimit from "express-rate-limit";
import cors from "cors";
import Redis from "ioredis";
import crypto from "crypto";

const kv = process.env.REDIS_URL ? new Redis(process.env.REDIS_URL) : null;

const port = Number(process.env.PORT || 8787);
const model = process.env.OPENAI_MODEL || "gpt-5.4-mini";
const proxyToken = process.env.KAI_PROXY_TOKEN || "";
const openAIKey = process.env.OPENAI_API_KEY;

if (!openAIKey) {
    throw new Error("Missing OPENAI_API_KEY");
}

const openai = new OpenAI({ apiKey: openAIKey });
const app = express();

app.use(cors({
    origin: ["https://stilla.app", "https://stilla-three.vercel.app", "http://localhost:3000"],
    methods: ["GET", "POST", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"]
}));

app.use(express.json({ limit: "32kb" }));

app.get("/health", (_req, res) => {
    res.json({
        ok: true,
        service: "stilla-kai-proxy",
        model
    });
});

const generateLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 100,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: "Too many requests. Please try again later." },
});

app.post("/kai/generate", generateLimiter, async (req, res) => {
    try {
        if (proxyToken) {
            const authHeader = req.headers.authorization || "";
            const bearerToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
            if (bearerToken !== proxyToken) {
                return res.status(401).json({ error: "Unauthorized" });
            }
        }

        const mood = typeof req.body?.mood === "string" ? req.body.mood.trim() : "";
        const durationMinutes = Number(req.body?.durationMinutes);
        const personalityName = typeof req.body?.personalityName === "string"
            ? req.body.personalityName.trim()
            : "Zen Minimalist";
        const personalityPrompt = typeof req.body?.personalityPrompt === "string"
            ? req.body.personalityPrompt.trim()
            : "";

        if (!mood || !Number.isInteger(durationMinutes) || durationMinutes < 1 || durationMinutes > 180) {
            return res.status(400).json({
                error: "Invalid request. Expecting non-empty mood and durationMinutes between 1 and 180."
            });
        }

        const systemPrompt = buildSystemPrompt(mood, durationMinutes, personalityName, personalityPrompt);
        const completion = await openai.chat.completions.create({
            model,
            response_format: { type: "json_object" },
            temperature: 0.7,
            messages: [
                {
                    role: "system",
                    content: systemPrompt
                },
                {
                    role: "user",
                    content: `Generate a ${durationMinutes} minute meditation for someone feeling ${mood}. Also provide a proactive next-step header, 1–2 sentence guidance, and three distinct session suggestions for their next session.`
                }
            ]
        });

        const content = completion.choices[0]?.message?.content;
        if (!content) {
            return res.status(502).json({ error: "OpenAI returned an empty response." });
        }

        let parsed;
        try {
            parsed = JSON.parse(content);
        } catch {
            return res.status(502).json({ error: "OpenAI returned invalid JSON." });
        }

        const validated = normalizeScript(parsed, durationMinutes);
        return res.json(validated);
    } catch (error) {
        console.error("Kai proxy failure:", error);
        return res.status(500).json({
            error: "Unable to generate a Kai meditation right now."
        });
    }
});

// --- NEW SHARING ENDPOINTS ---

const shareLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 100,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: "Too many share attempts. Please try again later." },
});

// Store session JSON and return a short ID
app.post("/kai/share", shareLimiter, async (req, res) => {
    try {
        if (!kv) {
            return res.status(503).json({ error: "Storage not configured" });
        }

        if (proxyToken) {
            const authHeader = req.headers.authorization || "";
            const bearerToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
            if (bearerToken !== proxyToken) {
                return res.status(401).json({ error: "Unauthorized" });
            }
        }

        const sessionData = req.body;
        if (!sessionData || Object.keys(sessionData).length === 0) {
            return res.status(400).json({ error: "Invalid session data" });
        }

        // Generate a random 7-character ID
        const id = crypto.randomBytes(4).toString("hex").slice(0, 7);
        
        // Store in KV with 30 day expiry
        const ONE_MONTH = 60 * 60 * 24 * 30;
        await kv.set(`share:${id}`, JSON.stringify(sessionData), "EX", ONE_MONTH);

        return res.json({ id });
    } catch (error) {
        console.error("Kai share store failure:", error);
        return res.status(500).json({ error: "Failed to store shared session" });
    }
});

// Retrieve session JSON by ID
app.get("/kai/share", async (req, res) => {
    try {
        if (!kv) {
            return res.status(503).json({ error: "Storage not configured" });
        }

        const id = req.query.id;
        if (typeof id !== "string" || !id) {
            return res.status(400).json({ error: "Missing share ID" });
        }

        const rawData = await kv.get(`share:${id}`);
        if (!rawData) {
            return res.status(404).json({ error: "Session not found or expired" });
        }

        return res.json(JSON.parse(rawData));
    } catch (error) {
        console.error("Kai share retrieve failure:", error);
        return res.status(500).json({ error: "Failed to retrieve shared session" });
    }
});

app.listen(port, () => {
    console.log(`Stilla Kai proxy listening on :${port}`);
});

function buildSystemPrompt(mood, durationMinutes, personalityName, personalityPrompt) {
    return `
You are Kai.
You must fully assume the selected persona below.
Persona compliance is mandatory.
Do not blend this persona with a generic meditation voice.
Do not soften, average out, or partially apply the persona.
The user should be able to clearly feel which persona they chose from the wording alone.

Selected persona: ${personalityName}

Persona instructions:
${personalityPrompt}

Now create a personalized meditation script and proactive guidance in JSON format.
The JSON must follow this structure exactly:
{
  "title": "A short, poetic title",
  "guidanceHeader": "A proactive, persona-styled header (max 60 chars)",
  "guidanceBody": "A short, proactive, persona-styled paragraph (1–2 sentences)",
  "suggestions": [
    "Suggestion 1 (short, specific, 8–16 words)",
    "Suggestion 2 (short, specific, 8–16 words)",
    "Suggestion 3 (short, specific, 8–16 words)"
  ],
  "durationMinutes": ${durationMinutes},
  "steps": [
    { "text": "The words to speak", "pauseDuration": 5.0 }
  ]
}
Guidelines:
- The user is feeling: ${mood}.
- The proactive guidance should feel like a personal next step based on the user's recent memory and current mood.
- Suggestions should feel varied, useful, and aligned to the persona while respecting the user's context.
- Total duration: ${durationMinutes} minutes (${durationMinutes * 60} seconds).
- The "pauseDuration" field is in SECONDS. Provide generous pauses between steps.
- Ensure the sum of pauseDurations plus reading time roughly matches the total duration.
- Stay safe, non-diagnostic, and non-medical.
- Do not claim to treat mental illness, trauma, or medical conditions.
- Do not encourage emotional dependency.
- If the user expresses distress, respond gently and keep the meditation grounded and supportive.
- Keep the meditation useful and coherent, but let the persona strongly shape:
  - sentence length
  - emotional tone
  - metaphor density
  - pacing
  - level of warmth vs restraint
  - how distraction is described
- If the selected persona is minimal, be truly minimal.
- If the selected persona is practical, be plainly practical.
- If the selected persona is poetic, be richly poetic.
- If the selected persona is analytical, sound observant and reflective.
- If the selected persona is formal and esoteric, stay formal and esoteric throughout.
- Respond ONLY with raw JSON. No markdown, no filler.
`.trim();
}

function normalizeScript(raw, requestedDuration) {
    const title = typeof raw?.title === "string" && raw.title.trim() ? raw.title.trim() : "Kai Journey";
    const durationMinutes = Number.isInteger(raw?.durationMinutes) ? raw.durationMinutes : requestedDuration;
    const guidanceHeader = typeof raw?.guidanceHeader === "string" && raw.guidanceHeader.trim()
        ? raw.guidanceHeader.trim()
        : null;
    const guidanceBody = typeof raw?.guidanceBody === "string" && raw.guidanceBody.trim()
        ? raw.guidanceBody.trim()
        : null;
    const suggestions = Array.isArray(raw?.suggestions)
        ? raw.suggestions
            .map((s) => (typeof s === "string" ? s.trim() : ""))
            .filter((s) => s.length > 0)
            .slice(0, 3)
        : [];
    const rawSteps = Array.isArray(raw?.steps) ? raw.steps : [];

    const steps = rawSteps
        .map((step) => ({
            text: typeof step?.text === "string" ? step.text.trim() : "",
            pauseDuration: Number(step?.pauseDuration)
        }))
        .filter((step) => step.text.length > 0)
        .map((step) => ({
            text: step.text,
            pauseDuration: Number.isFinite(step.pauseDuration) && step.pauseDuration > 0 ? step.pauseDuration : 5
        }));

    if (steps.length === 0) {
        throw new Error("Generated script had no valid steps.");
    }

    return {
        title,
        guidanceHeader,
        guidanceBody,
        suggestions,
        durationMinutes,
        steps
    };
}

export default app;
