import assert from "node:assert/strict";
import test from "node:test";

import {
  assertOperationsTestProject,
  localizedPushCopy,
  parseOperationsPushRequest,
} from "../lib/operations/push-alerts.js";

const localized = {
  ko: {title: "알림", body: "본문"},
  en: {title: "Alert", body: "Message"},
  "zh-Hans": {title: "通知", body: "正文"},
  "zh-Hant": {title: "通知", body: "內文"},
};

test("operations push accepts a bounded id and every supported locale", () => {
  assert.deepEqual(parseOperationsPushRequest({
    commandId: "push_20261118_abcdefghijkl",
    localized,
  }), {
    commandId: "push_20261118_abcdefghijkl",
    localized,
  });
  assert.throws(
    () => parseOperationsPushRequest({commandId: "short", localized}),
    {code: "invalid-argument"},
  );
});

test("operations push selects copy for the registered device locale", () => {
  assert.deepEqual(localizedPushCopy(localized, "english"), localized.en);
  assert.deepEqual(
    localizedPushCopy(localized, "simplifiedChinese"),
    localized["zh-Hans"],
  );
  assert.deepEqual(localizedPushCopy(localized, "unknown"), localized.ko);
});

test("operations push cannot run against the production Firebase project", () => {
  assert.doesNotThrow(() => assertOperationsTestProject("ban-pick-simulator"));
  assert.throws(
    () => assertOperationsTestProject("project0000-ec01e"),
    {code: "failed-precondition"},
  );
});
