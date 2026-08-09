# Product decisions

## Native scope

- The iOS MVP mirrors the useful web journeys but is not a web-wrapper or pixel copy.
- Product features ship with web/native parity by default. A platform may use its own native interaction patterns, but any intentional capability or timing difference must be explicitly approved and recorded on the feature ticket.
- Use native SwiftUI components wherever possible.
- The bottom navigation uses the platform-native tab bar/liquid-glass presentation.
- Native authentication is email/password plus Sign in with Apple. Google auth remains available on web only.
- Patterns need a complete native overview grouped into source-order sections; alphabetical section sorting is incorrect.
- The focused reader must let a maker jump directly between sections and persist the selected position.
- Guests can advance, go back, and jump between sections in the bundled demo project without authenticating. Save that demo reader position only on the device; cloud sync, notes, project completion, and private project creation remain account actions.
- Bundled demo patterns and projects are guest-only. Once authentication succeeds, Library, Projects, counts, search, and resume surfaces show only owner-scoped data; a new or empty account sees import/project empty-state calls to action. Signing out restores the guest demos without merging local progress into the account.
- Projects is the default landing destination on web and iOS; there is no separate Home screen or Home tab. Guest Projects shows both an in-progress demo and a completed demo, visually separated by state, so the product journey is immediately explorable.
- Opening the active guest demo project must show the product transformation before the reader: an external original PDF, the standardized source-order pattern, then the live project with saved progress. Authenticated project detail remains action-focused.
- Original PDF terminology and labels matter. Do not normalize away meaningful row, round, setup, finishing, size, or section labels.
- Pattern overviews expose a glossary containing only shorthand actually found in that pattern. Supported shorthand stays verbatim and becomes tappable in the reader, opening its craft explanation in a bottom sheet; unknown text remains untouched.
- Every project overview has a persistent materials checklist derived from structured yarn/tool metadata and explicit supply evidence in its instructions. Checklist state is per-project and on-device until the backend gains a materials-completion field; never invent missing supplies.
- The reader includes a private visual journal at the exact project/instruction position. Native images live in Application Support and web images in IndexedDB, with project, section, step, and date metadata. This MVP is explicitly on-device/private; any future community gallery requires opt-in publishing, moderation, and must never retroactively expose private images.

## Visual system

- Brand direction comes from `references/WhatsApp Image 2026-07-01 at 08.38.15.jpeg` and the checked-in assets.
- Core colors are warm orange, pink, sky blue, cream, and dark navy ink.
- The icon and illustrations should feel playful and yarn-craft-specific; functional UI stays clean and native.
- Do not sacrifice contrast, Dynamic Type, VoiceOver semantics, or native hit targets for brand color. Orange is unsuitable for small text on light/translucent backgrounds; use navy ink there.

## Loading and errors

- A spinner without context is insufficient.
- Initial loads that survive a 250 ms anti-flash delay use a compact transparent knitting character at roughly half the splash illustration's visual size. A sparse ring of code-native brand-colour “stitches” rotates around it; there is no full-screen colour or grey material card. The concise operation title stays visible while the fuller resource explanation remains in the combined VoiceOver label.
- Branded loading motion is implemented in SwiftUI around a static transparent raster and stops under Reduce Motion; do not introduce a GIF, video, or animation runtime casually.
- Existing content remains visible during refreshes with a compact progress banner.
- PDF import distinguishes upload, PDF analysis/section extraction, and library refresh.
- Progress saves, note saves, project creation, authentication, session restore, sign-out, and deletion communicate active work.
- Disable conflicting or duplicate mutation controls until the operation finishes.
- Loading, empty, loaded, and error states must be distinct and accessible.

## Privacy and review

- User PDFs, extracted pattern content, progress, and notes are private and linked to the account for app functionality.
- Privacy is a contextual data-handling guarantee, not the core product message. Lead with clearer pattern steps, prepared materials, saved progress, and easier stop/resume workflows; reserve privacy reassurance for upload, account, device-only photo, deletion, and policy contexts.
- Product interaction, performance, and crash diagnostics may be collected for analytics; no cross-company tracking or tracking domains. Native Firebase Analytics uses its automatic events only and must not receive pattern text, filenames, notes, account identifiers, or other user content as custom parameters.
- Account deletion must remove the account and user data and remain explicitly confirmed.
