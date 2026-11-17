/* eslint-disable max-len */
import {PublicGameInterruption, ServerGameInterruption} from "../game-interruption/types.js";

export type RussianRouletteAction = "spin" | "shield" | "none";
export type RussianRoulettePhase = "selecting" | "revealing" | "rotating" | "firing" | "outcome" | "finished";

export interface RussianRoulettePlayer {
  uid: string;
  nickname: string;
  characterId: string;
  seatIndex: number;
  status: "alive" | "eliminated";
  shieldLocked: boolean;
  eliminatedTurn?: number;
  rank?: number;
}
export interface RussianRoulettePublicState {
  gameType: "russian_roulette";
  status: "playing" | "finished";
  phase: RussianRoulettePhase;
  round: number;
  revision: number;
  targetUid: string | null;
  turnDeadlineAt: number | null;
  choiceCount: number;
  revealedActions: Record<string, RussianRouletteAction>;
  spinCount: number;
  shotBlocked: boolean | null;
  eliminatedUid: string | null;
  players: Record<string, RussianRoulettePlayer>;
  winnerUid: string | null;
  finishReason?: "winner" | "manual" | "insufficientPlayers";
  interruption?: PublicGameInterruption;
  startedAt: number;
  updatedAt: number;
  finishedAt?: number;
  gameInstanceId?: string;
  phaseSeq?: number;
  turnSeq?: number;
  dataSeq?: number;
  resumeEpoch?: number;
  recovery?: Record<string, unknown>;
}

export interface RussianRoulettePrivatePlayer {
  choiceSubmitted: boolean;
  action?: RussianRouletteAction;
  _context?: Record<string, unknown>;
}

export interface RussianRouletteGameState {
  public: RussianRoulettePublicState;
  private: Record<string, RussianRoulettePrivatePlayer>;
  server: {
    interruption?: ServerGameInterruption;
    [key: string]: unknown;
  };
}

export interface RussianRouletteRoom {
  controllerUid?: string;
  controllerSessionId?: string;
  hostUid?: string;
  status?: string;
  selectedGame?: string;
  players?: Record<string, Record<string, unknown>>;
  game?: RussianRouletteGameState;
}
