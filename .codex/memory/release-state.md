# Release state

Last verified: 2026-08-07 (Europe/London).

This file is a navigation aid, not authority. Re-query external systems before changing release state.

## Verified snapshot

- The current working tree removes Home as a destination and opens into Projects. Explore shows visually separated active and completed demo projects; the active overview explains outside-PDF import and standardization before the reader. The reader includes tappable glossary shorthand, a material checklist, and private step-linked on-device photos. Firebase automatic analytics is initialized from the bundled iOS configuration.
- Fruity Friends is the featured active demo and Mini Whale supplies the completed-project example. The offline starter catalog also contains Perfect Granny Square with the product-supplied PDFs and covers. Stable fixtures contain 81, 12 and 10 instructions respectively.
- Local build-29 release verification passed the complete native unit/UI suite on iPhone 17 Pro / iOS 26.3.1, including the camera/photo-library presentation regression and reader accessibility audits. The repeated-row audit also passed five consecutive stress iterations. Web lint, 25 tests and the production build/typecheck passed. Shipped app-code commit `cac116d1171ea3c530a3da7af466eb52cfd59a23` is on `origin/main`; test-only commit `966209326ab8579c955071d6a7e955f91be4d80c` narrowly scopes two verified Xcode 26 repeat-fixture contrast false positives while retaining all other contrast/hit-region failures. GitHub Quality run `31179766358` passed both web and full iOS jobs for `9662093`.
- The signed archive was verified as version 1.0 build 29 with the App Store profile, valid Apple Distribution signature, expected team/bundle identity, and bundled Firebase configuration. Upload completed successfully and App Store Connect processed build 29 as `VALID`. Xcode emitted non-blocking missing-dSYM warnings for Firebase's prebuilt analytics frameworks.
- Build 29 has en-GB/en-US “What to Test” notes, belongs to both `Stitchly Internal` and `Stitchly External Beta`, and reports `IN_BETA_TESTING` for both internal and external states. Builds 27 and 28 were superseded during release-gate accessibility investigation.
- App Store version 1.0 remains `WAITING_FOR_REVIEW` with build 10 selected. The current review submission was submitted on 2026-08-03 and remains untouched.
- Five 6.7-inch App Store screenshots are uploaded, including pattern overview and section navigation.
- The canonical Vercel production alias is ready with a full-page render fallback for PDFs without suitable embedded rasters, plus generated brand-reference fallbacks for patterns and projects. The repair reprocessed the one existing pattern missing a cover successfully (`1 examined, 1 created, 0 failed`).
- The canonical Vercel aliases serve a `READY` production deployment containing commit `5b5dac4`. This repaired a latent TypeScript narrowing failure that had blocked automatic deployments and deployed the completion-telemetry allow-list fix from `15a27bf`.
- A privacy-safe seven-day Neon baseline exists. Build 21 has 2 app opens across 2 owners, 3 reader opens across 2 owners, and 4 reader-progress events across 1 owner; no MetricKit diagnostic payload or reported-crash event exists across the window. Treat missing diagnostics separately from a proven crash-free population.
- Linear issues LUK-121 and LUK-61 contain build-29 TestFlight and hosted-CI evidence for the photo picker fix, accessibility follow-up and Firebase runtime verification. LUK-118, LUK-119 and LUK-120 contain build-26 evidence. Guest-demo implementation issues LUK-105, LUK-106, LUK-107, LUK-109, LUK-110, LUK-112, LUK-113 and LUK-114 are Done with build-24 evidence. LUK-104 and LUK-111 are In Review. LUK-108 remains In Progress for the explicit mutation/security inventory, allow-listed guest-conversion telemetry and pending-action replay rules; do not describe that observability slice as complete.
- Direct product-owner supply and selection of the three PDFs/covers is recorded, but it is not independent legal proof of redistribution rights. The public App Store Connect API still does not prove the complete App Privacy questionnaire state.

## Next release checks

1. Re-query App Store version 1.0 review state and selected build.
2. If 1.0 is approved/released, record the authoritative transition time, verify the public listing, and run the documented clean-install production smoke test against build 10.
3. If Apple rejects the submission, capture the rejection verbatim in a linked Linear blocker before changing code or metadata.
4. Check App Store Connect, support, Vercel/Neon health, and privacy-safe telemetry at release, +1 hour, +24 hours, and +72 hours. Collect actual beta/production crash evidence separately from Apple’s approval state.
5. If declarations change, confirm App Privacy questionnaire state through an authoritative App Store Connect surface; the public API and bundled privacy manifest do not prove the questionnaire state.
