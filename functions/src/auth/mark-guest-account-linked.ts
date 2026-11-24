import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {
  OnboardingProvider,
  parseOnboardingStatus,
} from "./onboarding-types.js";

const REGION = "asia-northeast3";
const OPTIONS = {region: REGION};

/**
 * Firebase Auth의 sign_in_provider 값을 온보딩 provider 이름으로 바꿉니다.
 * @param {unknown} value 토큰의 firebase.sign_in_provider 값
 * @return {OnboardingProvider | undefined} 연결 가능한 provider 또는 undefined
 */
export function linkedProviderFromSignInProvider(
  value: unknown,
): OnboardingProvider | undefined {
  return value === "google.com" ? "google" :
    value === "apple.com" ? "apple" :
      value === "password" ? "legacyPassword" : undefined;
}

/**
 * Firebase Auth에서 익명 계정에 새 인증 수단이 연결된 뒤 온보딩 메타데이터를
 * 같은 UID로 갱신합니다. 프로필·구매·방 기록은 UID가 유지되므로 이동하지 않습니다.
 */
export const markGuestAccountLinked = onCall(OPTIONS, async (request) => {
  const auth = request.auth;
  if (!auth) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  const provider = linkedProviderFromSignInProvider(
    auth.token.firebase?.sign_in_provider,
  );
  if (!provider) {
    throw new HttpsError(
      "failed-precondition",
      "연결된 이메일·Google·Apple 인증 정보를 확인하지 못했습니다.",
    );
  }

  const db = getFirestore();
  const onboardingRef = db.collection("userOnboarding").doc(auth.uid);
  const userRef = db.collection("users").doc(auth.uid);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(onboardingRef);
    const data = snapshot.data();
    const status = parseOnboardingStatus(data?.status);
    if (!snapshot.exists || status !== "complete") {
      throw new HttpsError(
        "failed-precondition",
        "완료된 게스트 계정만 로그인 방식을 연결할 수 있습니다.",
      );
    }
    const previousProvider = data?.provider;
    if (previousProvider !== "anonymous" && previousProvider !== provider) {
      throw new HttpsError(
        "failed-precondition",
        "이미 다른 로그인 방식으로 연결된 계정입니다.",
      );
    }
    transaction.set(onboardingRef, {
      provider,
      linkedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    if (typeof auth.token.email === "string" && auth.token.email.length > 0) {
      transaction.set(userRef, {
        email: auth.token.email,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  });
  return {success: true, provider};
});
