#!/usr/bin/env python3
"""Ukur ketahanan dua gaya ilustrasi terhadap downscale.

Semua angka di puzzle-style.html dan puzzle-style.md berasal dari skrip ini,
sehingga bisa diperiksa ulang, bukan dikutip dari tempat lain.

Bahan ujinya dua PNG 1024x1024 dari make_style_samples.py. Keduanya menggambar
komposisi dan warna yang sama persis; yang berbeda hanya cara tepi bentuknya
digambar. Gaya A bertepi keras, gaya B bertepi lembut.

Tiga hal yang diukur, semuanya pada skala 0 sampai 255 (luma Rec. 601):

  1. KONTRAS BIDANG pada empat ukuran. Menjawab apakah warna bidang berubah
     saat texture diturunkan.
       terang  - kecerahan rata-rata area menyala
       gelap   - kecerahan rata-rata area gelap
       kontras - terang dikurangi gelap
       detail  - selisih kecerahan pintu (detail terkecil) dengan dindingnya

  2. LEBAR ZONA TRANSISI tepi bentuk, pada skala 256. Diukur dari titik yang
     warnanya 10% menuju warna bentuk sampai titik yang 90%. Ini yang menentukan
     apakah sebuah bentuk masih punya batas saat texture diturunkan.

  3. UKURAN FITUR TERKECIL YANG BERTAHAN, diukur dari puncak kecerahannya dan
     dirata-ratakan pada beberapa geseran setengah piksel supaya hasilnya tidak
     bergantung pada kebetulan posisi.

Jalankan dari direktori mockups:
    python3 measure_downscale.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
SKALA_256 = 4  # gambar skala 256 menjadi 1024
BAHAN = [("A, flat", "style-flat-1024.png"), ("B, lembut", "style-grad-1024.png")]

# Kotak sampling sebagai fraksi sisi gambar, sama di semua ukuran.
KOTAK = {
    "terang": (0.16, 0.17, 0.45, 0.50),
    "gelap": (0.02, 0.02, 0.12, 0.14),
    "pintu": (0.47, 0.71, 0.58, 0.85),
    "dinding": (0.13, 0.60, 0.44, 0.85),
}

UKURAN = [1024, 512, 256, 128]

# Tepi kiri pintu pada skala 256, tempat lebar transisi diukur.
TEPI_PINTU = {"luar": 112, "dalam": 135, "baris": 200}

# Ukuran sisi tanda uji, pada skala 256.
UKURAN_FITUR = [2, 3, 4, 6, 8, 12, 16]

# Ambang bacanya: fitur dianggap masih utuh kalau puncaknya minimal 95% dari
# kedalaman nominal. Di bawah itu bentuknya sudah melemah oleh resampling.
AMBANG_FITUR = 0.95

# Warna uji bagian 3, dibaca dari tokens.css.
TOKEN_UJI = {"gelap": "--noir-700", "terang": "--lamp-100"}


def baca_token():
    import re
    css = (HERE.parent / "tokens.css").read_text()
    return dict(re.findall(r"^\s*(--[a-z0-9-]+)\s*:\s*(#[0-9A-Fa-f]{6})\s*;", css, re.M))


def hex_ke_rgb(nilai):
    return tuple(int(nilai[i + 1:i + 3], 16) for i in (0, 2, 4))


def luma(rgb):
    return 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]


def rerata(im, fraksi):
    """Kecerahan rata-rata pada kotak fraksi.

    Batas kotak dibulatkan ke piksel bulat dan lebarnya dijamin minimal 1 px,
    supaya galat pembulatan tidak ikut terukur pada ukuran kecil.
    """
    w, h = im.size
    x0, y0, x1, y1 = fraksi
    kiri, atas = round(x0 * w), round(y0 * h)
    kanan = max(kiri + 1, round(x1 * w))
    bawah = max(atas + 1, round(y1 * h))
    px = list(im.crop((kiri, atas, kanan, bawah)).get_flattened_data())
    return sum(luma(p) for p in px) / len(px)


def ukur_bidang(berkas, nama):
    """Kontras bidang pada empat ukuran, dari satu berkas sumber 1024."""
    sumber = Image.open(berkas).convert("RGB")
    if sumber.size != (1024, 1024):
        raise SystemExit(f"{berkas} harus 1024x1024, ditemukan {sumber.size}")
    baris = []
    for n in UKURAN:
        im = sumber if n == 1024 else sumber.resize((n, n), Image.LANCZOS)
        nilai = {k: rerata(im, f) for k, f in KOTAK.items()}
        baris.append({
            "gaya": nama, "px": n,
            "terang": nilai["terang"], "gelap": nilai["gelap"],
            "kontras": nilai["terang"] - nilai["gelap"],
            # Nilai mutlak: yang penting besar bedanya, bukan arahnya.
            "detail": abs(nilai["pintu"] - nilai["dinding"]),
        })
    return baris


def lebar_transisi(berkas):
    """Lebar zona transisi tepi kiri pintu, dinyatakan pada skala 256.

    Tepi keras memberi sekitar 1 px; tepi berblur memberi lebar sebesar blur-nya.
    """
    im = Image.open(berkas).convert("RGB")
    y = TEPI_PINTU["baris"] * SKALA_256
    x0 = TEPI_PINTU["luar"] * SKALA_256
    x1 = TEPI_PINTU["dalam"] * SKALA_256
    baris = [luma(im.getpixel((x, y))) for x in range(x0, x1)]

    gelap, terang = min(baris), max(baris)
    jarak = terang - gelap
    if jarak < 1:
        return 0.0
    t10, t90 = gelap + 0.1 * jarak, gelap + 0.9 * jarak
    awal = [i for i, v in enumerate(baris) if v >= t90]
    akhir = [i for i, v in enumerate(baris) if v <= t10]
    if not awal or not akhir:
        return 0.0
    return (abs(akhir[0] - awal[-1]) + 1) / SKALA_256


def ukur_fitur():
    """Kedalaman puncak sebuah tanda persegi setelah diturunkan ke 128 px.

    Tanda digambar pada bidang gelap dengan warna terang. Puncaknya diukur pada
    empat geseran setengah piksel lalu dirata-ratakan, supaya hasilnya tidak
    bergantung pada apakah tanda jatuh tepat di piksel bulat.
    """
    T = baca_token()
    gelap = hex_ke_rgb(T[TOKEN_UJI["gelap"]])
    terang = hex_ke_rgb(T[TOKEN_UJI["terang"]])
    luma_gelap = luma(gelap)
    nominal = luma(terang) - luma_gelap

    hasil = []
    for sisi in UKURAN_FITUR:
        kedalaman = []
        for geser in (0, 1, 2, 3):
            besar = Image.new("RGB", (1024, 1024), gelap)
            s4 = sisi * SKALA_256
            x0 = 512 - s4 // 2 + geser
            ImageDraw.Draw(besar).rectangle([x0, x0, x0 + s4 - 1, x0 + s4 - 1],
                                            fill=terang)
            for n in (256, 128):
                im = besar.resize((n, n), Image.LANCZOS)
                # Daerah sekitar tanda: dua kali lipat sisi tanda, supaya tepi
                # tanda selalu masuk walaupun posisinya bergeser.
                tepi = max(1, round(s4 * n / 1024))
                pusat = 512 * n // 1024
                k0, k1 = max(0, pusat - tepi), min(n, pusat + tepi)
                px = im.crop((k0, k0, k1, k1)).get_flattened_data()
                kedalaman.append(max(abs(luma(q) - luma_gelap) for q in px) / nominal)
        hasil.append({"sisi": sisi, "rasio": sum(kedalaman) / len(kedalaman)})
    return hasil


if __name__ == "__main__":
    semua = []
    for nama, berkas in BAHAN:
        semua += ukur_bidang(HERE / berkas, nama)

    print("1. KONTRAS BIDANG PADA TIAP UKURAN")
    print(f"{'gaya':<12}{'px':>6}{'terang':>9}{'gelap':>8}{'kontras':>9}{'detail':>8}")
    print("-" * 52)
    for b in semua:
        print(f"{b['gaya']:<12}{b['px']:>6}{b['terang']:>9.1f}{b['gelap']:>8.1f}"
              f"{b['kontras']:>9.1f}{b['detail']:>8.1f}")
    print()
    print("Perubahan dari 1024 ke 128 px:")
    for nama, _ in BAHAN:
        k = [b for b in semua if b["gaya"] == nama]
        print(f"  {nama:<12} kontras {100 * (k[-1]['kontras'] / k[0]['kontras'] - 1):+5.1f}%"
              f"   detail {100 * (k[-1]['detail'] / k[0]['detail'] - 1):+5.1f}%")

    print()
    print("2. LEBAR ZONA TRANSISI PADA TEPI BENTUK (skala 256)")
    print(f"{'gaya':<12}{'lebar px':>10}   putusan")
    print("-" * 44)
    for nama, berkas in BAHAN:
        lebar = lebar_transisi(HERE / berkas)
        print(f"{nama:<12}{lebar:>10.1f}   "
              f"{'tepi keras' if lebar <= 2 else 'tepi landai'}")

    print()
    print("3. FITUR TERKECIL YANG MASIH TERBACA SETELAH TURUN KE 128 PX")
    print(f"   ambang baca: puncak minimal {AMBANG_FITUR:.2f} dari kedalaman nominal")
    print(f"{'sisi px':>8}{'kedalaman':>11}   putusan")
    print("-" * 40)
    batas = None
    for b in ukur_fitur():
        lulus = b["rasio"] >= AMBANG_FITUR
        if lulus and batas is None:
            batas = b["sisi"]
        print(f"{b['sisi']:>8}{b['rasio']:>11.2f}   "
              f"{'terbaca' if lulus else 'tidak terbaca'}")
    print()
    print(f"Fitur terkecil yang masih terbaca: {batas} px pada skala 256, "
          f"setara {batas * SKALA_256} px pada sheet 1024.")
    print(f"Ambang produksi dipasang di 6 px pada skala 256, yaitu "
          f"{6 / batas:.1f}x lipat titik lemah, untuk menutup kompresi texture dan")
    print("resampler perangkat yang bukan LANCZOS. Pada sel yang tampil 170 px,")
    print("6 px di skala 256 setara 4 px di layar, masih di atas ambang terlihat.")
