# Stitchly for iOS

Requirements: Xcode 26, XcodeGen, and an iOS 18+ simulator.

Generate and test the project:

```sh
xcodegen generate --spec ios/project.yml
xcodebuild -project ios/Stitchly.xcodeproj -scheme Stitchly \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ios/DerivedData CODE_SIGNING_ALLOWED=NO build test
```

The production API is `https://stitchly-application.vercel.app`. Native sessions are opaque bearer tokens stored in the iOS Keychain. Apple, App Store Connect, database, and Blob credentials stay under the ignored `credentials/` directory or in Vercel environment variables.

Firebase Analytics is integrated through Swift Package Manager and configured at app launch from the bundled `GoogleService-Info.plist`. The app uses Firebase's automatically collected analytics events only; Stitchly does not send pattern text, filenames, notes, account identifiers, or other user content as custom Firebase event parameters.

## Release smoke test

1. Install fresh and sign in with Apple.
2. Import a PDF below 25 MB and confirm parsed sections appear.
3. Create a project, verify its materials checklist, advance the reader, open a shorthand glossary term, add a note and private step photo, then relaunch and confirm progress and the photo stay attached to that step.
4. Verify Dynamic Type at the largest accessibility size and complete the reader flow with VoiceOver.
5. Sign out and back in, then verify the same private data returns.
6. Confirm account deletion requires confirmation and removes the account.

The checked-in unit and UI suites cover production TLS, demo data integrity, native authentication controls, the project-to-reader journey, reader progress, the library, largest Dynamic Type, and automated accessibility audits for the sign-in and reader screens. GitHub Actions repeats the web and iOS checks on every push and pull request.

The bundled privacy manifest declares account identifiers, user-provided pattern content, product interaction, performance, and crash diagnostics. Stitchly does not track users across other companies' apps or websites. Firebase Analytics provides automatic product analytics, while Stitchly's first-party operational telemetry contains only allow-listed event names, app/build versions, and non-sensitive counters; pattern text, filenames, and notes are prohibited from both.
