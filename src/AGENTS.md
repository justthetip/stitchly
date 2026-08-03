# Web and backend agent instructions

- This repository uses Next.js 16 with breaking changes. Read the relevant installed guide under `node_modules/next/dist/docs/` before changing framework APIs, routing, caching, middleware, or file conventions.
- Preserve authenticated, owner-scoped access on every pattern, project, note, upload, and telemetry route.
- Never return private Blob URLs as public resources. Stream private source files through authenticated routes.
- Native API changes must remain compatible with the Codable models under `ios/Stitchly/Models.swift`, or update and test both sides together.
- Database schema changes require a new append-only migration under `migrations/`.
- Pattern extraction changes require regression coverage against `fixtures/pattern-extraction/` and the ground truth in `project-docs/`.
- Keep native bearer tokens opaque, revocable, expiring, and stored server-side only as designed; never log tokens or credentials.
- Telemetry must stay allow-listed and content-free.
- Run `npm run lint`, `npm test`, and the relevant build/type checks after changes.
