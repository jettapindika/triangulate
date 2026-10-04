#!/usr/bin/env bash
# Laporan status gate roadmap Triangulate (PRD §17).
#
# Deterministik: tanpa LLM, tanpa tafsir. Skrip ini melaporkan (a) minggu
# berjalan dihitung dari anchor, (b) target + gate minggu itu apa adanya dari
# docs/roadmap.json, dan (c) keadaan board EXTA-31. Verdict gate tetap milik
# owner — skrip tidak pernah menyatakan sebuah gate lulus.
#
# Pakai:  tools/roadmap-gate.sh [--date YYYY-MM-DD] [--parent EXTA-31]
# Keluar: 0 = laporan tercetak; 1 = tidak bisa jalan (anchor kosong, plan rusak)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAN="$ROOT/docs/roadmap.json"

TODAY="$(date -u +%Y-%m-%d)"
PARENT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --date) TODAY="${2:?--date butuh YYYY-MM-DD}"; shift 2 ;;
    --parent) PARENT="${2:?--parent butuh identifier issue}"; shift 2 ;;
    *) echo "argumen tidak dikenal: $1" >&2; exit 1 ;;
  esac
done

[ -f "$PLAN" ] || { echo "plan tidak ditemukan: $PLAN" >&2; exit 1; }

PARENT="${PARENT:-$(jq -r '.parent_issue // empty' "$PLAN")}"
START="$(jq -r '.start_date // empty' "$PLAN")"

if [ -z "$START" ]; then
  echo "anchor minggu 0 belum diisi: set .start_date di docs/roadmap.json" >&2
  echo "Pengingat gate roadmap tidak boleh berjalan tanpa anchor — minggu berjalan tidak bisa dihitung." >&2
  exit 1
fi

for d in "$START" "$TODAY"; do
  printf '%s' "$d" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' \
    || { echo "tanggal tidak valid (butuh YYYY-MM-DD): $d" >&2; exit 1; }
done

DAYS="$(jq -rn --arg a "$START" --arg b "$TODAY" \
  '($a+"T00:00:00Z"|fromdateiso8601) as $x
   | ($b+"T00:00:00Z"|fromdateiso8601) as $y
   | (($y-$x)/86400|floor)')"

if [ "$DAYS" -lt 0 ]; then
  echo "tanggal acuan ($TODAY) mendahului anchor ($START) — cek .start_date" >&2
  exit 1
fi

WEEK=$(( DAYS / 7 ))

echo "## Gate roadmap Triangulate — minggu $WEEK"
echo
echo "Anchor minggu 0: \`$START\` · hari ke-$DAYS · tanggal laporan \`$TODAY\`"
echo

if [ "$WEEK" -gt 8 ]; then
  echo "Roadmap 8 minggu sudah lewat. Gate minggu 8 tetap harus diverifikasi owner sebelum status apa pun ditulis."
else
  jq -r --argjson w "$WEEK" '
    .weeks[] | select(.week == $w) |
    "**Target minggu \(.week)** (PRD §17): \(.target)\n\n**Gate minggu \(.week)**: \(.gate)\n\n**Verdict gate**: _belum diisi — milik owner_\n"
  ' "$PLAN"
fi

if [ -n "$PARENT" ]; then
  echo "### Keadaan board ($PARENT)"
  echo
  CHILDREN="$(multica issue children "$PARENT" --output json)"

  echo "| Status | Jumlah |"
  echo "| --- | --- |"
  jq -r '
    [.stages[].issues[]] as $all |
    ($all | group_by(.status) | map({status: .[0].status, n: length}) | sort_by(.status))[] |
    "| \(.status) | \(.n) |"
  ' <<<"$CHILDREN"
  echo
  echo "Total sub-issue: $(jq -r '[.stages[].issues[]] | length' <<<"$CHILDREN")"
  echo
  echo "### Berubah dalam 7 hari terakhir"
  echo
  CUTOFF="$(jq -rn --arg t "$TODAY" '($t+"T00:00:00Z"|fromdateiso8601) - (7*86400) | todateiso8601')"
  jq -r --arg cutoff "$CUTOFF" '
    [.stages[].issues[] | select(.last_activity_at >= $cutoff)]
    | if length == 0 then "- tidak ada"
      else (sort_by(.last_activity_at) | reverse | .[] | "- \(.identifier) `\(.status)` — \(.title)") end
  ' <<<"$CHILDREN"
fi
