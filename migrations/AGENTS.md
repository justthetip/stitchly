# Database migration instructions

- Neon Postgres is shared by the web and native clients; schema changes can affect both immediately after deployment.
- Create a new numerically ordered migration for every change. Never edit, renumber, or delete an existing migration that may have run remotely.
- Keep ownership explicit: user data tables and queries must remain scoped through `owner_id` or the established authenticated-user relationship.
- Prefer forward-compatible additions and staged constraints when existing production data may not satisfy a new invariant.
- Native auth tokens, Apple identities, and password credentials are security-sensitive. Store only the designed hashes/identifiers and never add secrets or raw tokens to migrations, fixtures, logs, or comments.
- Verify the migration against the linked Neon branch, then run web tests and any affected native contract tests.
- Record deployment evidence and affected API/client behavior in the relevant Linear issue.
