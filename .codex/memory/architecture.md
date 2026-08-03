# Architecture

## Product boundary

Stitchly turns private knitting and crochet PDF patterns into structured, section-first instructions. Users can browse patterns, create projects, follow one instruction at a time, save their place, and attach notes.

There are two first-party clients:

- `src/`: Next.js 16 web app and HTTP API.
- `ios/Stitchly/`: native SwiftUI iPhone app targeting iOS 18+.

Both clients use the production API at `https://stitchly-application.vercel.app` and the same owner-scoped Neon data.

## Backend and data

- Neon Postgres is authoritative for users, patterns, parsed instructions, projects, notes, native sessions, and telemetry.
- Vercel Blob stores original private PDFs. Do not expose Blob URLs directly to unauthenticated clients.
- Every data route must derive the authenticated user and scope reads/writes by `owner_id`.
- Database migrations are append-only in `migrations/`; never rewrite a migration that may have run remotely.
- PDF extraction uses `unpdf` followed by deterministic, section-first parsing. Regression fixtures and ground truth live under `fixtures/` and `project-docs/`.
- Native auth endpoints live under `/api/native-auth`; native bearer tokens are opaque and stored in the iOS Keychain.
- Native telemetry is deliberately allow-listed and must never include pattern text, filenames, notes, credentials, or other user content.

## Native app map

- `StitchlyApp.swift`: root routing, main tabs, shared loading components, palette.
- `AuthManager.swift`: email/password, Sign in with Apple, session restore, Keychain lifecycle.
- `APIClient.swift`: authenticated JSON requests and private PDF upload.
- `LibraryViews.swift`: pattern list, staged PDF import, section-based pattern overview.
- `ProjectViews.swift`: projects, project creation, focused reader, section jumping, progress and notes.
- `AccountView.swift`: sign-out, deletion, privacy/support links.
- `Models.swift`: API models, ordered pattern-section grouping, demo fixtures.
- `Telemetry.swift`: privacy-safe operational events.
- `StitchlyTests/` and `StitchlyUITests/`: unit, journey, loading, Dynamic Type, and accessibility coverage.

`ios/project.yml` is the source of truth for the generated Xcode project. Run XcodeGen from `ios/` or use `xcodegen generate --spec ios/project.yml` from the repository root. Do not pass the `.xcodeproj` itself as `--project`; that creates a nested project accidentally.
