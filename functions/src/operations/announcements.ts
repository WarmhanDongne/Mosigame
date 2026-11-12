/* eslint-disable require-jsdoc, valid-jsdoc */
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const REGION = "asia-northeast3";
const COLLECTION = "platformAnnouncements";
const KINDS = new Set(["notice", "maintenance"]);
const LOCALES = ["ko", "en", "zh-Hans", "zh-Hant"] as const;

type AnnouncementKind = "notice" | "maintenance";
type LocalizedCopy = Record<(typeof LOCALES)[number], {
  title: string;
  body: string;
}>;

type UpsertPlatformAnnouncementData = {
  kind?: unknown;
  active?: unknown;
  localized?: unknown;
  maintenancePeriod?: unknown;
};

/** Rejects callers without the explicitly granted operations claim. */
function requireOperationsAdmin(
  request: {auth?: {token?: Record<string, unknown>}},
): void {
  if (request.auth?.token?.operationsAdmin !== true) {
    throw new HttpsError("permission-denied", "운영자 권한이 필요합니다.");
  }
}

/** Validates a non-empty bounded text field sent by the operations console. */
function parseText(value: unknown, label: string, maxLength: number): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${label}을 입력해주세요.`);
  }
  const text = value.trim();
  if (!text || text.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${label}은 1~${maxLength}자로 입력해주세요.`,
    );
  }
  return text;
}

/** Validates the complete four-language copy bundle. */
function parseLocalizedCopy(value: unknown): LocalizedCopy {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "언어별 공지 내용을 입력해주세요.");
  }
  const source = value as Record<string, unknown>;
  return Object.fromEntries(LOCALES.map((locale) => {
    const copy = source[locale];
    if (!copy || typeof copy !== "object" || Array.isArray(copy)) {
      throw new HttpsError("invalid-argument", `${locale} 공지 내용을 입력해주세요.`);
    }
    const fields = copy as Record<string, unknown>;
    return [locale, {
      title: parseText(fields.title, `${locale} 제목`, 80),
      body: parseText(fields.body, `${locale} 본문`, 500),
    }];
  })) as LocalizedCopy;
}

/** Parses one of the two supported announcement document IDs. */
function parseKind(value: unknown): AnnouncementKind {
  if (typeof value !== "string" || !KINDS.has(value)) {
    throw new HttpsError("invalid-argument", "올바른 공지 종류가 아닙니다.");
  }
  return value as AnnouncementKind;
}

/** Parses and validates an update before it reaches a Firestore document. */
export function parsePlatformAnnouncementUpdate(
  data: UpsertPlatformAnnouncementData | undefined,
): {
  kind: AnnouncementKind;
  active: boolean;
  localized: LocalizedCopy;
  maintenancePeriod: string | null;
} {
  const kind = parseKind(data?.kind);
  if (typeof data?.active !== "boolean") {
    throw new HttpsError("invalid-argument", "공지 표시 여부를 선택해주세요.");
  }
  const localized = parseLocalizedCopy(data?.localized);
  const maintenancePeriod = kind === "maintenance" &&
      data.maintenancePeriod !== undefined ?
    parseText(data.maintenancePeriod, "점검 시간", 120) : null;
  if (kind === "maintenance" && data.active && !maintenancePeriod) {
    throw new HttpsError("invalid-argument", "점검 시간을 입력해주세요.");
  }
  return {kind, active: data.active, localized, maintenancePeriod};
}

/** Updates one of the two user-visible platform announcements. */
export const updatePlatformAnnouncement = onCall<
  UpsertPlatformAnnouncementData
>(
  {region: REGION},
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    requireOperationsAdmin(request);
    const {kind, active, localized, maintenancePeriod} =
      parsePlatformAnnouncementUpdate(request.data);
    await getFirestore().collection(COLLECTION).doc(kind).set({
      kind,
      active,
      localized,
      maintenancePeriod,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: request.auth.uid,
    }, {merge: true});
    return {kind, active};
  },
);

/** New room creation and entry are unavailable while maintenance is active. */
export async function assertPlatformMaintenanceInactive(): Promise<void> {
  const snapshot = await getFirestore().collection(COLLECTION)
    .doc("maintenance").get();
  if (snapshot.data()?.active === true) {
    throw new HttpsError("unavailable", "현재 서버 점검 중입니다. 잠시 후 다시 시도해주세요.");
  }
}
