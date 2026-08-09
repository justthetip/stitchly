import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const icons = ["projects", "patterns", "account"] as const;

test("tab icon masters remain tintable outline vectors and match the iOS assets", async () => {
  for (const icon of icons) {
    const assetName = `Tab${icon[0].toUpperCase()}${icon.slice(1)}`;
    const master = await readFile(`public/icons/tab-${icon}.svg`, "utf8");
    const native = await readFile(
      `ios/Stitchly/Assets.xcassets/${assetName}.imageset/${assetName}.svg`,
      "utf8",
    );
    const metadata = JSON.parse(
      await readFile(
        `ios/Stitchly/Assets.xcassets/${assetName}.imageset/Contents.json`,
        "utf8",
      ),
    ) as { properties?: Record<string, unknown> };

    assert.equal(native, master, `${icon} native asset drifted from its SVG master`);
    assert.match(master, /viewBox="0 0 28 28"/);
    assert.match(master, /fill="none"/);
    assert.match(master, /stroke="#000"/);
    assert.match(master, /stroke-width="1\.8"/);
    assert.match(master, /stroke-linecap="round"/);
    assert.match(master, /stroke-linejoin="round"/);
    assert.equal(metadata.properties?.["preserves-vector-representation"], true);
    assert.equal(metadata.properties?.["template-rendering-intent"], "template");
  }
});
