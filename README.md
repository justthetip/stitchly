# Stitchly

Stitchly is a mobile-first knitting and crochet companion for turning PDF patterns into clear, trackable guides.

The current build validates the core journey:

1. Add a private PDF pattern.
2. Review the extracted sections, rounds, rows, setup and finishing steps.
3. Start a project with materials and notes.
4. Follow one focused instruction at a time, using the pattern author's labels.
5. Save progress and resume exactly where you stopped.

## Product foundations

- Organisation first: patterns are easy to find and browse.
- Progress without effort: reader position and instruction notes persist automatically.
- Made for active crafting: large targets, focused instructions and a mobile-first layout.
- Warm, original visual identity inspired by handmade yarn craft rather than generic utility software.

## Stack

- Next.js 16 App Router, React 19 and Tailwind CSS 4
- Neon Postgres and Neon Auth (Google plus email/password)
- Private Vercel Blob storage for uploaded pattern files
- Server-side PDF text extraction with `unpdf` and deterministic, section-first parsing
- Vercel deployment from the `main` branch

Every data route resolves the authenticated Neon user and scopes reads and
writes by `owner_id`. Original PDFs remain private and are streamed through an
authenticated route rather than exposed as public Blob URLs.

## Local development

```bash
npm install
npm run dev
```

Environment variables are managed through the linked Vercel and Neon projects. Pull development values with:

```bash
vercel env pull
```

Never commit `.env.local`, `.neon`, or uploaded user files.

## Verification

```bash
npm test
npm run lint
npm run build
```

The parser regression suite uses real sample PDFs supplied from the local
Downloads folder when they are available. Database migrations live in
[`migrations`](./migrations). Product context and extraction ground truth live
in [`project-docs`](./project-docs).
