#!/usr/bin/env python3
"""Periksa mockup HTML tanpa membukanya dengan tangan.

Menjalankan Chrome headless, menyuntikkan skrip audit ke salinan sementara
tiap berkas, lalu membaca hasilnya dari DOM. Yang diperiksa:

  1. overflow horizontal pada enam lebar point
  2. elemen yang teksnya keluar dari containernya
  3. jumlah layar dan lembar spesifikasi
  4. target sentuh di bawah 44 point
  5. chip yang ternyata berada di dalam kontrol
  6. keluarga font yang benar-benar terpakai, dibandingkan dengan fallback
  7. gambar yang gagal dimuat di halaman gaya puzzle

Berkas sementara ditulis di direktori ini dan dihapus lagi. Tidak ada berkas
sumber yang diubah.

Pemakaian:
    python3 verify_mockup.py
    CHROME=/path/ke/chrome python3 verify_mockup.py

Keluar dengan kode 1 kalau ada pemeriksaan yang gagal.
"""

import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile

DIR = pathlib.Path(__file__).resolve().parent
CHROME = os.environ.get(
    "CHROME",
    "/Users/mac/.cache/puppeteer/chrome/mac_arm-148.0.7778.97/"
    "chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing",
)
LEBAR = [320, 360, 390, 430, 768, 1400]
FONT = {
    "Nunito": "--font-ui",
    "Merriweather": "--font-archive",
    "Special Elite": "--font-type",
    "Roboto Mono": "--font-code",
}

AUDIT = """
<script>
window.addEventListener("load", function () { setTimeout(function () {
  var de = document.documentElement;
  var out = { doc: de.scrollWidth - de.clientWidth, keluar: [],
              layar: 0, spec: 0, chip: 0, chipKlik: 0, img: 0, imgRusak: 0, font: [] };

  document.querySelectorAll("*").forEach(function (el) {
    if (el.clientWidth > 0 && el.scrollWidth > el.clientWidth + 1 &&
        getComputedStyle(el).overflowX === "visible") {
      out.keluar.push(el.tagName + "." + (el.className || ""));
    }
  });

  out.layar = document.querySelectorAll(".screen").length;
  out.spec = document.querySelectorAll(".spec").length;

  document.querySelectorAll(".chip").forEach(function (c) {
    out.chip++;
    if (c.closest("button") || c.closest("a")) out.chipKlik++;
  });

  var SEL = ["button", ".clue-card", ".ping-slot", ".hud-btn", ".role-opt"];
  out.target = 0; out.bawah44 = []; out.perKelas = {};
  SEL.forEach(function (s) {
    document.querySelectorAll(s).forEach(function (el) {
      out.target++;
      out.perKelas[s] = (out.perKelas[s] || 0) + 1;
      var r = el.getBoundingClientRect();
      if (r.height < 44 || r.width < 44) {
        out.bawah44.push(s + " " + (el.textContent || "").trim().slice(0, 20) + " " +
                          Math.round(r.width) + "x" + Math.round(r.height));
      }
    });
  });

  out.img = document.querySelectorAll("img").length;
  Array.prototype.forEach.call(document.querySelectorAll("img"), function (i) {
    if (!i.complete || i.naturalWidth === 0) out.imgRusak++;
  });

  var c = document.createElement("canvas").getContext("2d");
  var cs = getComputedStyle(document.documentElement);
  var map = __FONT__;
  Object.keys(map).forEach(function (nama) {
    var fam = cs.getPropertyValue(map[nama]).trim();
    if (!fam) return;
    c.font = "400 24px " + fam;       var a = c.measureText("Triangulate 1234567890").width;
    c.font = "400 24px serif";        var s = c.measureText("Triangulate 1234567890").width;
    c.font = "400 24px monospace";    var m = c.measureText("Triangulate 1234567890").width;
    out.font.push({ nama: nama, token: map[nama], lebar: +a.toFixed(2),
                    serif: +s.toFixed(2), mono: +m.toFixed(2),
                    terpakai: Math.abs(a - s) > 0.5 && Math.abs(a - m) > 0.5 });
  });

  var pre = document.createElement("pre");
  pre.id = "AUDIT-RESULT";
  pre.textContent = JSON.stringify(out);
  document.body.appendChild(pre);
}, 3000); });
</script>
"""


def audit(berkas: pathlib.Path, lebar: int) -> dict:
    skrip = AUDIT.replace("__FONT__", json.dumps(FONT))
    sementara = pathlib.Path(tempfile.mkstemp(suffix=".html", dir=DIR)[1])
    try:
        sementara.write_text(berkas.read_text().replace("</body>", skrip + "</body>"))
        keluaran = subprocess.run(
            [CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
             "--virtual-time-budget=15000", f"--window-size={lebar},900",
             "--dump-dom", f"file://{sementara}"],
            capture_output=True, text=True, timeout=120,
        ).stdout
    finally:
        sementara.unlink()
    cocok = re.search(r'<pre id="AUDIT-RESULT">(.*?)</pre>', keluaran, re.S)
    if not cocok:
        raise RuntimeError(f"tidak ada AUDIT-RESULT untuk {berkas.name} pada {lebar} point")
    teks = (cocok.group(1).replace("&quot;", '"').replace("&amp;", "&")
            .replace("&lt;", "<").replace("&gt;", ">"))
    return json.loads(teks)


def main() -> int:
    gagal = []
    halaman = {
        "index.html": {"layar": 6, "spec": 1, "target": 29, "chip": 14},
        "puzzle-style.html": {"layar": 0, "spec": 0, "target": 0, "chip": 0},
    }

    for nama, harapan in halaman.items():
        berkas = DIR / nama
        for lebar in LEBAR:
            d = audit(berkas, lebar)
            status = []
            if d["doc"] != 0:
                gagal.append(f"{nama} @{lebar}: overflow dokumen {d['doc']}")
                status.append(f"overflow={d['doc']}")
            if d["keluar"]:
                gagal.append(f"{nama} @{lebar}: teks keluar container {d['keluar']}")
            if d["bawah44"]:
                gagal.append(f"{nama} @{lebar}: target sentuh di bawah 44 {d['bawah44']}")
            if d["chipKlik"]:
                gagal.append(f"{nama} @{lebar}: {d['chipKlik']} chip berada di dalam kontrol")
            if d["imgRusak"]:
                gagal.append(f"{nama} @{lebar}: {d['imgRusak']} gambar gagal dimuat")
            for kunci, nilai in harapan.items():
                if d[kunci] != nilai:
                    gagal.append(f"{nama} @{lebar}: {kunci} {d[kunci]}, seharusnya {nilai}")
            rinci = " ".join(f"{k}={v}" for k, v in sorted(d["perKelas"].items()))
            print(f"  {nama:20s} @{lebar:5d} point  overflow={d['doc']}  "
                  f"keluar={len(d['keluar'])}  target={d['target']} ({rinci})  "
                  f"bawah44={len(d['bawah44'])}  chip={d['chip']}  chipKlik={d['chipKlik']}  "
                  f"layar={d['layar']}  spec={d['spec']}  img={d['img']}  rusak={d['imgRusak']}")

    d = audit(DIR / "index.html", 390)
    print("\n  Font (keluarga, token, lebar, fallback serif, fallback mono, terpakai):")
    for f in d["font"]:
        print(f"    {f['nama']:14s} {f['token']:16s} {f['lebar']:7.2f}  {f['serif']:7.2f}  "
              f"{f['mono']:7.2f}  {f['terpakai']}")
        if not f["terpakai"]:
            gagal.append(f"font {f['nama']} tidak terpakai, jatuh ke fallback")

    print()
    if gagal:
        print(f"GAGAL: {len(gagal)} pemeriksaan")
        for g in gagal:
            print(f"  - {g}")
        return 1
    print("LULUS: seluruh pemeriksaan bersih.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
