# Phase 4 AI — gate checklist

Phase 4 (AI highlights, mood analytics, automated “best moments”) is **not** required for beta. Treat every AI-facing feature as **off the beta path** until this checklist is satisfied; do not ship model-backed flows to production families as part of the core beta.

Use this gate before investing in models, storage, or Firebase extensions.

## Privacy

- Document what text or metadata leaves the device (diary bodies, chat, aggregate counts only, etc.).
- Choose region(s) for any third-party API and record data processing agreements.
- Add in-app disclosure if content is sent to a model provider; support opt-out if families expect it.

## Cost and quotas

- Estimate tokens per active family per week from realistic usage, not demos.
- Set monthly spend alerts on GCP / provider billing.
- Prefer batch or scheduled jobs over per-tap calls for expensive operations.

## Technical

- Prefer Firebase/GCP-native options (Callable Functions + Vertex) or a single vetted API; avoid many ad hoc keys in the client.
- Redact PII in prompts where the product allows; never log raw diary text at `debug` in production.

## Product

- Ship only after core loops (chat, tasks, diary, polls) show retention with real families; AI should not block stability or store release.

When all items are satisfied, treat Phase 4 as a **separate epic** with its own milestones and QA, not as part of the beta checklist.
