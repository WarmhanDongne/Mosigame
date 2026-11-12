import assert from "node:assert/strict";
import test from "node:test";

import {
  parsePlatformAnnouncementUpdate,
} from "../lib/operations/announcements.js";

const localized = {
  ko: {title: "공지", body: "본문"},
  en: {title: "Notice", body: "Body"},
  "zh-Hans": {title: "公告", body: "正文"},
  "zh-Hant": {title: "公告", body: "內文"},
};

test("announcement update requires all app locales", () => {
  assert.throws(
    () => parsePlatformAnnouncementUpdate({
      kind: "notice",
      active: true,
      localized: {ko: localized.ko},
    }),
    {code: "invalid-argument"},
  );
});

test("active maintenance requires an explicit window", () => {
  assert.throws(
    () => parsePlatformAnnouncementUpdate({
      kind: "maintenance",
      active: true,
      localized,
    }),
    {code: "invalid-argument"},
  );
  assert.deepEqual(
    parsePlatformAnnouncementUpdate({
      kind: "maintenance",
      active: true,
      localized,
      maintenancePeriod: "11/12 02:00–03:00 KST",
    }).maintenancePeriod,
    "11/12 02:00–03:00 KST",
  );
});
