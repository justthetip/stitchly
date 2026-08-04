# Release state

Last verified: 2026-08-04 (Europe/London).

This file is a navigation aid, not authority. Re-query external systems before changing release state.

## Verified snapshot

- Repository branch `main` includes build-21 checkpoint commit `64b9656`. Build 21 adds uniform padded/cropped thumbnails with protected account-scoped disk caching in Library, Projects, and Home; an obvious tappable reader-section switcher; and the approved full-size sign-in loading button with its compact stitch spinner.
- Local build-21 release verification passed 12/12 native unit tests, 22/22 native UI tests, web lint, and 13/13 web tests. GitHub Quality run `30905688819` passed both hosted iOS and web jobs for exact commit `64b9656`.
- The signed build-21 archive was verified as version 1.0 build 21 with the App Store profile, valid signature, Sign in with Apple entitlement, and bundled privacy manifest.
- App Store builds 11–21 processed as `VALID`. Build 21 has Beta App Review state `APPROVED`, en-GB/en-US “What to Test” notes, and membership in both `Stitchly Internal` and `Stitchly External Beta` TestFlight groups. It is also installed on the iPhone 16e simulator.
- App Store version 1.0 remains `WAITING_FOR_REVIEW` with build 10 selected. The current review submission was submitted on 2026-08-03 and remains untouched.
- Five 6.7-inch App Store screenshots are uploaded, including pattern overview and section navigation.
- The canonical Vercel production alias is ready with a full-page render fallback for PDFs without suitable embedded rasters, plus generated brand-reference fallbacks for patterns and projects. The repair reprocessed the one existing pattern missing a cover successfully (`1 examined, 1 created, 0 failed`).
- Native contextual onboarding and authenticated original-PDF viewing ship in build 17. Modern native auth fields ship in builds 18–21. Grouped reader ranges and automatic final-step project completion ship in build 19. Build 20 adds broader read caching, the refined loader, and representative artwork across the full pattern/project journey; build 21 adds persistent cover-image caching and the latest visible thumbnail, section-navigation, and auth-loading polish.
- Linear TestFlight issue LUK-70 is Done and has build-21 approval/group evidence. LUK-101 and LUK-103 are Done. LUK-78 is the only remaining backlog item and is externally blocked on public App Store approval/availability.

## Next release checks

1. Re-query App Store version 1.0 review state and selected build.
2. If 1.0 is approved/released, treat build 20 changes as a follow-up version rather than mutating the reviewed binary.
3. If Apple rejects the submission, capture the rejection verbatim in a linked Linear blocker before changing code or metadata.
4. Collect actual external tester feedback and crash-free evidence separately from Apple’s beta approval.
5. Confirm App Privacy questionnaire state through an authoritative App Store Connect surface before closing its Linear issue.
