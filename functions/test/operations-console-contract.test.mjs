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

test("game push status is read only for the operations admin", () => {
  const page = readFileSync("../public/operations/index.html", "utf8");
  const rules = readFileSync("../firestore.rules", "utf8");
  const collector = readFileSync("src/notifications/push-delivery-status.ts", "utf8");

  assert.match(page, /onSnapshot\(doc\(db,'pushDeliveryStatus','current'\)/);
  assert.match(page, /FCM API의 수락·거절과 요청 자체의 실패/);
  assert.doesNotMatch(page, /httpsCallable\(functions,\s*['"]send(?:Game)?Push/);
  assert.match(collector, /collection\("pushDeliveryStatus"\)\.doc\("current"\)/);
  assert.match(rules, /match \/pushDeliveryStatus\/\{documentId\} \{[\s\S]*?operationsAdmin == true;[\s\S]*?allow list, write: if false;/);
});
