import express from "express";
import OpenAI from "openai";
import rateLimit from "express-rate-limit";
import cors from "cors";
import Redis from "ioredis";
import crypto from "crypto";

const kv = process.env.REDIS_URL ? new Redis(process.env.REDIS_URL) : null;

// Catch background connection errors to prevent unhandled exceptions crashing the serverless function
if (kv) {
    kv.on("error", (err) => {
        console.error("[Redis Error]:", err.message);
    });
}

const port = Number(process.env.PORT || 8787);
const model = process.env.OPENAI_MODEL || "gpt-5.4-mini";
const proxyToken = process.env.KAI_PROXY_TOKEN || "";
const openAIKey = process.env.OPENAI_API_KEY;

if (!openAIKey) {
    throw new Error("Missing OPENAI_API_KEY");
}

const openai = new OpenAI({ apiKey: openAIKey });
const app = express();

// Trust the Vercel edge proxy so that rate limiting handles the real client IP (x-forwarded-for)
app.set("trust proxy", 1);

app.use(cors({
    origin: ["https://vindla.app", "https://vindla-three.vercel.app", "http://localhost:3000"],
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
    max: 30,
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

        console.log(`[Generate] Model: ${model} | IP: ${req.ip} | Mood: "${mood}" | Duration: ${durationMinutes}m | Persona: "${personalityName}"`);

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

app.post("/kai/sleep/generate", generateLimiter, async (req, res) => {
    try {
        if (proxyToken) {
            const authHeader = req.headers.authorization || "";
            const bearerToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
            if (bearerToken !== proxyToken) {
                return res.status(401).json({ error: "Unauthorized" });
            }
        }

        const themeTitle = typeof req.body?.themeTitle === "string" ? req.body.themeTitle.trim() : "";
        const themeSubtitle = typeof req.body?.themeSubtitle === "string" ? req.body.themeSubtitle.trim() : "";
        const locale = typeof req.body?.locale === "string" ? req.body.locale.trim() : "en";
        const durationMinutes = Number(req.body?.durationMinutes);
        const excludeTitles = Array.isArray(req.body?.excludeTitles)
            ? req.body.excludeTitles
                .map((v) => (typeof v === "string" ? v.trim() : ""))
                .filter((v) => v.length > 0)
                .slice(0, 20)
            : [];

        if (!themeTitle || !Number.isInteger(durationMinutes) || durationMinutes < 1 || durationMinutes > 180) {
            return res.status(400).json({
                error: "Invalid request. Expecting themeTitle and durationMinutes between 1 and 180."
            });
        }

        console.log(`[SleepGenerate] Model: ${model} | IP: ${req.ip} | Theme: "${themeTitle}" | Duration: ${durationMinutes}m | Locale: ${locale}`);

        const systemPrompt = buildSleepSystemPrompt({
            themeTitle,
            themeSubtitle,
            durationMinutes,
            locale,
            excludeTitles
        });

        const completion = await openai.chat.completions.create({
            model,
            response_format: { type: "json_object" },
            temperature: 0.8,
            messages: [
                {
                    role: "system",
                    content: systemPrompt
                },
                {
                    role: "user",
                    content: `Generate a ${durationMinutes}-minute sleep story for "${themeTitle}" and include six fresh next headers.`
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

        const storyRaw = parsed?.story ?? parsed;
        const validatedStory = normalizeScript(storyRaw, durationMinutes);
        const nextHeaders = normalizeSleepHeaders(parsed?.nextHeaders, excludeTitles);

        return res.json({
            story: validatedStory,
            nextHeaders
        });
    } catch (error) {
        console.error("Kai sleep proxy failure:", error);
        return res.status(500).json({
            error: "Unable to generate a sleep story right now."
        });
    }
});

// --- NEW SHARING ENDPOINTS ---

const shareLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 30,
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

function buildSleepSystemPrompt({ themeTitle, themeSubtitle, durationMinutes, locale, excludeTitles }) {
    const subtitleLine = themeSubtitle ? `- Theme subtitle/context: ${themeSubtitle}` : "- Theme subtitle/context: none";
    const excluded = excludeTitles.length > 0
        ? excludeTitles.map((t) => `  - ${t}`).join("\n")
        : "  - none";
    const minWordTarget = Math.max(220, durationMinutes * 80);
    const maxWordTarget = Math.max(minWordTarget + 80, durationMinutes * 105);

    return `
You are Kai, generating sleep-first content.

Produce ONLY raw JSON with this exact top-level shape:
{
  "story": {
    "title": "Short bedtime title",
    "durationMinutes": ${durationMinutes},
    "steps": [
      { "text": "Soft narration sentence(s)", "pauseDuration": 1.0 }
    ]
  },
  "nextHeaders": [
    { "id": "kebab-case-id", "title": "Header title", "subtitle": "Optional subtitle" }
  ]
}

Requirements for "story":
- Locale: ${locale}
- Theme: ${themeTitle}
${subtitleLine}
- Optimize for sleep onset: low-arousal, calm, safe, repetitive, no cliffhangers.
- Avoid fear, danger, urgency, conflict, loud surprises, or emotionally activating twists.
- Keep narration flowing like one continuous bedtime story.
- Write enough actual narration for the full duration.
- Target total narration length: ${minWordTarget}-${maxWordTarget} words.
- If the story is too short, add more gentle descriptive narration (do NOT add filler silence).
- Use short-to-moderate pauseDuration values, usually around 0.8 to 1.3 seconds.
- Keep most paragraph/step transitions close to about 1 second.
- Only use a longer breath pause when truly needed for natural phrasing.
- Total timing should fit ${durationMinutes} minutes (${durationMinutes * 60} seconds) closely.
- Balance BOTH spoken text length and pauseDuration values so the story doesn't end early.
- Keep guidance non-medical and non-diagnostic.
- Story quality must feel premium and specific, not generic.
- Use a clear arc with four phases:
  1) Arrival in place
  2) Gentle exploration
  3) Deepening calm repetition
  4) Soft fade-out
- Keep one consistent setting and perspective for the full story.
- Reuse the same 3-5 motifs throughout (objects, sounds, textures, light).
- Include vivid but calm sensory detail (sound, touch, temperature, light, scent).
- Use concrete imagery over abstract wellness language.
- Forbidden generic filler phrases:
  - "you are safe here"
  - "let go of stress"
  - "drift into sleep" (more than once)
  - "relax your body" (repeated)
  - "calm your mind" (repeated)
- Avoid list-like instruction tone. It must read like a story, not a script of commands.
- Avoid introducing new locations/characters after 60% of the story.
- Final 20% should gradually simplify language, slow imagery, and gently taper to near-silence.

Requirements for "nextHeaders":
- Return exactly 6 headers.
- Keep each title short and evocative (2-6 words).
- Ensure they are substantially different from each other.
- Do not repeat these excluded titles:
${excluded}
- If subtitle is provided, keep it under 12 words.
- Headers must feel distinctive and specific, not generic wellness labels.
- Avoid generic titles like "Calm Night", "Peaceful Sleep", "Deep Rest", "Gentle Dreams".
- Prefer unusual-but-soothing hooks tied to place, object, or quiet action.

Respond ONLY with raw JSON, no markdown.
`.trim();
}

function normalizeSleepHeaders(rawHeaders, excludedTitles) {
    const excluded = new Set(
        excludedTitles.map((t) => t.trim().toLowerCase()).filter(Boolean)
    );

    const fallback = fallbackSleepHeaders(excludedTitles);
    if (!Array.isArray(rawHeaders)) {
        return fallback;
    }

    const normalized = [];
    for (const item of rawHeaders) {
        const title = typeof item?.title === "string" ? item.title.trim() : "";
        if (!title) continue;
        if (excluded.has(title.toLowerCase())) continue;

        const subtitle = typeof item?.subtitle === "string" ? item.subtitle.trim() : "";
        const id = typeof item?.id === "string" && item.id.trim()
            ? item.id.trim()
            : slugify(title);

        normalized.push({
            id,
            title,
            subtitle: subtitle || null
        });
    }

    const deduped = [];
    const seen = new Set();
    for (const item of normalized) {
        const key = item.title.toLowerCase();
        if (seen.has(key)) continue;
        seen.add(key);
        deduped.push(item);
    }

    if (deduped.length >= 6) {
        return deduped.slice(0, 6);
    }

    const extras = fallbackSleepHeaders([...excludedTitles, ...deduped.map((h) => h.title)]);
    return deduped.concat(extras).slice(0, 6);
}

function fallbackSleepHeaders(excludedTitles = []) {
    const defaults = [
        { id: "astronomers-attic", title: "The Astronomer's Attic", subtitle: "Dusty maps, brass lenses, and starlight on wood" },
        { id: "midnight-tram", title: "Last Tram Through the Rain", subtitle: "Window fog, dim stations, and quiet city hum" },
        { id: "orchard-watchtower", title: "The Orchard Watchtower", subtitle: "Apple leaves, lantern glow, and slow night wind" },
        { id: "paper-lantern-river", title: "Paper Lantern River", subtitle: "Boats drifting under bridges in warm silence" },
        { id: "salt-glasshouse", title: "The Salt Glasshouse", subtitle: "Sea mist on panes and soft echoing steps" },
        { id: "winter-post-office", title: "Winter Post Office", subtitle: "Unsent letters, ticking clock, and stove heat" },
        { id: "cedar-bathhouse", title: "The Cedar Bathhouse", subtitle: "Steam, cedar walls, and still midnight water" },
        { id: "lighthouse-kitchen", title: "Kitchen in the Lighthouse", subtitle: "Kettle warmth and waves turning below" },
        { id: "snowfield-observatory", title: "Snowfield Observatory", subtitle: "Red lamps, wool blankets, and distant sky" },
        { id: "night-greenmarket", title: "Greenmarket After Closing", subtitle: "Crates, canvas awnings, and soft street rain" },
        { id: "quarry-garden", title: "The Quarry Garden", subtitle: "Stone paths, moss walls, and moonlit water" },
        { id: "river-mill-loft", title: "Loft Above the River Mill", subtitle: "Timber beams and a wheel turning slowly" }
    ];

    const excluded = new Set(
        excludedTitles.map((t) => t.trim().toLowerCase()).filter(Boolean)
    );

    const available = defaults.filter((item) => !excluded.has(item.title.toLowerCase()));
    const source = available.length > 0 ? available : defaults;
    return shuffle(source).slice(0, 6);
}

function slugify(value) {
    return value
        .toLowerCase()
        .replace(/[^a-z0-9\s-]/g, "")
        .trim()
        .replace(/\s+/g, "-")
        .replace(/-+/g, "-")
        .slice(0, 48);
}

function shuffle(arr) {
    const copy = [...arr];
    for (let i = copy.length - 1; i > 0; i -= 1) {
        const j = Math.floor(Math.random() * (i + 1));
        [copy[i], copy[j]] = [copy[j], copy[i]];
    }
    return copy;
}

export default app;
