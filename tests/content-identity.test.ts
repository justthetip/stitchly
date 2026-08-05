import test from "node:test";
import assert from "node:assert/strict";
import {
  contentIdentity,
  contentMatchesSession,
} from "../src/lib/content-identity.ts";

test("guest demo content is invalidated as soon as a user authenticates", () => {
  assert.equal(contentIdentity(undefined), "guest");
  assert.equal(contentMatchesSession("guest", undefined, false), true);
  assert.equal(contentMatchesSession("guest", "maker-1", false), false);
  assert.equal(contentMatchesSession("maker-1", "maker-1", false), true);
});

test("content stays hidden while the session is restoring or belongs to another account", () => {
  assert.equal(contentMatchesSession("guest", undefined, true), false);
  assert.equal(contentMatchesSession("maker-1", "maker-2", false), false);
  assert.equal(contentMatchesSession("maker-2", "maker-2", false), true);
});
