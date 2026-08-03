# Release state

Last verified: 2026-08-03 (Europe/London).

This file is a navigation aid, not authority. Re-query external systems before changing release state.

## Verified snapshot

- Repository branch `main` includes commit `2954968` with informative native loading states.
- GitHub Quality run `30771052685` completed successfully for web and iOS.
- App Store builds 11–16 processed as `VALID`. Builds 11 through 16 are available to the `Stitchly Internal` TestFlight group with checkpoint-specific testing notes; build 16 adds native project/pattern deletion and ships alongside the live PDF-cover repair/backfill.
- App Store version 1.0 was observed as `WAITING_FOR_REVIEW` with build 10 selected. The submission was intentionally left untouched while build 16 was released only to the internal TestFlight group.
- Five 6.7-inch App Store screenshots are uploaded, including pattern overview and section navigation.
- The canonical Vercel production alias includes authenticated representative PDF cover extraction and the owner-scoped starter-pattern endpoint. The raw-image thumbnail bug was repaired and all seven existing PDF patterns were backfilled successfully. Neon migrations 005 and 006 were verified on the linked branch.
- Linear issues LUK-88, LUK-91, LUK-92, and LUK-93 are In Review. LUK-75 remains in progress while App Review is monitored.

## Next release checks

1. Re-query App Store version 1.0 review state and selected build.
2. If 1.0 is approved/released, treat build 10 changes as a follow-up version rather than mutating the reviewed binary.
3. If Apple rejects the submission, capture the rejection verbatim in a linked Linear blocker before changing code or metadata.
4. Confirm external beta status and actual tester feedback/crash-free evidence before closing TestFlight milestone work.
5. Confirm App Privacy questionnaire state through an authoritative App Store Connect surface before closing its Linear issue.
