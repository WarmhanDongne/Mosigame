/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {RecoveryRoom} from "./recovery-state.js";

// Longer than the app's 30-second preparation budget and normal seating/dealing.
export const STARTUP_RECOVERY_DELAY_MS = 90000;
export const STARTUP_RECOVERY_WINDOW_MS = 300000;
/** Compatibility no-op for the removed forced-disconnect watchdog. */
export function initializeStartupRecovery(room: RecoveryRoom, now: number): void {
  void now;
  if (room.game) delete room.game.server.startupRecovery;
}

export function hasStalledStartup(room: RecoveryRoom, now: number): boolean {
  void room;
  void now;
  return false;
}

/** Run inside the root transaction, scoped to the game observed by the scan. */
export function recoverStalledStartup(
  room: RecoveryRoom, expectedRoomInstanceId: string, expectedGameInstanceId: string, now: number,
): number {
  void room;
  void expectedRoomInstanceId;
  void expectedGameInstanceId;
  void now;
  return 0;
}
