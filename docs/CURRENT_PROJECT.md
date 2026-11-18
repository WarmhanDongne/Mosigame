# Mosigame 현재 프로젝트 기준

확인 기준: 2026-11-18, 문서 정리 전 `develop` 기준 `cb13e579`. 이 문서는 코드에 등록된
기능과 사용자가 확정한 공개 계획을 구분합니다. 운영 Firebase의 실제 배포·활성 상태를
조회했다는 뜻은 아닙니다.

## 제품과 버전

| 항목 | 현재 기준 |
| --- | --- |
| 앱 버전 | `1.0.1+9` (`pubspec.yaml`) |
| Flutter CI | `3.47.5` |
| Node.js | major 22 |
| Java CI | 17 |
| 운영 앱 | Android·iOS Flutter 앱 하나 |
| 게임 서버 | Firebase Functions, 서버 권위형 |

## 게임 상태

`GameRegistry` 등록은 코드가 앱에 포함됐다는 뜻이고, 사용자 공개는 Firestore 카탈로그,
TEST 실기기 검증과 스토어 배포까지 끝나야 합니다.

| gameId | 패키지 | 제품 계획 |
| --- | --- | --- |
| `liars_poker` | `game_liars_poker` | 공개 예정 |
| `final_call` | `game_final_call` | 공개 예정 |
| `yut` | `game_yut` | 공개 예정 |
| `strategy_yut` | `game_yut` | 공개 예정 |
| `russian_roulette` | `game_russian_roulette` | 공개 예정 |
| `mafia` | `game_mafia` | 보류 |
| `holdem` | `game_holdem` | 보류 |
| `strategy_yut_edition` | `game_yut` | 보류 |

보류 게임도 registry·Functions·테스트에 존재할 수 있습니다. 보류는 코드를 삭제한다는 뜻이
아니며 운영 `enabled`를 임의로 바꾸면 안 됩니다.

## workspace 패키지

현재 workspace는 8개입니다.

```text
game_kit
game_template
game_liars_poker
game_final_call
game_mafia
game_holdem
game_yut
game_russian_roulette
```

`game_template`은 복사용이며 앱 dependency가 아닙니다. 나머지 게임 패키지는 앱 바이너리에
코드와 에셋을 함께 넣습니다. 모든 현재 게임의 `requiredAssetVersion`은 0이며 런타임 게임
다운로드는 활성 정책이 아닙니다.

## 앱 registry

`lib/games/game_registry.dart`는 6개 구현 패키지에서 8개 catalog ID를 등록합니다.

```text
LiarsPokerGame
FinalCallGame
MafiaGame
HoldemGame
YutGame
StrategyYutGame
StrategyYutEditionGame
RussianRouletteGame
```

## Cloud Functions

정확한 현재 export source of truth는 `functions/src/index.ts`입니다.

- 현재 HEAD export: 93개
- 실제 운영 배포 개수와 revision: 별도 승인된 metadata 조회 없이는 미확정

문서에 적힌 과거 67·69·79·81개 수치를 현재 배포 수로 사용하지 않습니다.

## Firebase 환경

| 모드 | 용도 | 선택 방법 |
| --- | --- | --- |
| `server` | 운영 Firebase | 기본값. 개발 검증에서는 생략 사용 금지 |
| `test` | TEST Firebase 실기기·통합 검증 | `--dart-define=MOSIGAME_BACKEND=test` |
| `local` | 로컬 Emulator Suite | `--dart-define=MOSIGAME_BACKEND=local` |

Firebase CLI 기본 프로젝트는 TEST이고 운영은 `mosigame-production`을 명시해야 합니다.
운영 접근·배포·migration·카탈로그 활성화는 각각 사용자 승인이 필요합니다.

## 브랜치 흐름

```text
<개발자>_<기능> → hajun 또는 jinsung → TEST 검증 → develop → 스토어 배포 → main
```

- `main`: 실제 스토어 배포 완료
- `develop`: 다음 스토어 등록 대기
- `TEST`: TEST Firebase·실기기 검증
- `hajun`, `jinsung`: 개발자별 통합

상세 규칙과 커밋 형식은 루트 `AGENTS.md`가 소유합니다.
