# iOS release operations

## Safe prerequisites

- Bundle identifier: `com.lukejeffproduct.stitchly`.
- Marketing version currently uses the `1.0` line; build number is set in `ios/project.yml`.
- Signing assets and App Store Connect API material live only in ignored `credentials/` files.
- Never echo environment values or private-key contents. It is safe to source the ignored environment file inside a single command after validating its key path remains under this repository's `credentials/` directory.

## Generate and verify

Use the lightest verification mode that matches the current decision point:

- **Iterate** — while tuning visuals, copy, or a narrow interaction: compile the app and install it on the simulator. Run only a directly affected test when the behavior cannot be judged reliably by inspection.
- **Checkpoint** — when finishing a meaningful feature: run affected unit tests, affected UI journeys, and the relevant Dynamic Type/VoiceOver/accessibility audit. Record any intentionally deferred unrelated suite failure.
- **Release** — before a TestFlight/App Store upload or a release-readiness claim: run the complete native unit/UI suite plus the web checks below. No iteration or checkpoint result substitutes for this gate.

Iteration compile:

```sh
xcodebuild build -project ios/Stitchly.xcodeproj -scheme Stitchly \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.3.1'
```

Checkpoint tests should use `-only-testing:Target/TestCase/testName` (or the narrowest relevant test class) rather than starting the complete UI suite.

Release verification from the repository root:

```sh
(cd ios && xcodegen generate)
xcodebuild test -project ios/Stitchly.xcodeproj -scheme Stitchly \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.3.1'
npm run lint
npm test
```

The simulator model/OS may change; inspect available destinations rather than assuming it exists. GitHub Actions is the hosted source of truth after pushing.

## Archive

Automatic archive signing may ask Apple for a development profile and fail when the team has no registered devices. The working App Store archive uses the installed distribution identity and App Store profile explicitly:

```sh
xcodebuild archive \
  -project ios/Stitchly.xcodeproj \
  -scheme Stitchly \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath ios/build/Stitchly-BUILD-release.xcarchive \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY='Apple Distribution' \
  PROVISIONING_PROFILE_SPECIFIER='com.lukejeffproduct.stitchly AppStore'
```

Use `ios/ExportOptions.plist` and the App Store Connect API environment for export/upload. Validate every variable and the API key path before invoking `xcodebuild -exportArchive`.

## App Store Connect behavior

- A successful upload first reports that the package is processing. Poll until the build exists and its processing state is `VALID` before assigning groups or selecting it.
- Add a valid build to both internal and external beta groups and set specific “What to Test” copy.
- Selecting a build for the App Store version is a separate relationship update.
- Never replace or cancel a build when the App Store version is `WAITING_FOR_REVIEW`, `IN_REVIEW`, or another locked review state without explicit user direction. A newer build remains a TestFlight/follow-up candidate.
- Fastlane 2.237.0 may request removed relationships such as `buildDeliveries` or `betaBuildMetrics`. For reliable reads, use the underlying Spaceship Connect API with `includes: nil`.
- App Store screenshots are 1320×2868 6.7-inch captures under `ios/AppStore/Screenshots/en-US/`. Inspect generated captures before uploading. Use screenshot overwrite only when the full replacement set has been verified locally.
- The public App Store Connect API does not expose the complete App Privacy nutrition-label questionnaire. Do not claim it is complete based only on the bundled privacy manifest.

## Release evidence

For each candidate record:

- commit SHA and green hosted CI run;
- signed archive success and bundle/build versions;
- App Store processing state;
- internal and external TestFlight group membership;
- beta test notes;
- selected App Store build, if the version is editable;
- current App Store review state;
- corresponding Linear comments/status update.

## Production launch and monitoring

Before acting on an approval notification, re-query the App Store version, review submission, selected build, and release type. For an `AFTER_APPROVAL` version, record the first authoritative `READY_FOR_DISTRIBUTION`/`READY_FOR_SALE` transition as the release time; there is no separate scheduled release date. Verify the public listing and install button independently rather than treating the review state as proof of availability.

Run the production smoke test from a clean public App Store installation on a non-development physical device. Record the app version/build and device/iOS version, then verify:

1. email/password sign-in and Sign in with Apple reach the same owner-scoped account experience;
2. the example pattern or a permitted test PDF imports, review edits save, a representative cover appears, and the authenticated original PDF opens;
3. a project can be created, resumed from Home, switched between sections, advanced through a grouped repeat, noted, and completed;
4. revisiting Home, Library, Projects, and cover images uses the cached state without stale cross-account data;
5. sign-out removes private cached data and returns to native authentication.

Check launch health at release, +1 hour, +24 hours, and +72 hours:

- App Store Connect availability, crash/diagnostic reports, ratings, and reviews;
- support mail sent to `support@stitchly.app` and the public support page;
- Vercel function failures/latency and Neon health;
- privacy-safe `native_telemetry_events` aggregates by build number, event name, and time bucket: app opens; PDF import started/completed conversion; projects created; readers opened/progressed; reader completions; and MetricKit diagnostic payload/crash counts.

Never include owner IDs, pattern text, filenames, notes, credentials, or raw user content in a launch report. Compare counts and rates, and distinguish “no telemetry received” from a genuine zero.

## Rollback and urgent fixes

iOS does not support replacing an already released binary with an older build. Pausing a phased release (when one exists) or removing the app from sale are the rollback controls, and either requires an explicit release-owner decision after impact is confirmed.

For a severe production defect:

1. capture the symptom, affected app/build, timestamps, scope, and reproduction in a linked urgent Linear issue without copying private user content;
2. decide whether support guidance is sufficient or the release owner must pause/remove the app from sale;
3. branch from the released commit, apply only the verified fix, bump the marketing version to `1.0.1` (or the next editable patch version) and use a new build number;
4. run the complete native/web release gate, re-check signing/privacy/export declarations, and distribute an internal TestFlight smoke candidate before App Review submission;
5. never attach a follow-up TestFlight build to a locked review/version relationship or cancel an active submission without explicit user direction.

If Apple rejects a pre-release submission, preserve the exact rejection text and resolution-center context in Linear before changing code, metadata, or the selected build.
