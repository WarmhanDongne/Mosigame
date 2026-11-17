/* eslint-disable no-console, require-jsdoc */

import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {pathToFileURL} from "node:url";

import {russianRouletteCatalog} from "./russian-roulette-catalog.mjs";

export const RUSSIAN_ROULETTE_ID = "russian_roulette";
export const russianRouletteCatalogEntry = Object.freeze(
  russianRouletteCatalog[RUSSIAN_ROULETTE_ID],
);

/// Parses a deliberately explicit, single-document catalog registration command.
export function registerCommand(args) {
  let apply = false;
  let projectId;
  let confirmation;
  for (const argument of args) {
    if (argument === "--apply") {
      apply = true;
    } else if (argument.startsWith("--project=")) {
      projectId = argument.slice("--project=".length);
    } else if (argument.startsWith("--confirm-project=")) {
      confirmation = argument.slice("--confirm-project=".length);
    } else {
      throw new Error(`Unknown argument: ${argument}`);
    }
  }
  if (!projectId || projectId === "default") {
    throw new Error("An explicit Firebase project ID is required.");
  }
  if (apply && confirmation !== projectId) {
    throw new Error(`Apply requires --confirm-project=${projectId}.`);
  }
  return {apply, projectId};
}

/// Writes only `games/russian_roulette`; no other catalog document is listed,
/// deleted, or replaced by this operation.
export async function registerRussianRouletteCatalog({
  firestore,
  apply = false,
}) {
  const document = {
    id: RUSSIAN_ROULETTE_ID,
    ...russianRouletteCatalogEntry,
  };
  if (!apply) return {status: "dry-run", document};

  const reference = firestore.collection("games").doc(RUSSIAN_ROULETTE_ID);
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const timestamps = {updatedAt: FieldValue.serverTimestamp()};
    if (!snapshot.exists) {
      timestamps.createdAt = FieldValue.serverTimestamp();
    }
    transaction.set(
      reference,
      {...russianRouletteCatalogEntry, ...timestamps},
      {merge: true},
    );
  });
  return {status: "registered", document};
}

const isMain = process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMain) {
  try {
    const {apply, projectId} = registerCommand(process.argv.slice(2));
    if (!apply) {
      console.log(JSON.stringify(await registerRussianRouletteCatalog({
        firestore: null,
        apply: false,
      })));
    } else {
      const app = getApps()[0] ?? initializeApp({projectId});
      if (app.options.projectId !== projectId) {
        throw new Error("Wrong Firebase project.");
      }
      const result = await registerRussianRouletteCatalog({
        firestore: getFirestore(app),
        apply: true,
      });
      console.log(JSON.stringify({...result, projectId}));
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`Russian Roulette catalog registration failed: ${message}`);
    process.exitCode = 1;
  }
}
