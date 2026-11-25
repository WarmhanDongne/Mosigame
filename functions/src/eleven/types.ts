/* eslint-disable max-len */
import {RecoveryPublic} from "../game-interruption/recovery-state.js";
import {ElevenColor, ElevenDrawPurpose, ElevenJudgeReason} from "./rules.js";

export type ElevenPhase = "drawPick" | "drawReveal" | "firstSubmit" | "secondSubmit" | "roundResult" | "finished";

export interface ElevenPlayer {
  uid: string;
  nickname: string;
  characterId: string;
  seatIndex: number;
  status: "alive" | "eliminated";
}

export interface ElevenHistoryEntry {
  round: number;
  firstUid: string;
  colors: Record<string, ElevenColor>;
  winnerUid: string | null;
  autoSubmitted?: Record<string, true>;
}

export interface ElevenGameState {
  public: {
    gameType: "eleven";
    status: "playing" | "finished";
    phase: ElevenPhase;
    revision: number;
    round: number;
    players: Record<string, ElevenPlayer>;
    scores: Record<string, number>;
    firstUid: string | null;
    secondUid: string | null;
    turnUid: string | null;
    turnDeadlineAt: number | null;
    currentRound: {round: number; firstColor?: ElevenColor; secondColor?: ElevenColor; autoSubmitted: Record<string, true>};
    draw?: {purpose: ElevenDrawPurpose; order: [string, string]; picks: Record<string, number>; nextPickerUid: string | null; revealed?: Record<string, number>; winnerUid?: string};
    winnerUid: string | null;
    finishReason?: "winner" | "manual" | "insufficientPlayers";
    finishDetail?: "earlyEnd" | "allRounds" | "tieDraw";
    earlyEnd?: {remainingRounds: number; leaderUid: string; gap: number};
    /** 직전 라운드 결과. winnerUid가 없거나 null이면 동점입니다. 숫자·합·판정 유형은 넣지 않습니다. */
    lastRoundResult?: {round: number; winnerUid: string | null};
    startedAt: number;
    updatedAt: number;
    finishedAt?: number;
    gameInstanceId?: string;
    phaseSeq?: number;
    turnSeq?: number;
    dataSeq?: number;
    resumeEpoch?: number;
    recovery?: RecoveryPublic;
  };
  controller: {history: ElevenHistoryEntry[]};
  private: Record<string, {tiles: number[]; submission?: {round: number; value: number; auto: boolean}; _context?: Record<string, unknown>}>;
  server: {
    draw?: {purpose: ElevenDrawPurpose; slots: number[]};
    submissions: Record<string, number>;
    nextFirstUid?: string;
    lastJudgeReason?: ElevenJudgeReason;
    [key: string]: unknown;
  };
}

export interface ElevenRoom {
  controllerUid?: string;
  controllerSessionId?: string;
  hostUid?: string;
  status?: string;
  selectedGame?: string;
  players?: Record<string, Record<string, unknown>>;
  game?: ElevenGameState;
}
