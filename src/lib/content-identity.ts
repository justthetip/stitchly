export function contentIdentity(userId: string | null | undefined) {
  return userId ?? "guest";
}

export function contentMatchesSession(
  loadedIdentity: string | null,
  userId: string | null | undefined,
  sessionPending: boolean,
) {
  return !sessionPending && loadedIdentity === contentIdentity(userId);
}
