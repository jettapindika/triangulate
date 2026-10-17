#!/usr/bin/env python3
"""Validator sekali pakai untuk data kasus Triangulate.

Memeriksa graf, gerbang, dan varian terhadap aturan PRD v0.2 bagian 4, 5, 10.
Jalankan: python3 tools/validate_cases.py
"""

import json
import re
import sys
from pathlib import Path

CASES = Path(__file__).resolve().parent.parent / "cases"
FIELDS = {"pelaku", "motif", "cara"}

errors: list[str] = []
notes: list[str] = []


def fail(case: str, msg: str) -> None:
    errors.append(f"[{case}] {msg}")


def note(msg: str) -> None:
    notes.append(msg)


def validate_graph(case: str, data: dict) -> dict:
    nodes = data["nodes"]
    by_id: dict[str, dict] = {}
    for n in nodes:
        if n["id"] in by_id:
            fail(case, f"id node duplikat: {n['id']}")
        by_id[n["id"]] = n

    # needs pada evidence menunjuk KEY, bukan id node
    key_owner = {n["gives_key"]: n["id"] for n in nodes if n["type"] == "object"}
    for n in nodes:
        for k in n.get("needs", []):
            if n["type"] == "evidence" and k not in key_owner:
                fail(case, f"{n['id']} butuh kunci yang tidak diproduksi objek: {k}")

    evidence = [n for n in nodes if n["type"] == "evidence"]
    clues = [n for n in nodes if n["type"] == "clue"]
    deductions = [n for n in nodes if n["type"] == "deduction"]

    for c in clues:
        src = by_id.get(c["from"])
        if src is None or src["type"] != "evidence":
            fail(case, f"{c['id']} from bukan evidence: {c['from']}")

    # tiap bukti harus menghasilkan tepat satu clue
    for e in evidence:
        if e.get("yields") not in by_id:
            fail(case, f"{e['id']} yields node tidak ada: {e.get('yields')}")
        elif by_id[e["yields"]].get("from") != e["id"]:
            fail(case, f"{e['id']} dan {e.get('yields')} tidak saling merujuk")

    # edge list untuk deteksi siklus: consumer -> producer
    edges: dict[str, list[str]] = {}
    for n in nodes:
        deps = []
        for d in n.get("needs", []):
            target = key_owner.get(d, d)
            deps.append(target)
            if target not in by_id:
                fail(case, f"{n['id']} butuh node yang tidak ada: {d}")
        if n["type"] == "clue" and n.get("from") in by_id:
            deps.append(n["from"])
        edges[n["id"]] = deps

    state: dict[str, int] = {}

    def dfs(nid: str, stack: list[str]) -> None:
        state[nid] = 1
        for dep in edges.get(nid, []):
            if state.get(dep) == 1:
                fail(case, f"siklus: {' -> '.join(stack + [nid, dep])}")
                return
            if state.get(dep, 0) == 0:
                dfs(dep, stack + [nid])
        state[nid] = 2

    for n in nodes:
        if state.get(n["id"], 0) == 0:
            dfs(n["id"], [])

    # rantai: objek -> bukti -> clue, dan clue harus dipakai deduksi
    chains = sorted({n.get("chain") for n in nodes if n.get("chain")})
    used_clues = {d for ded in deductions for d in ded.get("needs", [])}
    for ch in chains:
        types = {n["type"] for n in nodes if n.get("chain") == ch}
        if not {"object", "evidence", "clue"} <= types:
            fail(case, f"rantai {ch} tidak lengkap: {sorted(types)}")
    for c in clues:
        if c["id"] not in used_clues:
            fail(case, f"{c['id']} tidak dipakai deduksi mana pun (rantai buntu)")

    # tiap rantai harus menopang minimal satu deduksi
    chain_deds = {d.get("chain") for d in deductions}
    for ch in chains:
        if ch not in chain_deds:
            fail(case, f"rantai {ch} tidak menopang deduksi apa pun")

    return {
        "by_id": by_id,
        "deductions": deductions,
        "clues": clues,
        "evidence": evidence,
        "chains": chains,
        "key_owner": key_owner,
    }


def validate_gate(case: str, data: dict, graph: dict) -> None:
    gate = data["gate"]
    deductions = graph["deductions"]
    key_deds = [d for d in deductions if d.get("key")]

    if len(deductions) != gate["total_deductions"]:
        fail(case, f"total_deductions={gate['total_deductions']} tapi node deduksi={len(deductions)}")
    if len(key_deds) != gate["key_deductions_required"]:
        fail(
            case,
            f"key_deductions_required={gate['key_deductions_required']} tapi deduksi ber-flag key={len(key_deds)}",
        )

    # PRD bagian 5: tiap field tuduhan harus ditopang minimal satu rantai
    field_chain: dict[str, set] = {f: set() for f in FIELDS}
    field_key: dict[str, bool] = {f: False for f in FIELDS}
    for d in deductions:
        f = d.get("field")
        if f not in FIELDS:
            fail(case, f"{d['id']} field tidak dikenal: {f}")
            continue
        field_chain[f].add(d.get("chain"))
        if d.get("key"):
            field_key[f] = True
    for f in sorted(FIELDS):
        if not field_chain[f]:
            fail(case, f"field tuduhan '{f}' tidak ditopang deduksi mana pun")
        elif not field_key[f]:
            if gate.get("form_requires_fields") == sorted(FIELDS):
                fail(case, f"field '{f}' hanya ditopang deduksi non-kunci, sedangkan form menuntut semua field")
            note(
                f"{case}: field '{f}' hanya punya deduksi non-kunci "
                f"(rantai {sorted(field_chain[f])}); gerbang tetap N={gate['key_deductions_required']}"
            )

    # setiap rantai harus menopang deduksi; Deduksi Kunci harus tersebar di
    # rantai berbeda sebanyak yang dimungkinkan N (PRD bagian 5)
    chain_key = {d.get("chain") for d in key_deds}
    need_distinct = min(len(graph["chains"]), gate["key_deductions_required"])
    if len(chain_key) < need_distinct:
        fail(
            case,
            f"Deduksi Kunci hanya tersebar di {len(chain_key)} rantai, "
            f"seharusnya minimal {need_distinct} dari {len(graph['chains'])} rantai",
        )
    for ch in graph["chains"]:
        if ch not in chain_key:
            note(
                f"{case}: rantai {ch} tanpa Deduksi Kunci "
                f"(N={gate['key_deductions_required']} dari {gate['total_deductions']}); "
                "deduksi rantai ini jadi bonus rank"
            )

    # PRD bagian 5: tiap rantai menopang satu field tuduhan, tidak campur
    chain_field: dict[str, set] = {}
    for d in deductions:
        chain_field.setdefault(d.get("chain"), set()).add(d.get("field"))
    for ch, fields in sorted(chain_field.items()):
        if len(fields) > 1:
            fail(case, f"rantai {ch} menopang lebih dari satu field: {sorted(fields)}")


def validate_statements(case: str, statements: list, contradictions: list, graph: dict, gate: dict) -> None:
    required = [c for c in contradictions if c.get("required")]
    if len(required) < gate["min_contradictions"]:
        fail(case, f"kontradiksi wajib={len(required)} kurang dari min_contradictions={gate['min_contradictions']}")

    by_stmt = {s["id"]: s for s in statements}
    clue_ids = {c["id"] for c in graph["clues"]}
    for c in contradictions:
        st = by_stmt.get(c["statement"])
        if st is None:
            fail(case, f"{c['id']} menunjuk pernyataan tidak ada: {c['statement']}")
            continue
        if not st.get("lie"):
            fail(case, f"{c['id']} menandai kontradiksi pada pernyataan yang tidak bohong: {st['id']}")
        if st.get("contradicted_by") != c["contradicted_by"]:
            fail(case, f"{c['id']} contradicted_by tidak sama dengan pernyataan {st['id']}")
        if c["contradicted_by"] not in clue_ids:
            fail(case, f"{c['id']} contradicted_by bukan clue: {c['contradicted_by']}")

    if not any(s.get("lie") for s in statements):
        fail(case, "tidak ada pernyataan saksi yang bohong")
    for s in statements:
        if s.get("lie") and not s.get("contradicted_by"):
            fail(case, f"{s['id']} bohong tapi tanpa contradicted_by")


def validate_solution(case: str, solution: dict) -> None:
    for f in sorted(FIELDS):
        if not solution.get(f):
            fail(case, f"solusi tidak mengisi field {f}")


def shared_payload_text(data: dict) -> str:
    """Teks yang dibaca pemain dari aset bersama (bukan deklarasi varian)."""
    blob = {
        "nodes": data.get("nodes"),
        "shared_clue_text": data.get("shared_clue_text"),
        "puzzle_content": data.get("puzzle_content"),
        "briefings": data.get("briefings"),
    }
    return json.dumps(blob, ensure_ascii=False).lower()


def main() -> int:
    files = sorted(CASES.glob("*.json"))
    if not files:
        print("tidak ada file kasus", file=sys.stderr)
        return 1

    for path in files:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            fail(path.name, f"JSON tidak valid: {exc}")
            continue

        case = data.get("case_id", path.name)
        graph = validate_graph(case, data)
        validate_gate(case, data, graph)

        if "variant_content" in data:
            seen = set()
            for v in data["variant_content"]:
                vid = v["id"]
                seen.add(vid)
                vcase = f"{case}:{vid}"
                validate_statements(vcase, v["statements"], v["contradictions"], graph, data["gate"])
                validate_solution(vcase, v["solution"])
                for d in graph["deductions"]:
                    if d["id"] not in v.get("deduction_text", {}):
                        fail(vcase, f"teks deduksi hilang: {d['id']}")
                for cid in ("clue_c1", "clue_c2"):
                    if cid not in v.get("clue_text", {}):
                        fail(vcase, f"teks clue hilang: {cid}")

            declared = {v["id"] for v in data.get("variants", [])}
            if declared != seen:
                fail(case, f"variants {sorted(declared)} != variant_content {sorted(seen)}")

            culprits = [v["culprit"] for v in data["variants"]]
            motives = [v["motive"] for v in data["variants"]]
            if len(set(culprits)) != len(culprits):
                fail(case, "pelaku antar varian sama")
            if len(set(motives)) != len(motives):
                fail(case, "motif antar varian sama")

            by_id = {v["id"]: v for v in data["variant_content"]}
            for v in data["variants"]:
                sol = by_id[v["id"]]["solution"]
                if not re.search(rf"\b{v['culprit']}\b", sol["pelaku"], re.IGNORECASE):
                    fail(f"{case}:{v['id']}", f"pelaku solusi '{sol['pelaku']}' tidak cocok varian '{v['culprit']}'")
                note(f"{case}:{v['id']} pelaku={sol['pelaku']} motif={v['motive']}")

            # aset bersama tidak boleh membocorkan payload varian. Nama pelaku
            # boleh muncul di aset bersama hanya bila semua kandidat pelaku
            # disebut (mis. log akses), supaya tidak mendisambiguasi varian.
            blob = shared_payload_text(data)
            culprits = {v["culprit"].lower() for v in data["variants"]}
            present = {c for c in culprits if re.search(rf"\b{re.escape(c)}\b", blob)}
            if present and present != culprits:
                fail(
                    case,
                    f"aset bersama menyebut sebagian kandidat pelaku {sorted(present)} "
                    f"dari {sorted(culprits)} (mendisambiguasi varian)",
                )
            for v in data["variants"]:
                if re.search(rf"\b{re.escape(v['motive'].lower())}\b", blob):
                    fail(case, f"aset bersama menyebut motif varian '{v['motive']}' (bocor antar varian)")
        else:
            validate_statements(case, data["statements"], data["contradictions"], graph, data["gate"])
            validate_solution(case, data["solution"])

    for n in notes:
        print(f"  ok  {n}")
    if errors:
        print("\nGAGAL:", file=sys.stderr)
        for e in errors:
            print(f"  {e}", file=sys.stderr)
        return 1
    print(f"\nLOLOS: {len(files)} file kasus valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
