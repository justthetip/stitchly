# Release state

Last verified: 2026-08-04 (Europe/London).

This file is a navigation aid, not authority. Re-query external systems before changing release state.

## Verified snapshot

- Repository branch `main` includes auth-field commit `9977a0c`, grouped-reader/project-completion commit `f62a8b8`, and the first branded-loader implementation `0a2a305`; a smaller transparent loader refinement is in local iteration.
- GitHub Quality run `30847162177` completed successfully for web and iOS on `f62a8b8`.
- App Store builds 11–19 processed as `VALID`. Build 19 has Beta App Review state `APPROVED` and is assigned to both `Stitchly Internal` and `Stitchly External Beta` TestFlight groups.
- App Store version 1.0 remains `WAITING_FOR_REVIEW` with build 10 selected. The current review submission was submitted on 2026-08-03 and remains untouched.
- Five 6.7-inch App Store screenshots are uploaded, including pattern overview and section navigation.
- The canonical Vercel production alias is ready with a full-page render fallback for PDFs without suitable embedded rasters, plus generated brand-reference fallbacks for patterns and projects. The repair reprocessed the one existing pattern missing a cover successfully (`1 examined, 1 created, 0 failed`).
- Native contextual onboarding and authenticated original-PDF viewing ship in build 17. Modern native auth fields ship in builds 18–19. Grouped reader ranges and automatic final-step project completion ship in build 19. The final local native suites passed 7/7 unit tests and 21/21 UI tests, including accessibility audits.
- Linear TestFlight issue LUK-70 is Done and now has authoritative external-beta approval/group evidence. LUK-78 remains blocked on public App Store availability; LUK-101 and LUK-103 are actionable product backlog work.

## Next release checks

1. Re-query App Store version 1.0 review state and selected build.
2. If 1.0 is approved/released, treat build 19 changes as a follow-up version rather than mutating the reviewed binary.
3. If Apple rejects the submission, capture the rejection verbatim in a linked Linear blocker before changing code or metadata.
4. Collect actual external tester feedback and crash-free evidence separately from Apple’s beta approval.
5. Confirm App Privacy questionnaire state through an authoritative App Store Connect surface before closing its Linear issue.
