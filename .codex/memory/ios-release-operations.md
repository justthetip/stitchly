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
