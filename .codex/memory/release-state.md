# Release state

Last verified: 2026-08-17 (Europe/London).

This file is a navigation aid, not authority. Re-query external systems before changing release state.

## Verified snapshot

- The current working tree removes Home as a destination and opens into Projects. Explore shows visually separated active and completed demo projects; the active overview explains outside-PDF import and standardization before the reader. The reader includes tappable glossary shorthand, a material checklist, and private step-linked on-device photos. Patterns now has a mock marketplace and owned-pattern view. Projects, Patterns, and Account use shared craft-specific outline SVG tab icons on web and iOS.
- Fruity Friends is the featured active demo and Mini Whale supplies the completed-project example. The offline starter catalog also contains Perfect Granny Square with the product-supplied PDFs and covers. Stable fixtures contain 81, 12 and 10 instructions respectively.
- Build 33 fixes the external build-32 launch crash caused by fractional ISO-8601 dates in the bundled demo catalog, adds system-aware light/dark themes across the native app, and installs Firebase Crashlytics 12.17.0 with collection enabled and a Release dSYM upload phase. The implementation commit is `5db409a` on `origin/main`; hosted Quality run `32010482350` passed both web and iOS jobs. GitHub issue #1 records the completed dark-mode ticket because the available Linear credentials expose only the unrelated Yoto workspace.
- Local build-33 release verification passed all 55 native unit/UI tests on an iPhone 16e / iOS 26.3.1 simulator, including the fractional-date regression and paired light/dark contrast, hit-region, and clipping audits. Web lint and all 27 web tests passed.
- The signed archive is version 1.0 build 33 with the App Store profile, valid Apple Distribution signature, expected team/bundle identity, 18 bundled privacy manifests, and Firebase configuration. The Stitchly binary UUID `CD6472E8-B833-3358-88FB-022C882589D0` exactly matches its dSYM, and Crashlytics accepted that dSYM explicitly.
- Native Analytics uses the no-IDFA `FirebaseAnalyticsCore` product. The build-33 archive excludes GoogleAdsOnDeviceConversion and GoogleAppMeasurementIdentitySupport. Xcode still emits the two upstream static-framework dSYM false positives for FirebaseAnalytics and GoogleAppMeasurement; Firebase 12.17.0 does not publish matching dSYMs, so app and Crashlytics symbol upload remain enabled and no synthetic symbols are used.
- App Store Connect processed build 33 as `VALID`. Its en-GB/en-US “What to Test” notes are populated, it belongs to both `Stitchly Internal` and `Stitchly External Beta`, its Beta App Review is approved, and both internal and external states report `IN_BETA_TESTING` with auto-notify enabled.
- App Store version 1.0 remains `WAITING_FOR_REVIEW` with build 10 selected. The current review submission was submitted on 2026-08-03 and remains untouched.
- Five 6.7-inch App Store screenshots are uploaded, including pattern overview and section navigation.
- The canonical Vercel production alias is ready with a full-page render fallback for PDFs without suitable embedded rasters, plus generated brand-reference fallbacks for patterns and projects. The repair reprocessed the one existing pattern missing a cover successfully (`1 examined, 1 created, 0 failed`).
- The canonical Vercel aliases serve a `READY` production deployment containing commit `5b5dac4`. This repaired a latent TypeScript narrowing failure that had blocked automatic deployments and deployed the completion-telemetry allow-list fix from `15a27bf`.
- A privacy-safe seven-day Neon baseline exists. Build 21 has 2 app opens across 2 owners, 3 reader opens across 2 owners, and 4 reader-progress events across 1 owner; no MetricKit diagnostic payload or reported-crash event exists across the window. Treat missing diagnostics separately from a proven crash-free population.
- Linear LUK-125 contains implementation, visual, local test, archive, and build-32 TestFlight evidence for the shared tab icons. LUK-129 tracks the remaining upstream Firebase/Xcode static-framework dSYM warnings and records the no-IDFA mitigation. LUK-124 contains build-31 marketplace distribution evidence. LUK-126 remains In Progress for the broader parity audit; LUK-127 and LUK-128 remain in the backlog. LUK-108 remains In Progress for the explicit mutation/security inventory, allow-listed guest-conversion telemetry and pending-action replay rules; do not describe that observability slice as complete.
- Direct product-owner supply and selection of the three PDFs/covers is recorded, but it is not independent legal proof of redistribution rights. The public App Store Connect API still does not prove the complete App Privacy questionnaire state.

## Next release checks

1. Re-query App Store version 1.0 review state and selected build.
2. If 1.0 is approved/released, record the authoritative transition time, verify the public listing, and run the documented clean-install production smoke test against build 10.
3. If Apple rejects the submission, capture the rejection verbatim in a linked Linear blocker before changing code or metadata.
4. Check App Store Connect, support, Vercel/Neon health, and privacy-safe telemetry at release, +1 hour, +24 hours, and +72 hours. Collect actual beta/production crash evidence separately from Apple’s approval state.
5. If declarations change, confirm App Privacy questionnaire state through an authoritative App Store Connect surface; the public API and bundled privacy manifest do not prove the questionnaire state.
