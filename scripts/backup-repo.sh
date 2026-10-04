#!/usr/bin/env bash
#
# backup-repo.sh — backup repo git Triangulate (mirror + bundle + verify + manifest + rotasi).
#
# Semua langkah sudah diuji pada 2026-10-04; lihat docs/ci/05-backup-restore.md.
#
# Alur:
#   1. git clone --mirror <sumber>            salinan lengkap semua ref
#   2. normalisasi refs/heads/main            worktree agen hanya punya refs/remotes/origin/main
#   3. git bundle create --all                artefak tunggal portabel
#   4. git bundle verify                      bukti bundle utuh
#   5. tulis manifest.env                     SHA main, jumlah file, ukuran, timestamp, sha256
#   6. rotasi                                 simpan KEEP_LAST backup terbaru
#
# Pakai:
#   ./scripts/backup-repo.sh
#   REPO_PATH=/path/ke/triangulate BACKUP_DIR=/path/backup KEEP_LAST=14 ./scripts/backup-repo.sh
#   MIRROR_URL=https://github.com/jettapindika/triangulate ./scripts/backup-repo.sh
#
set -euo pipefail

REPO_PATH="${REPO_PATH:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/triangulate-backups}"
MIRROR_URL="${MIRROR_URL:-}"
KEEP_LAST="${KEEP_LAST:-7}"

die() { printf 'GAGAL: %s\n' "$*" >&2; exit 1; }
log() { printf '[backup] %s\n' "$*"; }

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    printf 'TIDAK_TERSEDIA'
  fi
}

case "$KEEP_LAST" in
  ''|*[!0-9]*) die "KEEP_LAST harus angka >= 1 (dapat: $KEEP_LAST)" ;;
esac
[ "$KEEP_LAST" -ge 1 ] || die "KEEP_LAST harus >= 1 (dapat: $KEEP_LAST)"

if [ -n "$MIRROR_URL" ]; then
  SOURCE="$MIRROR_URL"
else
  SOURCE="$REPO_PATH"
  [ -d "$SOURCE" ] || die "REPO_PATH bukan direktori: $SOURCE"
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$BACKUP_DIR/$TS"
MIRROR_DIR="$RUN_DIR/triangulate.git"
BUNDLE="$RUN_DIR/triangulate.bundle"
MANIFEST="$RUN_DIR/manifest.env"

mkdir -p "$RUN_DIR"
log "sumber: $SOURCE"
log "tujuan: $RUN_DIR"

# 1. mirror
git clone --mirror "$SOURCE" "$MIRROR_DIR" >/dev/null 2>&1 || die "git clone --mirror gagal dari $SOURCE"
log "mirror dibuat"

# 2. normalisasi ref main
if git -C "$MIRROR_DIR" show-ref --verify --quiet refs/heads/main; then
  MAIN_REF="refs/heads/main"
elif git -C "$MIRROR_DIR" show-ref --verify --quiet refs/remotes/origin/main; then
  git -C "$MIRROR_DIR" update-ref refs/heads/main refs/remotes/origin/main
  MAIN_REF="refs/heads/main"
  log "refs/heads/main dibuat dari refs/remotes/origin/main"
else
  die "ref main tidak ada di mirror (refs/heads/main maupun refs/remotes/origin/main)"
fi

MAIN_SHA="$(git -C "$MIRROR_DIR" rev-parse "$MAIN_REF")"
MAIN_FILES="$(git -C "$MIRROR_DIR" ls-tree -r --name-only "$MAIN_REF" | wc -l | tr -d ' ')"
MIRROR_REFS="$(git -C "$MIRROR_DIR" for-each-ref --format='%(refname)' | wc -l | tr -d ' ')"
log "main $MAIN_SHA, $MAIN_FILES file, $MIRROR_REFS ref"

# 3. bundle
git -C "$MIRROR_DIR" bundle create "$BUNDLE" --all >/dev/null 2>&1 || die "git bundle create gagal"
log "bundle dibuat"

# 4. verify
git -C "$MIRROR_DIR" bundle verify "$BUNDLE" >"$RUN_DIR/bundle-verify.txt" 2>&1 \
  || die "git bundle verify gagal (lihat $RUN_DIR/bundle-verify.txt)"
log "bundle verify: OK"

# 5. manifest
BUNDLE_BYTES="$(wc -c <"$BUNDLE" | tr -d ' ')"
BUNDLE_SHA256="$(sha256_of "$BUNDLE")"
{
  printf 'BACKUP_TS=%s\n' "$TS"
  printf 'SOURCE=%s\n' "$SOURCE"
  printf 'MAIN_REF=%s\n' "$MAIN_REF"
  printf 'MAIN_SHA=%s\n' "$MAIN_SHA"
  printf 'MAIN_FILES=%s\n' "$MAIN_FILES"
  printf 'BUNDLE_BYTES=%s\n' "$BUNDLE_BYTES"
  printf 'BUNDLE_SHA256=%s\n' "$BUNDLE_SHA256"
  printf 'BUNDLE_PATH=%s\n' "$BUNDLE"
  printf 'MIRROR_REFS=%s\n' "$MIRROR_REFS"
  printf 'GIT_VERSION=%s\n' "$(git --version)"
} >"$MANIFEST"
log "manifest: $MANIFEST"

# 6. rotasi
printf '%s\n' "$BACKUP_DIR"/*/ | sort -r | tail -n +"$((KEEP_LAST + 1))" | while IFS= read -r OLD; do
  [ -n "$OLD" ] || continue
  [ -d "$OLD" ] || continue
  case "$OLD" in
    "$RUN_DIR"/*|"$RUN_DIR") continue ;;
  esac
  rm -rf "$OLD"
  log "rotasi: hapus $OLD"
done

log "LULUS — main=$MAIN_SHA file=$MAIN_FILES bundle=${BUNDLE_BYTES}B"
