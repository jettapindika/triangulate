#!/usr/bin/env python3
"""Buat dua contoh gaya ilustrasi 1024x1024 untuk uji downscale.

Kedua contoh menggambar **komposisi yang sama persis** (jendela, bulan, dua
bangunan, pintu pada koordinat yang sama). Yang berbeda hanya cara mengisi
bidangnya:

  Gaya A, flat    - tiap bidang satu warna rata.
  Gaya B, gradien - tiap bidang diisi gradien menuju warna bidang tetangganya,
                    jadi batas antar bidang menyatu.

Dengan begitu selisih hasil ukur hanya berasal dari gaya pengisian, bukan dari
komposisi yang kebetulan berbeda. Warna dibaca dari ../tokens.css supaya berkas
yang diukur dan yang ditampilkan di puzzle-style.html tidak bisa berbeda.

Jalankan dari direktori mockups:
    python3 make_style_samples.py
"""
import re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
SISI = 1024
SKALA = SISI // 256  # bentuk digambar pada skala 256, dinaikkan 4x
RADIUS_BLUR = 12     # radius blur gaya lembut, 12 px pada 1024 = 3 px pada 256

# Bentuk: nama, kotak pada skala 256, token warna, token warna bidang di bawahnya.
BENTUK = [
    ("jendela", (36, 40, 120, 136), "--lamp-300", "--noir-700"),
    ("bulan", (150, 36, 212, 98), "--lamp-100", "--noir-700"),
    ("bld2", (60, 118, 136, 158), "--wood-500", "--noir-700"),
    ("bld", (30, 150, 226, 226), "--wood-700", "--noir-700"),
    ("pintu", (118, 178, 152, 226), "--noir-900", "--wood-700"),
]


def token():
    """Baca token warna dari tokens.css. Satu sumber nilai, tanpa salinan."""
    css = (HERE.parent / "tokens.css").read_text()
    pasangan = re.findall(r"^\s*(--[a-z0-9-]+)\s*:\s*(#[0-9A-Fa-f]{6})\s*;", css, re.M)
    return dict(pasangan)


T = token()


def hex_ke_rgb(nilai):
    return tuple(int(nilai[i + 1:i + 3], 16) for i in (0, 2, 4))


def luma(rgb):
    return 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]


def campur(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def kotak_256(k):
    x0, y0, x1, y1 = k
    return [x0 * SKALA, y0 * SKALA, x1 * SKALA, y1 * SKALA]


def gaya_flat():
    """Bidang rata, tepi keras, tanpa gradien."""
    im = Image.new("RGB", (SISI, SISI), hex_ke_rgb(T["--noir-700"]))
    d = ImageDraw.Draw(im)
    for nama, kotak, warna, _ in BENTUK:
        if nama == "bulan":
            d.ellipse(kotak_256(kotak), fill=hex_ke_rgb(T[warna]))
        else:
            d.rectangle(kotak_256(kotak), fill=hex_ke_rgb(T[warna]))
    return im


def gaya_gradien():
    """Komposisi dan warna sama persis, tetapi setiap bentuk digambar lembut.

    Bentuk digambar seperti gaya flat, lalu diblur dengan radius 12 px pada skala
    1024 (setara 3 px pada skala 256). Hasilnya tidak punya tepi keras sama
    sekali: batas antar bentuk menjadi tanjakan warna yang landai.

    Inilah gaya yang ditolak. Bukan karena warnanya, tetapi karena tidak ada tepi
    yang bisa dipertahankan oleh resampler saat texture diturunkan.
    """
    im = Image.new("RGB", (SISI, SISI), hex_ke_rgb(T["--noir-700"]))
    d = ImageDraw.Draw(im)
    for nama, kotak, warna, _ in BENTUK:
        if nama == "bulan":
            d.ellipse(kotak_256(kotak), fill=hex_ke_rgb(T[warna]))
        else:
            d.rectangle(kotak_256(kotak), fill=hex_ke_rgb(T[warna]))
    return im.filter(ImageFilter.GaussianBlur(RADIUS_BLUR))


if __name__ == "__main__":
    for nama, gambar in [("style-flat-1024.png", gaya_flat()),
                         ("style-grad-1024.png", gaya_gradien())]:
        gambar.save(HERE / nama)
        print(f"{nama} {gambar.size[0]}x{gambar.size[1]}")

    print()
    print("Jarak luma antar bidang pada gambar 1024 (skala 0 sampai 255):")
    for a, b in [("pintu", "bld"), ("jendela", "noir"), ("bld", "noir")]:
        warna_a = next(w for n, k, w, _ in BENTUK if n == a) if a != "noir" else "--noir-700"
        warna_b = next(w for n, k, w, _ in BENTUK if n == b) if b != "noir" else "--noir-700"
        la, lb = luma(hex_ke_rgb(T[warna_a])), luma(hex_ke_rgb(T[warna_b]))
        print(f"  flat    {a:<8} ke {b:<8} {abs(la - lb):5.1f}")
        ujung = campur(hex_ke_rgb(T[warna_a]), hex_ke_rgb(T[warna_b]), 0.5)
        print(f"  gradien {a:<8} ke {b:<8} {abs(la - luma(ujung)):5.1f}")
