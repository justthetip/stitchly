# Release state

Last verified: 2026-08-03 (Europe/London).

This file is a navigation aid, not authority. Re-query external systems before changing release state.

## Verified snapshot

- Repository branch `main` includes commit `2954968` with informative native loading states.
- GitHub Quality run `30771052685` completed successfully for web and iOS.
- App Store build 10 processed as `VALID` and is present in both internal and external TestFlight groups with loading-state test notes.
- App Store version 1.0 was observed as `WAITING_FOR_REVIEW` with build 9 selected. Apple rejected attempts to replace the selected binary while that state was active; the submission was intentionally left untouched.
- Five 6.7-inch App Store screenshots are uploaded, including pattern overview and section navigation.
- Linear issue LUK-81 is Done. LUK-75 remains in progress while App Review is monitored.

## Next release checks

1. Re-query App Store version 1.0 review state and selected build.
2. If 1.0 is approved/released, treat build 10 changes as a follow-up version rather than mutating the reviewed binary.
3. If Apple rejects the submission, capture the rejection verbatim in a linked Linear blocker before changing code or metadata.
4. Confirm external beta status and actual tester feedback/crash-free evidence before closing TestFlight milestone work.
5. Confirm App Privacy questionnaire state through an authoritative App Store Connect surface before closing its Linear issue.
