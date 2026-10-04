#!/usr/bin/env bash
#
# restore-drill.sh — uji restore backup repo git Triangulate dari bundle.
#
# Kriteria lulus (semuanya wajib):
#   1. SHA-256 file bundle cocok dengan manifest (menangkap file yang diubah/ditambah isinya)
#   2. git bundle verify sukses
#   3. SHA commit main hasil restore identik dengan manifest
#   4. jumlah file (git ls-tree -r --name-only main | wc -l) identik dengan manifest
#
# Cetak LULUS atau GAGAL; exit non-zero saat GAGAL.
# Diuji pada 2026-10-04; lihat docs/ci/05-backup-restore.md.
#
# Pakai:
#   ./scripts/restore-drill.sh
#   BACKUP_DIR=/path/backup ./scripts/restore-drill.sh
#   MANIFEST=/path/backup/<ts>/manifest.env ./scripts/restore-drill.sh
#
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-$HOME/triangulate-backups}"
MANIFEST="${MANIFEST:-}"
RESTORE_ROOT="${RESTORE_ROOT:-/tmp/triangulate-restore-drill}"

die() { printf 'GAGAL: %s\n' "$*" >&2; exit 1; }
log() { printf '[drill] %s\n' "$*"; }

now_ms() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import time; print(int(time.time() * 1000))'
  else
    printf '%s000' "$(date +%s)"
  fi
}

# Ambil nilai dari manifest.env tanpa `source` (nilai bisa memuat karakter shell).
manifest_get() {
  awk -F= -v k="$1" '$1==k { sub(/^[^=]*=/, ""); print; exit }' "$MANIFEST"
}

if [ -z "$MANIFEST" ]; then
  MANIFEST="$(printf '%s\n' "$BACKUP_DIR"/*/manifest.env | LC_ALL=C sort | tail -n 1)"
  [ -f "$MANIFEST" ] || MANIFEST=""
fi
[ -n "$MANIFEST" ] || die "manifest.env tidak ditemukan di $BACKUP_DIR (isi MANIFEST= atau jalankan backup-repo.sh dulu)"
[ -f "$MANIFEST" ] || die "manifest tidak ada: $MANIFEST"

MAIN_SHA="$(manifest_get MAIN_SHA)"
MAIN_FILES="$(manifest_get MAIN_FILES)"
BUNDLE_PATH="$(manifest_get BUNDLE_PATH)"
BUNDLE_SHA256="$(manifest_get BUNDLE_SHA256)"
[ -n "$MAIN_SHA" ] || die "manifest tidak memuat MAIN_SHA: $MANIFEST"
[ -n "$MAIN_FILES" ] || die "manifest tidak memuat MAIN_FILES: $MANIFEST"
[ -n "$BUNDLE_PATH" ] || die "manifest tidak memuat BUNDLE_PATH: $MANIFEST"
[ -f "$BUNDLE_PATH" ] || die "bundle tidak ada: $BUNDLE_PATH"

log "manifest: $MANIFEST"
log "bundle:   $BUNDLE_PATH"

mkdir -p "$RESTORE_ROOT"
WORK="$(mktemp -d "$RESTORE_ROOT/work.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# --- Kriteria 1: integritas byte bundle ---
if [ -n "$BUNDLE_SHA256" ] && [ "$BUNDLE_SHA256" != "TIDAK_TERSEDIA" ]; then
  if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL_SHA256="$(sha256sum "$BUNDLE_PATH" | awk '{print $1}')"
  else
    ACTUAL_SHA256="$(shasum -a 256 "$BUNDLE_PATH" | awk '{print $1}')"
  fi
  if [ "$ACTUAL_SHA256" != "$BUNDLE_SHA256" ]; then
    printf 'GAGAL: sha256 bundle berbeda (manifest %s, aktual %s)\n' "$BUNDLE_SHA256" "$ACTUAL_SHA256" >&2
    exit 1
  fi
  log "sha256 bundle: OK"
else
  log "sha256 bundle: dilewati (manifest tidak memuat BUNDLE_SHA256)"
fi

# --- Kriteria 2: bundle verify (butuh konteks repo) ---
VERIFY_REPO="$(dirname "$BUNDLE_PATH")/triangulate.git"
if [ ! -d "$VERIFY_REPO" ]; then
  git init --bare -q "$WORK/verify.git"
  VERIFY_REPO="$WORK/verify.git"
fi
T0="$(now_ms)"
if ! git -C "$VERIFY_REPO" bundle verify "$BUNDLE_PATH" >"$WORK/verify.txt" 2>&1; then
  cat "$WORK/verify.txt" >&2
  printf 'GAGAL: git bundle verify gagal\n' >&2
  exit 1
fi
T1="$(now_ms)"
log "bundle verify: OK ($((T1 - T0)) ms)"

# --- Kriteria 2 & 3: restore + bandingkan ---
T2="$(now_ms)"
git clone -q "$BUNDLE_PATH" "$WORK/restored" 2>/dev/null || die "git clone dari bundle gagal"
T3="$(now_ms)"

if git -C "$WORK/restored" show-ref --verify --quiet refs/heads/main; then
  R_REF="refs/heads/main"
elif git -C "$WORK/restored" show-ref --verify --quiet refs/remotes/origin/main; then
  R_REF="refs/remotes/origin/main"
else
  die "ref main tidak ditemukan di hasil restore"
fi

R_SHA="$(git -C "$WORK/restored" rev-parse "$R_REF")"
R_FILES="$(git -C "$WORK/restored" ls-tree -r --name-only "$R_REF" | wc -l | tr -d ' ')"

printf '[drill] %-12s %-42s %s\n' "kriteria" "manifest" "hasil restore"
printf '[drill] %-12s %-42s %s\n' "SHA main" "$MAIN_SHA" "$R_SHA"
printf '[drill] %-12s %-42s %s\n' "jumlah file" "$MAIN_FILES" "$R_FILES"
printf '[drill] %-12s %s\n' "durasi" "restore $((T3 - T2)) ms"

FAIL=0
if [ "$MAIN_SHA" != "$R_SHA" ]; then printf 'GAGAL: SHA main berbeda\n' >&2; FAIL=1; fi
if [ "$MAIN_FILES" != "$R_FILES" ]; then printf 'GAGAL: jumlah file berbeda\n' >&2; FAIL=1; fi
[ "$FAIL" -eq 0 ] || exit 1

printf 'LULUS: SHA main %s dan %s file identik dengan manifest\n' "$R_SHA" "$R_FILES"
