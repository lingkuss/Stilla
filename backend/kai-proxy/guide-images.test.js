import test from "node:test";
import assert from "node:assert/strict";
import express from "express";
import { registerGuideImages, guideImageModel } from "./guide-images.js";

const png = Buffer.from([137,80,78,71,13,10,26,10,1,2,3]);
class MemoryKV {
    values = new Map();
    async set(key, value) {
        if (this.values.has(key)) return null;
        this.values.set(key, value);
        return "OK";
    }
    async eval(script, _count, key, owner) {
        if (script.includes("INCR")) {
            const value = (this.values.get(key) || 0) + 1;
            this.values.set(key, value);
            return value;
        }
        if (this.values.get(key) === owner) this.values.delete(key);
        return 1;
    }
}
async function fixture(t, operation = async () => ({ data: [{ b64_json: png.toString("base64") }] })) {
    const app = express();
    const calls = [];
    const kv = new MemoryKV();
    const client = Object.fromEntries(["generate", "edit"].map(method => [method, async options => {
        calls.push({ method, options });
        return operation(options);
    }]));
    registerGuideImages(app, { kv, client, authorize: (req, res, next) => {
        if (req.headers.authorization !== "Bearer test") return res.status(401).end();
        req.auth = { installationId: "test-device" };
        next();
    } });
    const server = app.listen(0, "127.0.0.1");
    await new Promise(resolve => server.once("listening", resolve));
    t.after(() => new Promise(resolve => server.close(resolve)));
    const url = `http://127.0.0.1:${server.address().port}/kai/guide/image`;
    const request = (body, authorized = true) => fetch(url, { method: "POST", headers: {
        "Content-Type": "application/json", ...(authorized ? { Authorization: "Bearer test" } : {}),
    }, body: JSON.stringify(body) });
    return { request, calls, kv };
}

test("rejects unauthenticated requests before any paid call", async t => {
    const f = await fixture(t);
    assert.equal((await f.request({ description: "A fox" }, false)).status, 401);
    assert.equal(f.calls.length, 0);
});
test("generates one transparent Sunburst PNG, ignores client model overrides", async t => {
    const f = await fixture(t);
    const response = await f.request({ description: "A fox", model: "other", n: 100 });
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("content-type"), "image/png");
    assert.equal(response.headers.get("cache-control"), "no-store");
    assert.deepEqual(Buffer.from(await response.arrayBuffer()), png);
    assert.equal(f.calls.length, 1);
    assert.equal(f.calls[0].options.model, guideImageModel);
    assert.equal(f.calls[0].options.background, "transparent");
    assert.equal(f.calls[0].options.n, 1);
    assert.equal(f.calls[0].options.quality, "medium");
});
test("reference-only requests use edits and preserve uploaded bytes", async t => {
    const f = await fixture(t);
    assert.equal((await f.request({ referenceImage: png.toString("base64") })).status, 200);
    assert.equal(f.calls[0].method, "edit");
    assert.equal(f.calls[0].options.image.type, "image/png");
    assert.deepEqual(Buffer.from(await f.calls[0].options.image.arrayBuffer()), png);
});
test("invalid or oversized inputs never reach the provider", async t => {
    const f = await fixture(t);
    for (const body of [{}, [], { description: "x".repeat(2001) }, { referenceImage: "not base64" }, { referenceImage: Buffer.from("text").toString("base64") }]) {
        assert.equal((await f.request(body)).status, 400);
    }
    assert.equal((await f.request({ referenceImage: "a".repeat(2_200_000) })).status, 413);
    assert.equal(f.calls.length, 0);
});
test("simultaneous requests cannot duplicate a paid generation", async t => {
    let finish, began;
    const started = new Promise(resolve => { began = resolve; });
    const f = await fixture(t, () => { began(); return new Promise(resolve => { finish = resolve; }); });
    const first = f.request({ description: "A fox" });
    await started;
    assert.equal((await f.request({ description: "A fox" })).status, 409);
    finish({ data: [{ b64_json: png.toString("base64") }] });
    assert.equal((await first).status, 200);
    assert.equal(f.calls.length, 1);
});
test("hourly limit persists across requests", async t => {
    const f = await fixture(t);
    for (let i = 0; i < 15; i++) assert.equal((await f.request({ description: "A fox" })).status, 200);
    assert.equal((await f.request({ description: "A fox" })).status, 429);
    assert.equal(f.calls.length, 15);
});
test("provider failures are sanitized and release the active lock", async t => {
    const f = await fixture(t, async () => { throw Object.assign(new Error("private provider detail"), { status: 403, code: "model_not_found" }); });
    for (let i = 0; i < 2; i++) {
        const response = await f.request({ description: "A fox" });
        assert.equal(response.status, 502);
        assert.deepEqual(await response.json(), { code: "model_unavailable" });
    }
    assert.equal(f.calls.length, 2);
});
test("rejects missing or corrupt provider output", async t => {
    const f = await fixture(t, async () => ({ data: [{ b64_json: Buffer.from("not an image").toString("base64") }] }));
    const response = await f.request({ description: "A fox" });
    assert.equal(response.status, 502);
    assert.deepEqual(await response.json(), { code: "invalid_image" });
});
