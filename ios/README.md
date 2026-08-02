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

## Release smoke test

1. Install fresh and sign in with Apple.
2. Import a PDF below 25 MB and confirm parsed sections appear.
3. Create a project, advance the reader, add a note, then relaunch and confirm progress.
4. Verify Dynamic Type at the largest accessibility size and complete the reader flow with VoiceOver.
5. Sign out and back in, then verify the same private data returns.
6. Confirm account deletion requires confirmation and removes the account.

The checked-in unit and UI suites cover production TLS, demo data integrity, the project-to-reader journey, reader progress, the library, and an accessibility Dynamic Type launch. GitHub Actions repeats the web and iOS checks on every push and pull request.
