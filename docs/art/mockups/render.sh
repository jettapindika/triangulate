#!/usr/bin/env bash
# Render mockup HTML jadi PNG. Tanpa dependensi Node atau Python.
#
# Pakai Chrome for Testing yang sudah ada di mesin ini. Kalau lokasinya berbeda,
# set CHROME lewat environment variable:
#
#   CHROME=/path/to/chrome ./render.sh
#
# Hasil:
#   01-06  tiap layar, 780x1688 (artboard 390x844 pada skala 2)
#   07     lembar spesifikasi target sentuh
#   08     halaman gaya ilustrasi puzzle
#   09     gabungan keenam layar, untuk lampiran

set -euo pipefail
cd "$(dirname "$0")"

CHROME="${CHROME:-$HOME/.cache/puppeteer/chrome/mac_arm-148.0.7778.97/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing}"

if [ ! -x "$CHROME" ]; then
  echo "Chrome tidak ditemukan di: $CHROME" >&2
  echo "Set CHROME ke path Chrome atau Chromium yang bisa headless." >&2
  exit 1
fi

SCALE=2
BUDGET=8000   # ms; beri waktu font jaringan termuat sebelum dipotret

# shot <hash-atau-file> <lebar> <tinggi> <nama-file>
shot() {
  "$CHROME" --headless --disable-gpu --hide-scrollbars \
    --force-device-scale-factor="$SCALE" \
    --window-size="$2,$3" --virtual-time-budget="$BUDGET" \
    --screenshot="$4" "file://$PWD/$1" >/dev/null 2>&1
  printf '  %-24s %s\n' "$4" "$(magick identify -format '%wx%h' "$4")"
}

echo "Layar mockup:"
shot "index.html#s1"      390 844  01-handler-table.png
shot "index.html#s2"      390 844  02-director-board.png
shot "index.html#s3"      390 844  03-ping-wheel.png
shot "index.html#s4"      390 844  04-searcher-hud.png
shot "index.html#s5"      390 844  05-lobby-rolecard.png
shot "index.html#s6"      390 844  06-case-recap.png

echo "Halaman dokumen:"
shot "index.html#spec"    900 760   07-ui-spec.png
shot "puzzle-style.html" 2080 4200  08-puzzle-style.png

# Buang latar kosong di tepi supaya berkasnya tidak penuh ruang mati.
magick 07-ui-spec.png -fuzz 1% -trim +repage 07-ui-spec.png
magick 08-puzzle-style.png -fuzz 1% -trim +repage 08-puzzle-style.png
printf '  %-24s %s\n' "07-ui-spec.png (trim)" "$(magick identify -format '%wx%h' 07-ui-spec.png)"
printf '  %-24s %s\n' "08-puzzle-style.png (trim)" "$(magick identify -format '%wx%h' 08-puzzle-style.png)"

# Gabungan keenam layar dalam satu baris, untuk lampiran di issue.
echo "Gabungan:"
magick montage 01-handler-table.png 02-director-board.png 03-ping-wheel.png \
  04-searcher-hud.png 05-lobby-rolecard.png 06-case-recap.png \
  -tile 3x2 -geometry +16+16 -background '#0B0908' 09-all-screens.png
printf '  %-24s %s\n' "09-all-screens.png" "$(magick identify -format '%wx%h' 09-all-screens.png)"

echo "Selesai."
