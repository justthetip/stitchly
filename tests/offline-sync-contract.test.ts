import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

test("offline note retries use an owner and project scoped idempotency key", () => {
  const route = readFileSync("src/app/api/projects/[id]/notes/route.ts", "utf8");
  const migration = readFileSync("migrations/008_offline_note_idempotency.sql", "utf8");

  assert.match(route, /clientMutationId/);
  assert.match(route, /on conflict \(owner_id, project_id, client_mutation_id\)/);
  assert.match(migration, /add column if not exists client_mutation_id uuid/);
  assert.match(migration, /unique index[\s\S]*owner_id, project_id, client_mutation_id/);
});
