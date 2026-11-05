import {logger} from "firebase-functions";
import {HttpsError} from "firebase-functions/v2/https";

const RESULTS = new Set([
  "accepted", "ignored", "stale", "staleContext", "dataMissing",
]);
const REASONS = new Set([
  "staleConnection", "staleContext", "upgradeRequired", "paused",
]);

/**
 * Observe readiness without logging identities or private/error payloads.
 * @param {unknown} data Request whose fixed state/role labels may be recorded.
 * @param {Function} action Callable execution to observe without changing it.
 * @return {Promise} Original result, or the original thrown error.
 */
export async function traceRecoveryReport(
  data: unknown,
  action: () => Promise<Record<string, unknown>>,
): Promise<Record<string, unknown>> {
  const input = data !== null && typeof data === "object" ?
    data as Record<string, unknown> : {};
  const started = performance.now();
  const labels = {
    reportState: input.state === "ready" || input.state === "failed" ?
      input.state : "other",
    role: input.role === "controller" || input.role === "player" ?
      input.role : "other",
  };
  const record = (fields: Record<string, unknown>): void => {
    try {
      logger.info("game_recovery_report_result", {
        ...labels, ...fields,
        durationMs: Math.round(performance.now() - started),
      });
    } catch {
      // Logging must not change an applied response or the original failure.
    }
  };
  try {
    const result = await action();
    record({
      outcome: "response",
      status: typeof result.status === "string" && RESULTS.has(result.status) ?
        result.status : "other",
      ...(typeof result.paused === "boolean" ? {paused: result.paused} : {}),
      ...(typeof result.reconnectRequested === "boolean" ?
        {reconnectRequested: result.reconnectRequested} : {}),
    });
    return result;
  } catch (error) {
    const details = error instanceof HttpsError ? error.details : undefined;
    const reason = details !== null && typeof details === "object" ?
      (details as Record<string, unknown>).reason : undefined;
    record({
      outcome: "error",
      errorCode: error instanceof HttpsError ? error.code : "internal",
      reason: typeof reason === "string" && REASONS.has(reason) ?
        reason : "other",
    });
    throw error;
  }
}
