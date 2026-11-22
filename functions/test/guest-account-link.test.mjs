import assert from "node:assert/strict";
import test from "node:test";

const {linkedProviderFromSignInProvider} = await import(
  "../lib/auth/mark-guest-account-linked.js"
);

test("게스트 연동은 Firebase 로그인 공급자를 온보딩 공급자로 변환한다", () => {
  assert.equal(linkedProviderFromSignInProvider("password"), "legacyPassword");
  assert.equal(linkedProviderFromSignInProvider("google.com"), "google");
  assert.equal(linkedProviderFromSignInProvider("apple.com"), "apple");
  assert.equal(linkedProviderFromSignInProvider("anonymous"), undefined);
});
