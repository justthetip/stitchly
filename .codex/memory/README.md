# Stitchly agent memory

This directory records durable project knowledge for future coding sessions. It contains no credentials and is safe to commit.

Read only what the task needs:

- `architecture.md` — system boundaries, data ownership, and important source locations.
- `product-decisions.md` — settled product and native UI decisions that should not be casually reversed.
- `ios-release-operations.md` — reproducible build, signing, TestFlight, and App Store workflow plus known traps.
- `release-state.md` — dated external state. Always re-query Apple, GitHub, Vercel, Neon, and Linear before acting on it.

Rules of use:

1. Durable decisions belong in the first three files.
2. Volatile build numbers, review states, and milestone percentages belong only in `release-state.md` with a date.
3. Never store private keys, passwords, tokens, reviewer credentials, personal phone numbers, or environment-variable values here.
4. Update these notes when a verified change makes them materially inaccurate; do not turn them into a chronological session transcript.
