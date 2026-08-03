# Release state

Last verified: 2026-08-03 (Europe/London).

This file is a navigation aid, not authority. Re-query external systems before changing release state.

## Verified snapshot

- Repository branch `main` includes feature commit `ef9f4c3` and backfill-runner repair `dfcf40e`.
- GitHub Quality run `30836848292` completed successfully for web and iOS on `dfcf40e`.
- App Store builds 11–17 processed as `VALID`. Build 17 is available only to the `Stitchly Internal` TestFlight group with focused testing notes for PDF cover rendering, generated fallbacks, contextual native onboarding, and original-PDF viewing.
- App Store version 1.0 was observed as `WAITING_FOR_REVIEW` with build 10 selected. The submission was intentionally left untouched while build 17 was released only to the internal TestFlight group.
- Five 6.7-inch App Store screenshots are uploaded, including pattern overview and section navigation.
- The canonical Vercel production alias is ready with a full-page render fallback for PDFs without suitable embedded rasters, plus generated brand-reference fallbacks for patterns and projects. The repair reprocessed the one existing pattern missing a cover successfully (`1 examined, 1 created, 0 failed`).
- Native contextual onboarding and authenticated original-PDF viewing ship in build 17. The local final suites passed 19/19 iOS tests and 13/13 web tests, plus lint and the Next.js production build.
- Linear issues LUK-82 through LUK-98 are Done with implementation and release evidence. LUK-78 is the only remaining Backlog issue and is blocked on public App Store availability.

## Next release checks

1. Re-query App Store version 1.0 review state and selected build.
2. If 1.0 is approved/released, treat build 17 changes as a follow-up version rather than mutating the reviewed binary.
3. If Apple rejects the submission, capture the rejection verbatim in a linked Linear blocker before changing code or metadata.
4. Confirm external beta status and actual tester feedback/crash-free evidence before closing TestFlight milestone work.
5. Confirm App Privacy questionnaire state through an authoritative App Store Connect surface before closing its Linear issue.
