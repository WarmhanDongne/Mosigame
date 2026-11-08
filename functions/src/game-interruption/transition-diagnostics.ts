/* eslint-disable require-jsdoc */
import {logger} from "firebase-functions";

const PHASES = new Set([
  "dealing", "playing", "lastCardChallenge", "penalty", "finished",
]);
const RESULTS = new Set([
  "dealingCompleted", "dealingAlreadyCompleted", "gameEnded",
]);

function object(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" ?
    value as Record<string, unknown> : {};
}

/**
 * Observe the returned transaction snapshot without another read or mutation.
 * @param {string} action Fixed callable action label.
 * @param {unknown} request Used only for a current-game equality check.
 * @param {unknown} response Used only for a whitelisted result label.
 * @param {Function} snapshot Decode the already-returned transaction snapshot.
 */
export function recordLiarsPokerTransition(
  action: "completeDealing" | "endGame",
  request: unknown,
  response: unknown,
  snapshot: () => unknown,
): void {
  // Diagnostic failures, including decoding, cannot fail a committed call.
  try {
    const room = object(snapshot());
    const game = object(room.game);
    const pub = object(game.public);
    const server = object(game.server);
    const privatePlayers = Object.values(object(game.private));
    const contextKeys = ["gameInstanceId", "phaseSeq", "turnSeq", "dataSeq"];
    const validContext = typeof pub.gameInstanceId === "string" &&
      pub.gameInstanceId.length > 0 &&
      contextKeys.slice(1).every((key) =>
        Number.isSafeInteger(pub[key]) && (pub[key] as number) > 0);
    const matchingPrivatePlayers = privatePlayers.filter((entry) => {
      const context = object(object(entry)._context);
      return validContext && contextKeys.every((key) =>
        context[key] === pub[key]);
    }).length;
    const type = object(response).type;
    logger.info("liars_poker_transition_result", {
      action,
      responseType: typeof type === "string" && RESULTS.has(type) ?
        type : "other",
      // A replay may return an earlier success while a different game is live.
      requestGameCurrent: validContext &&
        object(request).gameInstanceId === pub.gameInstanceId,
      status: pub.status === "playing" || pub.status === "finished" ?
        pub.status : "other",
      phase: typeof pub.phase === "string" && PHASES.has(pub.phase) ?
        pub.phase : "other",
      paused: object(pub.recovery).paused === true,
      contextValid: validContext,
      privatePlayers: privatePlayers.length,
      matchingPrivatePlayers,
      pendingHands: Object.keys(object(server.pendingHands)).length > 0,
    });
  } catch {
    // No raw request, response, identity, cards or error text in logs.
  }
}
