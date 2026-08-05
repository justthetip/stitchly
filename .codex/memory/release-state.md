# Release state

Last verified: 2026-08-05 (Europe/London).

This file is a navigation aid, not authority. Re-query external systems before changing release state.

## Verified snapshot

- Repository branch `main` includes guest-demo product commit `109507a` and hosted-simulator repair `d6cabd9`. The product now exposes Home, Library, Projects, overviews and the focused reader to signed-out users; gates private/account mutations contextually; saves demo-reader progress only on device; clearly labels the demo throughout; and defaults email authentication to account creation with a compact Apple/email chooser.
- Fruity Friends is the featured bundled demo and sole preloaded project. The offline starter catalog also contains Mini Whale and Perfect Granny Square with the product-supplied PDFs and covers. Stable fixtures contain 81, 12 and 10 instructions respectively.
- Local build-24 release verification passed the complete native unit/UI suite. Web lint, 16 tests and the production build/typecheck passed after the final web changes. GitHub Quality run `30981719613` passed both hosted iOS and web jobs for commit `d6cabd9`; that commit contains the exact build-24 product source plus a workflow-only simulator-selection repair.
- The signed archive was verified as version 1.0 build 24 with the App Store profile, valid Apple Distribution signature and expected team/bundle identity. Upload completed successfully and App Store Connect processed build 24 as `VALID`.
- TestFlight builds 22, 23 and 24 were cut during the guest-demo iteration. Build 24 has en-GB/en-US “What to Test” notes, belongs to both `Stitchly Internal` and `Stitchly External Beta`, and reports `IN_BETA_TESTING` for both internal and external states.
- App Store version 1.0 remains `WAITING_FOR_REVIEW` with build 10 selected. The current review submission was submitted on 2026-08-03 and remains untouched.
- Five 6.7-inch App Store screenshots are uploaded, including pattern overview and section navigation.
- The canonical Vercel production alias is ready with a full-page render fallback for PDFs without suitable embedded rasters, plus generated brand-reference fallbacks for patterns and projects. The repair reprocessed the one existing pattern missing a cover successfully (`1 examined, 1 created, 0 failed`).
- The canonical Vercel aliases serve a `READY` production deployment containing commit `5b5dac4`. This repaired a latent TypeScript narrowing failure that had blocked automatic deployments and deployed the completion-telemetry allow-list fix from `15a27bf`.
- A privacy-safe seven-day Neon baseline exists. Build 21 has 2 app opens across 2 owners, 3 reader opens across 2 owners, and 4 reader-progress events across 1 owner; no MetricKit diagnostic payload or reported-crash event exists across the window. Treat missing diagnostics separately from a proven crash-free population.
- Linear guest-demo implementation issues LUK-105, LUK-106, LUK-107, LUK-109, LUK-110, LUK-112, LUK-113 and LUK-114 are Done with build-24 evidence. LUK-104 and LUK-111 are In Review. LUK-108 remains In Progress for the explicit mutation/security inventory, allow-listed guest-conversion telemetry and pending-action replay rules; do not describe that observability slice as complete.
- Direct product-owner supply and selection of the three PDFs/covers is recorded, but it is not independent legal proof of redistribution rights. The public App Store Connect API still does not prove the complete App Privacy questionnaire state.

## Next release checks

1. Re-query App Store version 1.0 review state and selected build.
2. If 1.0 is approved/released, record the authoritative transition time, verify the public listing, and run the documented clean-install production smoke test against build 10.
3. If Apple rejects the submission, capture the rejection verbatim in a linked Linear blocker before changing code or metadata.
4. Check App Store Connect, support, Vercel/Neon health, and privacy-safe telemetry at release, +1 hour, +24 hours, and +72 hours. Collect actual beta/production crash evidence separately from Apple’s approval state.
5. If declarations change, confirm App Privacy questionnaire state through an authoritative App Store Connect surface; the public API and bundled privacy manifest do not prove the questionnaire state.
