import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

test("test operations console is isolated from the production Firebase project", () => {
  const config = JSON.parse(readFileSync("../firebase.test.json", "utf8"));
  const page = readFileSync("../public/operations/index.html", "utf8");

  assert.equal(config.hosting.site, "mosigame-operations-test");
  assert.equal(config.hosting.public, "public");
  assert.match(page, /projectId:'ban-pick-simulator'/);
  assert.doesNotMatch(page, /project0000-ec01e/);
  assert.match(page, /updatePlatformAnnouncement/);
  assert.match(page, /operationsAdmin/);
});
