# Release state

Last verified: 2026-08-03 (Europe/London).

This file is a navigation aid, not authority. Re-query external systems before changing release state.

## Verified snapshot

- Repository branch `main` includes auth-field commit `9977a0c` and grouped-reader/project-completion commit `f62a8b8`.
- GitHub Quality run `30847162177` completed successfully for web and iOS on `f62a8b8`.
- App Store builds 11–19 processed as `VALID`. Build 19 is available only to the `Stitchly Internal` TestFlight group with focused testing notes for grouped repeat rows, the ×32 headband repeat indicator, reader-driven project completion, and the modern native auth fields.
- App Store version 1.0 was observed as `WAITING_FOR_REVIEW` with build 10 selected. The submission was intentionally left untouched while build 17 was released only to the internal TestFlight group.
- Five 6.7-inch App Store screenshots are uploaded, including pattern overview and section navigation.
- The canonical Vercel production alias is ready with a full-page render fallback for PDFs without suitable embedded rasters, plus generated brand-reference fallbacks for patterns and projects. The repair reprocessed the one existing pattern missing a cover successfully (`1 examined, 1 created, 0 failed`).
- Native contextual onboarding and authenticated original-PDF viewing ship in build 17. Modern native auth fields ship in builds 18–19. Grouped reader ranges and automatic final-step project completion ship in build 19. The final local native suites passed 7/7 unit tests and 21/21 UI tests, including accessibility audits.
- Linear issues LUK-82 through LUK-100 are Done with implementation and release evidence. LUK-78 is the only remaining Backlog issue and is blocked on public App Store availability.

## Next release checks

1. Re-query App Store version 1.0 review state and selected build.
2. If 1.0 is approved/released, treat build 19 changes as a follow-up version rather than mutating the reviewed binary.
3. If Apple rejects the submission, capture the rejection verbatim in a linked Linear blocker before changing code or metadata.
4. Confirm external beta status and actual tester feedback/crash-free evidence before closing TestFlight milestone work.
5. Confirm App Privacy questionnaire state through an authoritative App Store Connect surface before closing its Linear issue.
