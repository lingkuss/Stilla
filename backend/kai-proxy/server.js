import express from "express";
import OpenAI from "openai";

const port = Number(process.env.PORT || 8787);
const model = process.env.OPENAI_MODEL || "gpt-4o-mini";
const proxyToken = process.env.KAI_PROXY_TOKEN || "";
const openAIKey = process.env.OPENAI_API_KEY;

if (!openAIKey) {
    throw new Error("Missing OPENAI_API_KEY");
}

const openai = new OpenAI({ apiKey: openAIKey });
const app = express();

app.use(express.json({ limit: "32kb" }));

app.get("/health", (_req, res) => {
    res.json({
        ok: true,
        service: "stilla-kai-proxy",
        model
    });
});

app.post("/kai/generate", async (req, res) => {
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
        const personalityName = typeof req.body?.personalityName === "string" ? req.body.personalityName.trim() : "Zen Minimalist";
        const personalityPrompt = typeof req.body?.personalityPrompt === "string" ? req.body.personalityPrompt.trim() : "";

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
                    content: `Generate a ${durationMinutes} minute meditation for someone feeling ${mood}.`
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

Now create a personalized meditation script in JSON format.
The JSON must follow this structure exactly:
{
  "title": "A short, poetic title",
  "durationMinutes": ${durationMinutes},
  "steps": [
    { "text": "The words to speak", "pauseDuration": 5.0 }
  ]
}
Guidelines:
- The user is feeling: ${mood}.
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
        durationMinutes,
        steps
    };
}

export default app;
