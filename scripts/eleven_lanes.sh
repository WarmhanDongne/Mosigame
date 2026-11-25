#!/usr/bin/env bash
# ELEVEN-01 S5 레인 A·B·C worktree를 만든다(노션 'ELEVEN S5–S7 작업 방식' 4절).
#
#   bash scripts/eleven_lanes.sh            # 현재 HEAD(S5-0 기준 커밋)에서 만든다
#   bash scripts/eleven_lanes.sh <커밋>      # 다른 기준 커밋에서 만든다
#
# - 위치: ~/Developer/projects/project00-lanes/lane-{a,b,c} (저장소 밖. 안에 두면 analyze·workspace가
#   중복 패키지를 읽는다)
# - 브랜치: eleven/lane-a-phone, eleven/lane-b-tablet, eleven/lane-c-integration
# - 이미 있는 worktree·브랜치는 건드리지 않는다(다시 실행해도 안전). 커밋·push하지 않는다.
# - 각 worktree에서 flutter pub get, 레인 C는 functions npm ci까지 한다.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lanes_dir="${ELEVEN_LANES_DIR:-$HOME/Developer/projects/project00-lanes}"
base="${1:-HEAD}"

cd "$repo"
base_commit="$(git rev-parse --verify "$base^{commit}")"
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo "주의: $repo 에 커밋하지 않은 tracked 변경이 있다. 레인에는 기준 커밋 내용만 들어간다." >&2
fi
echo "기준 커밋: $(git log -1 --format='%h %s' "$base_commit")"
mkdir -p "$lanes_dir"

lanes=(
  "lane-a eleven/lane-a-phone"
  "lane-b eleven/lane-b-tablet"
  "lane-c eleven/lane-c-integration"
)

for entry in "${lanes[@]}"; do
  read -r name branch <<<"$entry"
  dir="$lanes_dir/$name"
  if [[ -e "$dir" ]]; then
    echo "[$name] 이미 있음: $dir (건너뜀)"
  elif git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "[$name] 기존 브랜치 $branch 로 worktree 생성"
    git worktree add "$dir" "$branch"
  else
    echo "[$name] 새 브랜치 $branch ($(git rev-parse --short "$base_commit"))"
    git worktree add -b "$branch" "$dir" "$base_commit"
  fi
done

for entry in "${lanes[@]}"; do
  read -r name _ <<<"$entry"
  dir="$lanes_dir/$name"
  echo "[$name] flutter pub get"
  (cd "$dir" && flutter pub get >/dev/null)
  if [[ "$name" == "lane-c" && ! -d "$dir/functions/node_modules" ]]; then
    echo "[$name] npm ci (functions)"
    (cd "$dir/functions" && npm ci --no-audit --no-fund >/dev/null)
  fi
done

echo
git worktree list
cat <<MSG

다음:
  1. 각 폴더에서 Codex를 열고 한 줄 입력
     $lanes_dir/lane-a → docs/planning/eleven-lanes/LANE-A.md 읽고 진행
     $lanes_dir/lane-b → docs/planning/eleven-lanes/LANE-B.md 읽고 진행
     $lanes_dir/lane-c → docs/planning/eleven-lanes/LANE-C.md 읽고 진행
  2. 레인이 끝나면 Claude에게 "레인 A 검수"처럼 요청
MSG
