/* eslint-disable no-console */

import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {pathToFileURL} from "node:url";

export const TEST_PROJECT_ID = "ban-pick-simulator";
const UID_PATTERN = /^[A-Za-z0-9_-]{20,128}$/;

/** Grants only the operations-console claim without discarding other claims. */
export async function grantOperationsAdmin(auth, uid) {
  if (!UID_PATTERN.test(uid)) throw new Error("Invalid Firebase Auth UID.");
  const user = await auth.getUser(uid);
  await auth.setCustomUserClaims(uid, {
    ...(user.customClaims ?? {}),
    operationsAdmin: true,
  });
  return {uid, operationsAdmin: true};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  const uidArg = args.find((arg) => arg.startsWith("--uid="));
  const confirmation = `--confirm-project=${TEST_PROJECT_ID}`;
  try {
    if (!uidArg || !args.includes("--apply") || !args.includes(confirmation) ||
        args.some((arg) => arg !== "--apply" && arg !== confirmation && arg !== uidArg)) {
      throw new Error(
        `Usage: --apply ${confirmation} --uid=<Firebase Auth UID>`,
      );
    }
    const app = getApps()[0] ?? initializeApp({projectId: TEST_PROJECT_ID});
    if (app.options.projectId !== TEST_PROJECT_ID) {
      throw new Error("This script only permits the test Firebase project.");
    }
    const result = await grantOperationsAdmin(getAuth(app), uidArg.slice(6));
    console.log(JSON.stringify(result));
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`Operations admin grant failed: ${message}`);
    process.exitCode = 1;
  }
}
