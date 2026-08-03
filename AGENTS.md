<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

# Stitchly project rules

- Treat this repository as one product with two clients: the Next.js web app and the native SwiftUI app under `ios/`.
- Read the nearest nested `AGENTS.md` before changing files in `src/`, `migrations/`, or `ios/`.
- Read `.codex/memory/README.md` for the project map and route to only the relevant memory file. Dated release state is evidence to re-check, not permanent truth.
- Preserve `references/`; its contents are user-owned source material and may remain untracked.
- Never print, copy into source, or commit anything under `credentials/`, `.env.local`, or `.neon/`.
- Keep email/password and Sign in with Apple as the native authentication methods. Do not reintroduce a Google/browser authentication flow in iOS.
- Prefer native Apple UI and behavior in iOS. The product palette may brand native controls, but accessibility and platform conventions win over web pixel matching.
- Every asynchronous user journey must expose an animated loading state with operation-specific copy. Mutations must prevent duplicate actions while active.
- Update the relevant Stitchly MVP Linear issue with concrete evidence as work progresses. Do not mark beta, review, or release tasks complete without authoritative App Store Connect evidence.
- Before claiming release readiness, verify the exact build, TestFlight groups, App Store version relationship, CI result, signing, privacy declarations, and current review state.
