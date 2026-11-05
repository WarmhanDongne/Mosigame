/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {currentPresence} from "../room/current-presence.js";
import {
  hasIndependentPlayerRecovery, PreparationReconnectTarget, RecoveryRoom,
  registerRecoveryFailure, requestPreparationReconnect, requiredRecoveryKeys,
} from "./recovery-state.js";

// Longer than the app's 30-second preparation budget and normal seating/dealing.
export const STARTUP_RECOVERY_DELAY_MS = 90000;
export const STARTUP_RECOVERY_WINDOW_MS = 300000;
const RECENT_HEARTBEAT_MS = 20000;

function supported(room: RecoveryRoom): boolean {
  return hasIndependentPlayerRecovery(room) &&
    ["liars_poker", "final_call"].includes(String(room.game?.public.gameType));
}

/** Opt in only at new-game creation; never infer eligibility for old games. */
export function initializeStartupRecovery(room: RecoveryRoom, now: number): void {
  const game = room.game;
  if (!game) return;
  delete game.server.startupRecovery;
  if (!supported(room) || !game.public.gameInstanceId) return;
  const waiting: Record<string, PreparationReconnectTarget> = {};
  for (const key of requiredRecoveryKeys(room)) {
    const split = key.indexOf(":");
    const role = key.slice(0, split) as "player" | "controller";
    const uid = key.slice(split + 1);
    const connection = currentPresence(room, uid, role);
    if (!connection?.connected) continue;
    const controller = role === "controller";
    waiting[key] = {
      uid, role, connectionId: controller ? room.controllerCurrentConnectionId! : room.players![uid].currentConnectionId!,
      connectionSeq: connection.connectionSeq,
      ...(controller ? {} : {membershipId: room.players![uid].membershipId!}),
    };
  }
  if (Object.keys(waiting).length) {
    game.server.startupRecovery = {
      version: 1, gameInstanceId: game.public.gameInstanceId, startedAt: now, waiting,
    };
  }
}

/** Missing ready alone is insufficient: require the same live connection. */
function startupTargets(room: RecoveryRoom, now: number): PreparationReconnectTarget[] {
  const game = room.game;
  const startup = game?.server.startupRecovery;
  if (room.status !== "playing" || game?.public.status !== "playing" || !supported(room) ||
      !startup || startup.version !== 1 || startup.gameInstanceId !== game.public.gameInstanceId ||
      !Number.isFinite(now) || !Number.isFinite(startup.startedAt) ||
      now - startup.startedAt < STARTUP_RECOVERY_DELAY_MS || now - startup.startedAt > STARTUP_RECOVERY_WINDOW_MS) return [];
  const required = new Set(requiredRecoveryKeys(room));
  return Object.entries(startup.waiting ?? {}).flatMap(([key, target]) => {
    if (!target || !["player", "controller"].includes(target.role) ||
        key !== `${target.role}:${target.uid}` || !required.has(key)) return [];
    const previous = game.server.preparationReconnects?.[key];
    if (previous && (target.role === "controller" || previous.membershipId === target.membershipId)) return [];
    const connection = currentPresence(room, target.uid, target.role);
    const id = target.role === "controller" ? room.controllerCurrentConnectionId : room.players?.[target.uid]?.currentConnectionId;
    if (!connection?.connected || id !== target.connectionId || connection.connectionSeq !== target.connectionSeq ||
        (target.role === "player" && connection.membershipId !== target.membershipId) ||
        connection.lastSeen > now || now - connection.lastSeen > RECENT_HEARTBEAT_MS) return [];
    return [target];
  });
}

export function hasStalledStartup(room: RecoveryRoom, now: number): boolean {
  return startupTargets(room, now).length > 0;
}

/** Run inside the root transaction, scoped to the game observed by the scan. */
export function recoverStalledStartup(
  room: RecoveryRoom, expectedRoomInstanceId: string, expectedGameInstanceId: string, now: number,
): number {
  if (room.roomInstanceId !== expectedRoomInstanceId || room.game?.public.gameInstanceId !== expectedGameInstanceId) return 0;
  let reconnected = 0;
  for (const target of startupTargets(room, now)) {
    if (!requestPreparationReconnect(room, target)) continue;
    registerRecoveryFailure(room, target.uid, target.role, now, "preparationFailed");
    delete room.game!.server.startupRecovery!.waiting[`${target.role}:${target.uid}`];
    reconnected++;
  }
  if (reconnected && Object.keys(room.game!.server.startupRecovery!.waiting).length === 0) delete room.game!.server.startupRecovery;
  return reconnected;
}
