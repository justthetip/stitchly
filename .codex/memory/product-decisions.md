# Product decisions

## Native scope

- The iOS MVP mirrors the useful web journeys but is not a web-wrapper or pixel copy.
- Use native SwiftUI components wherever possible.
- The bottom navigation uses the platform-native tab bar/liquid-glass presentation.
- Native authentication is email/password plus Sign in with Apple. Google auth remains available on web only.
- Patterns need a complete native overview grouped into source-order sections; alphabetical section sorting is incorrect.
- The focused reader must let a maker jump directly between sections and persist the selected position.
- Original PDF terminology and labels matter. Do not normalize away meaningful row, round, setup, finishing, size, or section labels.

## Visual system

- Brand direction comes from `references/WhatsApp Image 2026-07-01 at 08.38.15.jpeg` and the checked-in assets.
- Core colors are warm orange, pink, sky blue, cream, and dark navy ink.
- The icon and illustrations should feel playful and yarn-craft-specific; functional UI stays clean and native.
- Do not sacrifice contrast, Dynamic Type, VoiceOver semantics, or native hit targets for brand color. Orange is unsuitable for small text on light/translucent backgrounds; use navy ink there.

## Loading and errors

- A spinner without context is insufficient.
- Initial loads use a native animated state with a concise title and an explanation of the resource being loaded.
- Existing content remains visible during refreshes with a compact progress banner.
- PDF import distinguishes upload, PDF analysis/section extraction, and library refresh.
- Progress saves, note saves, project creation, authentication, session restore, sign-out, and deletion communicate active work.
- Disable conflicting or duplicate mutation controls until the operation finishes.
- Loading, empty, loaded, and error states must be distinct and accessible.

## Privacy and review

- User PDFs, extracted pattern content, progress, and notes are private and linked to the account for app functionality.
- Product interaction, performance, and crash diagnostics may be collected for analytics; no tracking or tracking domains.
- Account deletion must remove the account and user data and remain explicitly confirmed.
