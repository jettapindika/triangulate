#!/usr/bin/env python3
"""Agregasi event telemetri Triangulate -> laporan metrik PRD §12.

Dua tahap dalam satu berkas:

  reduce : event mentah (NDJSON, satu objek per baris) -> dataset
           {sessions, lobbies, releases, anomalies}
  report : dataset -> tabel markdown siap tempel, satu baris per metrik
           PRD §12, lengkap dengan target dan verdict

Tanpa LLM dan tanpa tafsir: skrip ini tidak pernah menebak angka. Metrik yang
datanya belum ada ditulis `NO DATA`, bukan 0.

Pakai:
  tools/metric-report.py --events events.ndjson
  tools/metric-report.py --events events.ndjson --emit-summaries sessions.ndjson
  tools/metric-report.py --summaries sessions.ndjson --as-of 2026-10-12

Keluar: 0 = laporan tercetak; 1 = input tidak bisa dibaca.

KONTRAK EVENT — USULAN, bukan keputusan otomasi ini.
Definisi resmi metrik dan nama event milik Rani (EXTA-36, "Kamus metrik dan
skema event telemetri"). Nama di bawah adalah bentuk minimum yang dibutuhkan
skrip ini supaya bisa dijalankan dan diuji sekarang. Kalau EXTA-36 menetapkan
nama lain, cukup ubah tabel EVENTS di bawah; rumusnya tidak ikut berubah.
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

# --- kontrak event (lihat docstring) ---------------------------------------

EVENTS = {
    "lobby_enter": "Pemain masuk antrean matchmaking",
    "lobby_wait": "Antrean selesai; field: wait_s (float, detik)",
    "lobby_fail": "Sesi gagal start",
    "session_start": "Sesi mulai; field: case_id (str), is_case0 (bool)",
    "idle_start": "Awal idle tanpa input bermakna",
    "idle_end": "Akhir idle",
    "hint_used": "Satu hint dipakai",
    "accusation_submitted": "Tuduhan dikirim; field: correct (bool)",
    "session_end": "Sesi selesai; field: duration_s (float), solved (bool)",
    "case_released": "Story case baru dirilis; field: case_id (str). Bukan daily case.",
}

ROLES = ("searcher", "handler", "director")

# Ambang PRD §12/§6 — dipakai untuk verdict, bukan untuk menghitung nilai.
# Satu sumber kebenaran: docs/metrics.json. Tidak ada salinan kedua di sini.
METRICS_JSON = Path(__file__).resolve().parent.parent / "docs" / "metrics.json"

def load_targets(path: Path) -> dict:
    """Baca target + arah pembanding dari docs/metrics.json.

    Sengaja TIDAK ada nilai cadangan di kode: kalau berkasnya hilang atau
    rusak, skrip berhenti. Angka target yang disalin ke kode akan menyimpang
    dari PRD tanpa ada yang tahu.
    """
    try:
        spec = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SystemExit(f"berkas metrik tidak ditemukan: {path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{path}: JSON tidak valid: {exc}") from exc

    targets = {}
    for entry in spec.get("metrics", []):
        key = entry.get("id")
        if not key:
            raise SystemExit(f"{path}: ada metrik tanpa field 'id'")
        direction = entry.get("direction")
        if direction == "band":
            low, high = entry.get("target_low"), entry.get("target_high")
            if low is None or high is None:
                raise SystemExit(f"{path}: {key} berarah band tanpa target_low/target_high")
            target = (float(low), float(high))
        elif direction in ("gte", "lte"):
            if entry.get("target") is None:
                raise SystemExit(f"{path}: {key} berarah {direction} tanpa 'target'")
            target = float(entry["target"])
        elif direction == "track":
            target = None
        else:
            raise SystemExit(f"{path}: {key} punya direction tidak dikenal: {direction!r}")
        targets[key] = {
            "target": target,
            "direction": direction,
            "text": entry.get("target_text", ""),
            "period_days": entry.get("period_days"),
        }
    return targets

TARGETS = load_targets(METRICS_JSON)

FIRST_5MIN = 300.0


def parse_ts(value: str) -> datetime:
    text = value.replace("Z", "+00:00")
    parsed = datetime.fromisoformat(text)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def load_ndjson(path: str) -> list[dict]:
    rows = []
    with open(path, encoding="utf-8") as handle:
        for lineno, line in enumerate(handle, 1):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError as exc:
                raise SystemExit(f"{path}:{lineno}: JSON tidak valid: {exc}") from exc
    return rows


def reduce_events(events: list[dict]) -> dict:
    """Event mentah -> dataset {sessions, lobbies, releases, anomalies}."""
    unknown: dict[str, int] = defaultdict(int)
    sessions: dict[str, dict] = {}
    lobbies: list[dict] = []
    current_lobby: dict | None = None
    releases: list[dict] = []

    for event in events:
        name = event.get("event")
        if name not in EVENTS:
            unknown[str(name)] += 1
            continue
        ts = parse_ts(event["ts"])

        if name == "case_released":
            releases.append({"ts": ts, "case_id": event.get("case_id")})
            continue

        if name == "lobby_enter":
            current_lobby = {"entered_at": ts}
        elif name == "lobby_wait" and current_lobby is not None:
            current_lobby["wait_s"] = float(event["wait_s"])
            lobbies.append(current_lobby)
            current_lobby = None
        elif name == "lobby_fail" and current_lobby is not None:
            current_lobby["failed"] = True
            lobbies.append(current_lobby)
            current_lobby = None

        sid = event.get("session_id")
        if sid is None:
            continue
        session = sessions.setdefault(
            sid,
            {
                "session_id": sid,
                "roles": set(),
                "players": set(),
                "started_at": None,
                "ended_at": None,
                "duration_s": None,
                "solved": None,
                "is_case0": False,
                "hints": 0,
                "idle_s": {role: 0.0 for role in ROLES},
                "open_idle": {},
                "accusations": 0,
                "correct_accusations": 0,
            },
        )
        role = event.get("role")
        if role in ROLES:
            session["roles"].add(role)
        if event.get("player_id"):
            session["players"].add(event["player_id"])

        if name == "session_start":
            session["started_at"] = ts
            session["is_case0"] = bool(event.get("is_case0", False))
        elif name == "idle_start" and role in ROLES:
            session["open_idle"][role] = ts
        elif name == "idle_end" and role in ROLES:
            opened = session["open_idle"].pop(role, None)
            if opened is not None:
                session["idle_s"][role] += (ts - opened).total_seconds()
        elif name == "hint_used":
            session["hints"] += 1
        elif name == "accusation_submitted":
            session["accusations"] += 1
            if event.get("correct"):
                session["correct_accusations"] += 1
        elif name == "session_end":
            session["ended_at"] = ts
            session["duration_s"] = event.get("duration_s")
            session["solved"] = bool(event.get("solved", False))

    out = []
    for session in sessions.values():
        session["roles"] = sorted(session["roles"])
        session["players"] = sorted(session["players"])
        session["duration_s"] = resolve_duration(session)
        session["idle_s"] = {r: round(v, 3) for r, v in session["idle_s"].items()}
        session.pop("open_idle")
        out.append(session)
    out.sort(key=lambda s: (s["started_at"] or datetime.min.replace(tzinfo=timezone.utc), s["session_id"]))

    anomalies = {
        "unknown_events": dict(sorted(unknown.items())),
        "sessions_without_start": sum(1 for s in out if s["started_at"] is None),
        "sessions_without_end": sum(1 for s in out if s["ended_at"] is None),
        "sessions_without_role": sum(1 for s in out if not s["roles"]),
        "lobby_attempts": len(lobbies),
    }
    return {
        "sessions": out,
        "lobbies": lobbies,
        "releases": releases,
        "anomalies": anomalies,
    }


def resolve_duration(session: dict) -> float | None:
    if session["duration_s"] is not None:
        return float(session["duration_s"])
    if session["started_at"] and session["ended_at"]:
        return (session["ended_at"] - session["started_at"]).total_seconds()
    return None


def load_summaries(path: str) -> dict:
    """Ringkasan NDJSON -> dataset dengan bentuk yang sama seperti reduce_events."""
    sessions, lobbies, releases = [], [], []
    anomalies = None
    for row in load_ndjson(path):
        kind = row.get("kind", "session")
        if kind == "anomaly":
            anomalies = row.get("counts") or {}
            continue
        for key in ("started_at", "ended_at", "entered_at", "ts"):
            if row.get(key):
                row[key] = parse_ts(row[key])
        row.pop("kind", None)
        bucket = {"session": sessions, "lobby": lobbies, "release": releases}.get(kind)
        if bucket is None:
            raise SystemExit(f"{path}: kind tidak dikenal: {kind!r}")
        bucket.append(row)
    if anomalies is None:
        # Berkas ringkasan lama/tulisan tangan: hitung ulang yang bisa dihitung,
        # sisanya tidak bisa dipulihkan dan ditandai apa adanya.
        anomalies = {
            "unknown_events": {},
            "sessions_without_start": sum(1 for s in sessions if not s.get("started_at")),
            "sessions_without_end": sum(1 for s in sessions if not s.get("ended_at")),
            "sessions_without_role": sum(1 for s in sessions if not s.get("roles")),
            "lobby_attempts": len(lobbies),
        }
    return {
        "sessions": sessions,
        "lobbies": lobbies,
        "releases": releases,
        "anomalies": anomalies,
    }


def dumps_summaries(dataset: dict) -> str:
    lines = []
    for kind, rows in (("session", dataset["sessions"]), ("lobby", dataset["lobbies"]),
                       ("release", dataset["releases"])):
        for row in rows:
            out = dict(row, kind=kind)
            for key in ("started_at", "ended_at", "entered_at", "ts"):
                if out.get(key):
                    out[key] = out[key].isoformat().replace("+00:00", "Z")
            lines.append(json.dumps(out, sort_keys=True, ensure_ascii=False))
    anomalies = dataset["anomalies"]
    lines.append(json.dumps({"kind": "anomaly", "counts": anomalies}, sort_keys=True, ensure_ascii=False))
    return "\n".join(lines) + "\n"


# --- metrik PRD §12 ---------------------------------------------------------

def compute(dataset: dict, as_of: date, window_days: int) -> dict:
    sessions = dataset["sessions"]
    lobbies = dataset["lobbies"]
    releases = dataset["releases"]
    since = as_of - timedelta(days=window_days)
    window = [
        s
        for s in sessions
        if s["started_at"] is not None and since < s["started_at"].date() <= as_of
    ]
    started = [s for s in window if s["started_at"]]
    finished = [s for s in started if s["ended_at"] is not None]

    metrics: dict[str, dict] = {}

    def put(key: str, value, unit: str, sample: int, note: str = ""):
        metrics[key] = {"value": value, "unit": unit, "sample": sample, "note": note}

    # Retensi D1/D7 — kohort pemain yang sudah punya kesempatan kembali.
    seen: dict[str, set[date]] = defaultdict(set)
    for session in sessions:
        if session["started_at"]:
            for player in session["players"]:
                seen[player].add(session["started_at"].date())
    first_seen = {p: min(days) for p, days in seen.items()}
    for label, offset in (("retention_d1", 1), ("retention_d7", 7)):
        cohort = [p for p, first in first_seen.items() if first + timedelta(days=offset) <= as_of]
        returned = [p for p in cohort if first_seen[p] + timedelta(days=offset) in seen[p]]
        value = len(returned) / len(cohort) if cohort else None
        put(label, value, "rasio", len(cohort), f"kohort {offset} hari" if cohort else "")

    # Penyelesaian sesi. PRD §12 berbunyi "% sesi yang menamatkan kasus" tanpa
    # mengecualikan Case 0, jadi angkanya mencakup semua sesi; porsi Case 0
    # dilaporkan terpisah supaya pembacanya bisa menilai sendiri.
    solved = sum(1 for s in started if s["solved"])
    case0_total = sum(1 for s in started if s["is_case0"])
    put(
        "session_completion",
        solved / len(started) if started else None,
        "rasio",
        len(started),
        f"{solved}/{len(started)} sesi tamat, {case0_total} di antaranya Case 0" if started else "",
    )

    # Matchmaking.
    waits = [l["wait_s"] for l in lobbies if "wait_s" in l]
    put(
        "matchmaking_wait_median",
        statistics.median(waits) if waits else None,
        "detik",
        len(waits),
    )
    attempts = len(lobbies)
    failures = sum(1 for l in lobbies if l.get("failed"))
    put(
        "matchmaking_fail_rate",
        failures / attempts if attempts else None,
        "rasio",
        attempts,
        f"{failures}/{attempts} gagal" if attempts else "",
    )

    # Idle time per role — PRD §6: idle = tanpa input bermakna, ambang < 25%.
    # Ambang berlaku per role, jadi angka ringkasnya adalah rasio TERBURUK:
    # satu role di atas 25% sudah berarti gate gagal.
    per_role = {}
    for role in ROLES:
        total_idle = sum(s["idle_s"].get(role, 0.0) for s in finished)
        total_time = sum(s["duration_s"] for s in finished if role in s["roles"] and s["duration_s"])
        per_role[role] = {
            "value": total_idle / total_time if total_time else None,
            "idle_s": round(total_idle, 1),
            "session_s": round(total_time, 1),
        }
    measured = [entry["value"] for entry in per_role.values() if entry["value"] is not None]
    worst = max(measured) if measured else None
    put(
        "idle_time_per_role",
        worst,
        "rasio",
        len(finished),
        "rasio terburuk antar role",
    )
    metrics["idle_time_per_role"]["per_role"] = per_role

    # Case 0.
    case0 = [s for s in started if s["is_case0"]]
    case0_solved = sum(1 for s in case0 if s["solved"])
    put(
        "case0_completion",
        case0_solved / len(case0) if case0 else None,
        "rasio",
        len(case0),
        f"{case0_solved}/{len(case0)}" if case0 else "",
    )

    # Quit di 5 menit pertama, per role (PRD §12: dipantau, bandingkan antar role).
    quit_by_role = {role: 0 for role in ROLES}
    for session in finished:
        if session["duration_s"] is not None and session["duration_s"] < FIRST_5MIN:
            for role in session["roles"]:
                quit_by_role[role] += 1
    put(
        "quit_first_5min_per_role",
        None,
        "jumlah per role",
        len(finished),
        "dipantau, tanpa target",
    )
    metrics["quit_first_5min_per_role"]["per_role"] = quit_by_role

    # Hint.
    hints = sum(s["hints"] for s in started)
    put(
        "hint_per_session",
        hints / len(started) if started else None,
        "hint/sesi",
        len(started),
        f"{hints} hint" if started else "",
    )

    # Konten — PRD §12: "Story case baru, 1 per 1-2 minggu". Dihitung dari
    # event `case_released`, bukan dari jumlah case yang muncul di sesi:
    # case lama yang dimainkan ulang bukan konten baru.
    spec = TARGETS.get("new_story_case", {})
    period = spec.get("period_days") or 14
    in_window = [r for r in releases if since < r["ts"].date() <= as_of]
    # Nol rilis hanya bermakna kalau pipeline telemetrinya memang hidup. Kalau
    # jendela ini tidak punya satu pun event sesi maupun rilis, "0" cuma
    # menandakan sink-nya gelap, bukan kontennya yang tidak rilis.
    live = bool(started) or bool(in_window)
    # Target berbunyi "per 14 hari" sedangkan jendela laporan 7 hari, jadi
    # lajunya disamakan dulu ke periode target sebelum dibandingkan.
    put(
        "new_story_case",
        len(in_window) * period / window_days if live else None,
        "kasus/periode",
        len(in_window),
        f"{len(in_window)} rilis dalam {window_days} hari, disamakan ke {period} hari" if live
        else "tidak ada telemetri di jendela ini",
    )

    return metrics


def verdict(key: str, value) -> str:
    if value is None:
        return "NO DATA"
    spec = TARGETS.get(key)
    if spec is None or spec["direction"] == "track":
        return "TRACK"
    target, direction = spec["target"], spec["direction"]
    if direction == "gte":
        return "PASS" if value >= target else "FAIL"
    if direction == "lte":
        return "PASS" if value <= target else "FAIL"
    if direction == "band":
        low, high = target
        return "PASS" if low <= value <= high else "FAIL"
    return "TRACK"


def fmt(value, unit: str) -> str:
    if value is None:
        return "—"
    if unit == "rasio":
        return f"{value * 100:.1f}%"
    if unit == "detik":
        return f"{value:.1f} dtk"
    if unit in ("hint/sesi", "kasus/periode"):
        return f"{value:.2f}"
    return str(value)


def render(metrics: dict, anomalies: dict, as_of: date, window_days: int, sessions: list[dict]) -> str:
    since = as_of - timedelta(days=window_days)
    rows = [
        ("Retensi", "D1", "retention_d1"),
        ("Retensi", "D7", "retention_d7"),
        ("Penyelesaian", "% sesi yang menamatkan kasus", "session_completion"),
        ("Matchmaking", "Median waktu tunggu", "matchmaking_wait_median"),
        ("Matchmaking", "% sesi gagal start", "matchmaking_fail_rate"),
        ("Pengalaman role", "Idle time per role", "idle_time_per_role"),
        ("Onboarding", "% menamatkan Case 0", "case0_completion"),
        ("Drop-off", "Quit di 5 menit pertama per role", "quit_first_5min_per_role"),
        ("Hint", "Rata-rata hint per sesi", "hint_per_session"),
        ("Konten", "Story case baru", "new_story_case"),
    ]
    lines = [
        f"## Laporan metrik Triangulate — {as_of.isoformat()}",
        "",
        f"Jendela: `{since.isoformat()}` → `{as_of.isoformat()}` ({window_days} hari) · "
        f"sesi dalam jendela: {len(sessions)}",
        "",
        "| Kategori | Metrik | Nilai | Target (PRD §12) | Verdict | Sampel |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for category, label, key in rows:
        item = metrics[key]
        target_text = TARGETS.get(key, {}).get("text", "")
        lines.append(
            f"| {category} | {label} | {fmt(item['value'], item['unit'])} | {target_text} "
            f"| {verdict(key, item['value'])} | {item['sample']} |"
        )

    notes = [(label, metrics[key]["note"]) for _, label, key in rows if metrics[key]["note"]]
    if notes:
        lines += ["", "Catatan:"]
        lines += [f"- {label}: {note}" for label, note in notes]

    idle = metrics["idle_time_per_role"]["per_role"]
    lines += ["", "### Idle time per role (PRD §6)", "", "| Role | Idle | Durasi sesi | Rasio | Verdict |", "| --- | --- | --- | --- | --- |"]
    for role in ROLES:
        entry = idle[role]
        lines.append(
            f"| {role} | {entry['idle_s']} dtk | {entry['session_s']} dtk "
            f"| {fmt(entry['value'], 'rasio')} | {verdict('idle_time_per_role', entry['value'])} |"
        )

    quit_role = metrics["quit_first_5min_per_role"]["per_role"]
    lines += [
        "",
        "### Quit di 5 menit pertama per role",
        "",
        "| Role | Jumlah |",
        "| --- | --- |",
    ]
    for role in ROLES:
        lines.append(f"| {role} | {quit_role[role]} |")

    lines += ["", "### Kualitas data", ""]
    if anomalies["unknown_events"]:
        lines.append("- Event tak dikenal (tidak dihitung): " + ", ".join(
            f"`{k}` × {v}" for k, v in anomalies["unknown_events"].items()))
    else:
        lines.append("- Event tak dikenal: tidak ada")
    lines.append(f"- Sesi tanpa `session_start`: {anomalies['sessions_without_start']}")
    lines.append(f"- Sesi tanpa `session_end`: {anomalies['sessions_without_end']}")
    lines.append(f"- Sesi tanpa role: {anomalies['sessions_without_role']}")
    lines.append(f"- Percobaan lobby: {anomalies['lobby_attempts']}")

    no_data = [k for k, v in metrics.items() if v["value"] is None and k != "quit_first_5min_per_role"]
    if no_data:
        lines += ["", "Metrik tanpa data: " + ", ".join(f"`{k}`" for k in no_data) + "."]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--events", help="NDJSON event mentah")
    source.add_argument("--summaries", help="NDJSON ringkasan sesi (keluaran --emit-summaries)")
    parser.add_argument("--emit-summaries", help="tulis ringkasan sesi ke path ini")
    parser.add_argument("--as-of", help="tanggal akhir jendela (YYYY-MM-DD), default hari ini UTC")
    parser.add_argument("--window-days", type=int, default=7)
    parser.add_argument("--json", action="store_true", help="keluarkan metrik sebagai JSON")
    args = parser.parse_args(argv)

    as_of = date.fromisoformat(args.as_of) if args.as_of else datetime.now(timezone.utc).date()

    if args.events:
        dataset = reduce_events(load_ndjson(args.events))
    else:
        dataset = load_summaries(args.summaries)

    if args.emit_summaries:
        with open(args.emit_summaries, "w", encoding="utf-8") as handle:
            handle.write(dumps_summaries(dataset))

    metrics = compute(dataset, as_of, args.window_days)
    anomalies = dataset["anomalies"]
    sessions = dataset["sessions"]
    if args.json:
        print(json.dumps({"as_of": as_of.isoformat(), "metrics": metrics, "anomalies": anomalies},
                         indent=2, ensure_ascii=False, default=str))
    else:
        sys.stdout.write(render(metrics, anomalies, as_of, args.window_days, sessions))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
