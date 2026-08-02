export default function PrivacyPage() {
  return <main className="mx-auto min-h-screen max-w-2xl px-6 py-16 text-slate-900">
    <h1 className="text-4xl font-bold">Stitchly privacy policy</h1>
    <p className="mt-3 text-sm text-slate-500">Effective 2 August 2026</p>
    <div className="mt-10 space-y-6 leading-7">
      <p>Stitchly stores the account details you provide through your sign-in provider, the pattern PDFs you upload, extracted pattern instructions, project progress, yarn details, and notes. We use this information only to provide and improve Stitchly.</p>
      <p>Your pattern files are stored privately and are only made available to your authenticated account. We do not sell personal information or use your pattern content for advertising.</p>
      <p>Stitchly uses Apple and Neon for authentication, Neon Postgres for app data, and Vercel for hosting and private file storage. These providers process data only as needed to operate the service.</p>
      <p>You can permanently delete your account and associated Stitchly data from Account in the iOS app. You may also contact <a className="underline" href="mailto:support@stitchly.app">support@stitchly.app</a> for privacy or deletion requests.</p>
    </div>
  </main>;
}
