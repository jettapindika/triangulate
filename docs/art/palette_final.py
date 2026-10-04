#!/usr/bin/env python3
"""Token final art bible Triangulate + laporan verifikasi kontras.

Menghasilkan:
  - palette.json   : token warna siap pakai (satu-satunya sumber angka warna)
  - laporan teks   : rasio kontras WCAG 2.1 dan simulasi buta warna

Aturan yang diuji:
  - WCAG 2.1 SC 1.4.3  teks normal >= 4.5:1, teks besar (>=24px / >=18.66px bold) >= 3:1
  - WCAG 2.1 SC 1.4.11 komponen UI & grafis bermakna >= 3:1
  - Pemisahan aksen role diuji di 4 mode penglihatan (normal, deuteranopia,
    protanopia, tritanopia) dengan jarak CIE76; ambang internal 25.
"""
import json
import math
from pathlib import Path


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def srgb_to_lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rel_luminance(h):
    r, g, b = hex_to_rgb(h)
    return 0.2126 * srgb_to_lin(r) + 0.7152 * srgb_to_lin(g) + 0.0722 * srgb_to_lin(b)


def contrast(a, b):
    la, lb = rel_luminance(a), rel_luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


# Simulasi buta warna: matriks Vienot 1999 pada ruang linier.
CVD_MATRIX = {
    "deuteranopia": [[0.625, 0.375, 0.0], [0.700, 0.300, 0.0], [0.0, 0.300, 0.700]],
    "protanopia": [[0.567, 0.433, 0.0], [0.558, 0.442, 0.0], [0.0, 0.242, 0.758]],
    "tritanopia": [[0.950, 0.050, 0.0], [0.0, 0.433, 0.567], [0.0, 0.475, 0.525]],
}


def simulate(hexcolor, kind):
    m = CVD_MATRIX[kind]
    lin = [srgb_to_lin(c) for c in hex_to_rgb(hexcolor)]
    out = [sum(m[i][j] * lin[j] for j in range(3)) for i in range(3)]

    def enc(v):
        v = max(0.0, min(1.0, v))
        s = v * 12.92 if v <= 0.0031308 else 1.055 * (v ** (1 / 2.4)) - 0.055
        return round(max(0.0, min(1.0, s)) * 255)

    return "#%02X%02X%02X" % tuple(enc(v) for v in out)


def lab(hexcolor):
    r, g, b = [srgb_to_lin(c) for c in hex_to_rgb(hexcolor)]
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 1.0
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116

    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def de76(a, b):
    la, lb = lab(a), lab(b)
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(la, lb)))

TOKENS = {
    # --- Base gelap: cokelat-hitam hangat, bukan hitam murni ---
    "noir-950": {"hex": "#0B0908", "peran": "void terluar, latar dokumen di luar meja"},
    "noir-900": {"hex": "#14100E", "peran": "latar terdalam (void, luar area meja)"},
    "noir-800": {"hex": "#1D1815", "peran": "latar panel standar"},
    "noir-700": {"hex": "#282019", "peran": "panel terangkat / kartu"},
    "noir-600": {"hex": "#35291F", "peran": "permukaan terangkat / hover"},
    "noir-500": {"hex": "#46372A", "peran": "dekoratif saja, bukan pembawa makna"},
    "noir-400": {"hex": "#5E4B3A", "peran": "dekoratif saja, bukan pembawa makna"},

    # --- Garis & ikon: wajib lulus 3:1 di noir-900/800/700 ---
    "line": {"hex": "#7A7168", "peran": "garis pemisah bermakna, batas kolom"},
    "icon-mute": {"hex": "#7D7166", "peran": "ikon informatif yang tidak aktif"},

    # --- Kertas & cahaya ---
    "paper-100": {"hex": "#F4EDE1", "peran": "teks utama"},
    "paper-200": {"hex": "#E2D8C6", "peran": "teks sekunder terang"},
    "paper-300": {"hex": "#C3B7A2", "peran": "teks sekunder"},
    "paper-400": {"hex": "#9A9080", "peran": "teks tersier / label kecil"},
    "lamp-100": {"hex": "#FFE0B0", "peran": "kilau lampu, sorotan teratas"},
    "lamp-300": {"hex": "#F0B457", "peran": "aksen utama, cincin fokus, tombol primer"},
    "lamp-500": {"hex": "#E09A2E", "peran": "lampu meja Handler (identitas visual)"},

    # --- Material dunia ---
    "wood-900": {"hex": "#2A1D13", "peran": "kayu paling gelap, ujung gradien meja"},
    "wood-700": {"hex": "#4A3524", "peran": "kayu gelap, bingkai meja"},
    "wood-500": {"hex": "#6E5136", "peran": "kayu sedang, badan meja"},
    "wood-300": {"hex": "#96714B", "peran": "kayu terang, tepi terpotong"},
    "brass-500": {"hex": "#C9A227", "peran": "kuningan, logam kecil, sekrup, engsel"},

    # --- Tinta di atas kertas: dipakai untuk dokumen, kartu clue, bukti cetak ---
    "ink-900": {"hex": "#2A2118", "peran": "teks isi di atas kertas"},
    "ink-700": {"hex": "#4A3A28", "peran": "tinta mesin tik, huruf bukti cetak"},
    "ink-alert": {"hex": "#8E2F26", "peran": "teks peringatan di atas kertas, versi gelap dari alert"},
    "paper-contra": {"hex": "#F3D9D4", "peran": "permukaan kartu kontradiksi, satu-satunya kartu berwarna"},

    # --- Aksen role ---
    "role-searcher": {"hex": "#5FA8D3", "peran": "Searcher (biru senter)"},
    "role-handler": {"hex": "#E09A2E", "peran": "Handler (amber lampu meja)"},
    "role-director": {"hex": "#B96A9E", "peran": "Director (plum tinta buku besar) - grafis/chip/ikon"},
    "role-director-text": {"hex": "#BE7AA6", "peran": "Director - varian untuk teks, lulus 4.5:1"},
    "role-npc": {"hex": "#8A93A0", "peran": "NPC / Archivist"},

    # --- Status ---
    "ok": {"hex": "#63B37A", "peran": "berhasil, terverifikasi"},
    "alert": {"hex": "#E36459", "peran": "peringatan, salah, timer cleanup (margin 4.76:1)"},
}

# Pasangan teks (fg, bg) -> teks normal 4.5:1
TEKS = [
    ("paper-100", "noir-900"), ("paper-100", "noir-800"), ("paper-100", "noir-700"),
    ("paper-100", "noir-600"), ("paper-100", "noir-500"),
    ("paper-200", "noir-800"), ("paper-200", "noir-700"), ("paper-200", "noir-600"),
    ("paper-300", "noir-900"), ("paper-300", "noir-800"), ("paper-300", "noir-700"),
    ("paper-400", "noir-900"), ("paper-400", "noir-800"), ("paper-400", "noir-700"),
    ("lamp-100", "noir-900"), ("lamp-100", "noir-800"), ("lamp-100", "noir-700"),
    ("lamp-300", "noir-900"), ("lamp-300", "noir-800"), ("lamp-300", "noir-700"),
    ("role-searcher", "noir-900"), ("role-searcher", "noir-800"), ("role-searcher", "noir-700"),
    ("role-handler", "noir-900"), ("role-handler", "noir-800"), ("role-handler", "noir-700"),
    ("role-director-text", "noir-900"), ("role-director-text", "noir-800"), ("role-director-text", "noir-700"),
    ("role-npc", "noir-900"), ("role-npc", "noir-800"), ("role-npc", "noir-700"),
    ("ok", "noir-900"), ("ok", "noir-800"), ("ok", "noir-700"),
    ("alert", "noir-900"), ("alert", "noir-800"), ("alert", "noir-700"),
    ("brass-500", "noir-900"), ("brass-500", "noir-800"), ("brass-500", "noir-700"),
    # Teks gelap di atas permukaan terang (tombol primer, chip aktif)
    ("noir-900", "lamp-100"), ("noir-900", "lamp-300"), ("noir-900", "paper-100"),
    ("noir-900", "paper-300"), ("noir-900", "brass-500"), ("noir-900", "ok"),
    ("noir-900", "alert"), ("noir-900", "role-searcher"), ("noir-900", "role-director-text"),
    # Teks di atas material kayu
    ("paper-100", "wood-700"), ("paper-100", "wood-500"), ("paper-300", "wood-700"),
    # Teks tinta di atas kertas (dokumen, kartu clue, bukti cetak)
    ("ink-900", "paper-100"), ("ink-900", "paper-200"), ("ink-900", "paper-300"),
    ("ink-700", "paper-100"), ("ink-700", "paper-200"),
    ("ink-alert", "paper-100"), ("ink-alert", "paper-200"), ("ink-alert", "paper-contra"),
    ("ink-900", "paper-contra"), ("ink-700", "paper-contra"), ("noir-900", "paper-contra"),
    ("noir-900", "paper-200"),
]

# Komponen UI & grafis bermakna -> 3:1
GRAFIS = [
    ("line", "noir-900", "garis pemisah"), ("line", "noir-800", "garis pemisah"),
    ("line", "noir-700", "garis pemisah"),
    ("icon-mute", "noir-900", "ikon informatif"), ("icon-mute", "noir-800", "ikon informatif"),
    ("icon-mute", "noir-700", "ikon informatif"),
    ("lamp-300", "noir-900", "cincin fokus"), ("lamp-300", "noir-800", "cincin fokus"),
    ("lamp-300", "noir-700", "cincin fokus"),
    ("role-searcher", "noir-800", "chip role"), ("role-handler", "noir-800", "chip role"),
    ("role-director", "noir-800", "chip role"), ("role-npc", "noir-800", "chip role"),
    ("ok", "noir-800", "badge status"), ("alert", "noir-800", "badge status"),
    ("wood-300", "noir-800", "tepi material"), ("wood-300", "noir-700", "tepi material"),
    ("brass-500", "noir-800", "logam"),
]

ROLE_AKSEN = ["role-searcher", "role-handler", "role-director"]
MODE = ["normal", "deuteranopia", "protanopia", "tritanopia"]
AMBANG_ROLE = 25.0


def c(a, b):
    return contrast(TOKENS[a]["hex"], TOKENS[b]["hex"])


def laporan():
    baris = []
    gagal = []

    baris.append("A. KONTRAS TEKS - WCAG 2.1 SC 1.4.3 (normal >= 4.5:1)")
    baris.append("-" * 72)
    for fg, bg in TEKS:
        r = c(fg, bg)
        ok = r >= 4.5
        if not ok:
            gagal.append(("teks", fg, bg, round(r, 2), 4.5))
        baris.append(f"  {'PASS' if ok else 'FAIL'}  {r:6.2f}:1   {fg} di {bg}")

    baris.append("")
    baris.append("B. KOMPONEN UI & GRAFIS - WCAG 2.1 SC 1.4.11 (>= 3:1)")
    baris.append("-" * 72)
    for fg, bg, label in GRAFIS:
        r = c(fg, bg)
        ok = r >= 3.0
        if not ok:
            gagal.append(("grafis", fg, bg, round(r, 2), 3.0))
        baris.append(f"  {'PASS' if ok else 'FAIL'}  {r:6.2f}:1   {fg} di {bg:9s} [{label}]")

    baris.append("")
    baris.append(f"C. PEMISAHAN AKSEN ROLE DI 4 MODE PENGLIHATAN (CIE76 >= {AMBANG_ROLE})")
    baris.append("-" * 72)
    for m in MODE:
        sim = {}
        for r_ in ROLE_AKSEN:
            h = TOKENS[r_]["hex"]
            sim[r_] = h if m == "normal" else simulate(h, m)
        baris.append(f"  {m}: " + "  ".join(f"{k.split('-')[1]}={v}" for k, v in sim.items()))
        for i, a in enumerate(ROLE_AKSEN):
            for b in ROLE_AKSEN[i + 1:]:
                d = de76(sim[a], sim[b])
                ok = d >= AMBANG_ROLE
                if not ok:
                    gagal.append(("role", a, b, round(d, 1), AMBANG_ROLE))
                baris.append(f"    {'PASS' if ok else 'FAIL'}  dE76 {d:6.1f}  {a} vs {b}")

    baris.append("")
    baris.append("D. RINGKASAN")
    baris.append("-" * 72)
    if gagal:
        baris.append(f"  {len(gagal)} pasangan GAGAL:")
        for g in gagal:
            baris.append(f"    {g}")
    else:
        baris.append("  Semua pasangan lulus ambang.")
    return "\n".join(baris), gagal


if __name__ == "__main__":
    teks, gagal = laporan()
    print(teks)
    out = {
        "meta": {
            "sumber_aturan": [
                "WCAG 2.1 SC 1.4.3 Contrast (Minimum)",
                "WCAG 2.1 SC 1.4.11 Non-text Contrast",
                "WCAG 2.1 SC 1.4.1 Use of Color",
            ],
            "catatan": "Warna adalah kanal sekunder; setiap penanda role wajib "
                       "disertai ikon dan label teks.",
            "ambang_pemisahan_role_cie76": AMBANG_ROLE,
        },
        "tokens": {k: v["hex"] for k, v in TOKENS.items()},
        "peran_token": {k: v["peran"] for k, v in TOKENS.items()},
        "gagal": gagal,
    }
    # Tulis di sebelah skrip, bukan di direktori kerja, supaya bisa dijalankan dari mana saja.
    tujuan = Path(__file__).resolve().parent / "palette.json"
    json.dump(out, open(tujuan, "w"), indent=2, ensure_ascii=False)
    print(f"\n{tujuan.name} ditulis.")
