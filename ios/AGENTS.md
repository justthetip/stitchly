# Native iOS agent instructions

- Read `../.codex/memory/product-decisions.md` and `../.codex/memory/ios-release-operations.md` before substantial native or release work.
- `project.yml` is authoritative. Regenerate `Stitchly.xcodeproj` after changing build settings, entitlements, sources, or version numbers.
- Use SwiftUI and Apple frameworks; avoid web views and custom replicas of native controls.
- Keep authentication to email/password and Sign in with Apple.
- Preserve section order from instruction positions. A pattern section navigator must jump to the first instruction and save progress.
- Every async operation requires visible, operation-specific loading feedback and duplicate-action protection. Reuse `LoadingStateView`, `LoadingBanner`, and `LoadingButtonLabel`.
- New core journeys need UI coverage. Test Dynamic Type and accessibility for materially new layouts.
- Demo/test launch arguments may expose deterministic states for UI tests and screenshots, but must not change normal production behavior.
- Do not weaken or silence an accessibility audit to make CI pass. Fix the rendered control, contrast, sizing, or semantics.
- Before uploading, increment `CURRENT_PROJECT_VERSION`, run tests, archive with distribution signing, validate the build in App Store Connect, and update Linear with evidence.
- Never alter an active App Review submission or selected binary without checking the current state and obtaining explicit direction when the version is locked.
