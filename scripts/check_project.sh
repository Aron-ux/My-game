#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT_BIN="${GODOT_BIN:-}"
if [[ -z "$GODOT_BIN" ]]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
  elif [[ -x "/home/weathour/.local/bin/godot-4.6.2" ]]; then
    GODOT_BIN="/home/weathour/.local/bin/godot-4.6.2"
  else
    GODOT_BIN=""
  fi
fi

echo "== Python project checks =="
python3 scripts/tests/check_docs_links.py
python3 scripts/tests/check_achievements.py
python3 scripts/tests/check_project_config.py
python3 scripts/tests/check_architecture_contract.py

if [[ -n "$GODOT_BIN" ]]; then
  echo "== Godot headless parse =="
  "$GODOT_BIN" --headless --path . --quit --verbose 2>&1 | tee /tmp/my-game-godot-check.log >/dev/null
  if grep -E "SCRIPT ERROR|Parse Error|Invalid call|Failed to load script|Failed to instantiate" /tmp/my-game-godot-check.log; then
    echo "GODOT_PARSE_CHECK_FAILED"
    exit 1
  fi
  echo "GODOT_PARSE_CHECK_OK"

  echo "== Godot main scene smoke =="
  "$GODOT_BIN" --headless --path . res://scenes/main.tscn --quit --verbose 2>&1 | tee /tmp/my-game-main-scene-smoke.log >/dev/null
  if grep -E "SCRIPT ERROR|Parser Error|Invalid call|Failed to load script|Compilation failed" /tmp/my-game-main-scene-smoke.log; then
    echo "MAIN_SCENE_SMOKE_FAILED"
    exit 1
  fi
  echo "MAIN_SCENE_SMOKE_OK"

  run_smoke() {
    local script="$1"
    local name
    local log
    name="$(basename "${script%.gd}")"
    log="/tmp/my-game-${name//_/-}.log"
    echo "== Godot ${name//_/ } =="
    if ! "$GODOT_BIN" --headless --path . --script "$script" 2>&1 | tee "$log"; then
      echo "${name^^}_FAILED"
      exit 1
    fi
    if grep -E "SCRIPT ERROR|Parser Error|Invalid call|Failed to load script|Compilation failed|^ERROR:" "$log"; then
      echo "${name^^}_FAILED"
      exit 1
    fi
    if ! grep -Eq "(_OK|: (OK|PASS))$" "$log"; then
      echo "${name^^}_MISSING_SUCCESS_MARKER"
      exit 1
    fi
  }

  for smoke in scripts/tests/*_smoke.gd; do
    # The dense benchmark is deliberately separate because it compares two
    # timed cases and writes result artifacts.
    [[ "$(basename "$smoke")" == "dense_combat_benchmark_smoke.gd" ]] && continue
    run_smoke "$smoke"
  done

else
  echo "== Godot checks skipped: set GODOT_BIN or install godot =="
fi

if command -v graphify >/dev/null 2>&1; then
  echo "== graphify update =="
  graphify update .
else
  echo "== graphify skipped: command not found =="
fi

echo "PROJECT_CHECK_OK"
