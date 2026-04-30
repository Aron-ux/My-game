#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ACHIEVEMENTS_PATH = ROOT / "data" / "achievements.json"
REQUIRED_FIELDS = {"id", "title", "description", "hidden", "goal", "steam_api_name"}


def main() -> int:
    failures: list[str] = []
    try:
        data = json.loads(ACHIEVEMENTS_PATH.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"ACHIEVEMENT_CHECK_FAILED\nCannot parse {ACHIEVEMENTS_PATH}: {exc}")
        return 1

    achievements = data.get("achievements")
    if not isinstance(achievements, list) or not achievements:
        failures.append("achievements must be a non-empty list")
        achievements = []

    seen: set[str] = set()
    for index, row in enumerate(achievements):
        label = f"achievements[{index}]"
        if not isinstance(row, dict):
            failures.append(f"{label} must be an object")
            continue
        missing = sorted(REQUIRED_FIELDS - set(row))
        if missing:
            failures.append(f"{label} missing fields: {', '.join(missing)}")
        achievement_id = str(row.get("id", "")).strip()
        if not achievement_id:
            failures.append(f"{label}.id is empty")
        elif achievement_id in seen:
            failures.append(f"duplicate achievement id: {achievement_id}")
        else:
            seen.add(achievement_id)
        if achievement_id and not achievement_id.startswith("ACH_"):
            failures.append(f"{achievement_id}: id should start with ACH_ for Steam API compatibility")
        steam_api_name = str(row.get("steam_api_name", "")).strip()
        if achievement_id and steam_api_name != achievement_id:
            failures.append(f"{achievement_id}: steam_api_name should match id unless migration is documented")
        try:
            goal = int(row.get("goal", 0))
        except Exception:
            goal = 0
        if goal < 1:
            failures.append(f"{achievement_id or label}: goal must be >= 1")
        if not isinstance(row.get("hidden"), bool):
            failures.append(f"{achievement_id or label}: hidden must be a boolean")
        for field in ["title", "description"]:
            if str(row.get(field, "")).strip() == "":
                failures.append(f"{achievement_id or label}: {field} is empty")

    if failures:
        print("ACHIEVEMENT_CHECK_FAILED")
        print("\n".join(failures))
        return 1
    print(f"ACHIEVEMENT_CHECK_OK {len(achievements)} achievements")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
