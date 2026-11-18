/* eslint-disable no-console */

import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {pathToFileURL} from "node:url";

export const TEST_PROJECT_ID = "ban-pick-simulator";
export const PRODUCTION_PROJECT_ID = "project0000-ec01e";
const UID_PATTERN = /^[A-Za-z0-9_-]{20,128}$/;

export function supportedOperationsProject(projectId) {
  return projectId === TEST_PROJECT_ID || projectId === PRODUCTION_PROJECT_ID;
}

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
  const projectArg = args.find((arg) => arg.startsWith("--project="));
  const projectId = projectArg?.slice("--project=".length);
  const confirmation = projectId ? `--confirm-project=${projectId}` : "";
  try {
    if (!projectId || !supportedOperationsProject(projectId) || !uidArg ||
        !args.includes("--apply") || !args.includes(confirmation) ||
        args.some((arg) => arg !== "--apply" && arg !== confirmation &&
            arg !== uidArg && arg !== projectArg)) {
      throw new Error(
        "Usage: --apply --project=<approved-project> " +
          "--confirm-project=<same-project> --uid=<Firebase Auth UID>",
      );
    }
    const app = getApps()[0] ?? initializeApp({projectId});
    if (app.options.projectId !== projectId) {
      throw new Error("Firebase app project does not match the confirmed project.");
    }
    const result = await grantOperationsAdmin(getAuth(app), uidArg.slice(6));
    console.log(JSON.stringify(result));
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`Operations admin grant failed: ${message}`);
    process.exitCode = 1;
  }
}
