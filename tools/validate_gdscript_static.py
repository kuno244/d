#!/usr/bin/env python3
"""Static structure checks for a Godot project when the Godot parser is unavailable.

This deliberately does NOT claim to compile GDScript. It catches project-reference,
class/function duplication, delimiter/string, and forbidden shipping-reference errors.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

CLASS_RE = re.compile(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)\s*$", re.M)
FUNC_RE = re.compile(r"^\s*func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", re.M)
RES_QUOTED_RE = re.compile(r"[\"'](res://[^\"']+)[\"']")
FORBIDDEN = ("assets/source/", "assets/processed/", "Meshy_AI_model")


def _strip_strings_comments(text: str) -> tuple[str, list[str]]:
    out: list[str] = []
    errors: list[str] = []
    quote: str | None = None
    escaped = False
    in_comment = False
    line = 1
    quote_line = 0
    i = 0
    while i < len(text):
        ch = text[i]
        if ch == "\n":
            line += 1
            in_comment = False
            if quote is None:
                out.append(ch)
            else:
                # Normal GDScript string literals cannot silently span a newline.
                errors.append(f"unterminated string started at line {quote_line}")
                quote = None
                escaped = False
                out.append(ch)
            i += 1
            continue
        if in_comment:
            out.append(" ")
            i += 1
            continue
        if quote is not None:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                quote = None
            out.append(" ")
            i += 1
            continue
        if ch == "#":
            in_comment = True
            out.append(" ")
        elif ch in ('"', "'"):
            quote = ch
            quote_line = line
            out.append(" ")
        else:
            out.append(ch)
        i += 1
    if quote is not None:
        errors.append(f"unterminated string started at line {quote_line}")
    return "".join(out), errors


def _delimiter_errors(text: str) -> list[str]:
    clean, errors = _strip_strings_comments(text)
    stack: list[tuple[str, int]] = []
    pairs = {")": "(", "]": "[", "}": "{"}
    opens = set(pairs.values())
    line = 1
    for ch in clean:
        if ch == "\n":
            line += 1
            continue
        if ch in opens:
            stack.append((ch, line))
        elif ch in pairs:
            if not stack or stack[-1][0] != pairs[ch]:
                errors.append(f"unmatched {ch} at line {line}")
            else:
                stack.pop()
    for ch, at in stack:
        errors.append(f"unclosed {ch} from line {at}")
    return errors


def _resolve_res(root: Path, ref: str) -> bool:
    if "%" in ref or "{" in ref:
        return True  # dynamic path, validated by runtime registry contracts instead
    rel = ref[len("res://"):]
    return (root / rel).exists()


def validate(root: Path | str) -> dict[str, Any]:
    root = Path(root)
    errors: list[str] = []
    warnings: list[str] = []
    gd_files = sorted((root / "scripts").rglob("*.gd"))
    scene_files = sorted((root / "scenes").rglob("*.tscn"))

    classes: dict[str, Path] = {}
    duplicate_classes = 0
    duplicate_functions = 0
    missing_paths: list[str] = []
    forbidden_hits: list[str] = []

    for path in gd_files:
        text = path.read_text(encoding="utf-8")
        for problem in _delimiter_errors(text):
            errors.append(f"{path.relative_to(root)}: {problem}")
        for class_name in CLASS_RE.findall(text):
            if class_name in classes:
                duplicate_classes += 1
                errors.append(
                    f"duplicate class_name {class_name}: {classes[class_name].relative_to(root)} and {path.relative_to(root)}"
                )
            else:
                classes[class_name] = path
        funcs = FUNC_RE.findall(text)
        seen_funcs: set[str] = set()
        for func_name in funcs:
            if func_name in seen_funcs:
                duplicate_functions += 1
                errors.append(f"{path.relative_to(root)}: duplicate function {func_name}")
            seen_funcs.add(func_name)

    reference_files = gd_files + scene_files + [root / "project.godot"]
    for path in reference_files:
        if not path.exists():
            errors.append(f"missing project file: {path.relative_to(root)}")
            continue
        text = path.read_text(encoding="utf-8")
        for ref in RES_QUOTED_RE.findall(text):
            if not _resolve_res(root, ref):
                item = f"{path.relative_to(root)} -> {ref}"
                if item not in missing_paths:
                    missing_paths.append(item)
        if path == root / "project.godot" or "scripts" in path.parts or "scenes" in path.parts:
            for token in FORBIDDEN:
                if token in text:
                    forbidden_hits.append(f"{path.relative_to(root)}: {token}")

    if missing_paths:
        errors.extend("missing res:// reference: " + item for item in missing_paths)
    if forbidden_hits:
        errors.extend("forbidden runtime reference: " + item for item in forbidden_hits)

    # Semicolon-packed statements are legal in GDScript, but ordinary multi-line code is easier to audit.
    semicolon_lines = 0
    for path in gd_files:
        for line in path.read_text(encoding="utf-8").splitlines():
            if ";" in line and not line.lstrip().startswith("#"):
                semicolon_lines += 1
    if semicolon_lines:
        warnings.append(f"{semicolon_lines} GDScript lines contain semicolon-separated statements")

    return {
        "passed": not errors,
        "errors": errors,
        "warnings": warnings,
        "gdscript_files": len(gd_files),
        "scene_files": len(scene_files),
        "class_names": len(classes),
        "duplicate_class_names": duplicate_classes,
        "duplicate_functions": duplicate_functions,
        "missing_res_paths": len(missing_paths),
        "forbidden_runtime_refs": len(forbidden_hits),
        "semicolon_statement_lines": semicolon_lines,
    }


def main(argv: list[str]) -> int:
    root = Path(argv[1]) if len(argv) > 1 else Path(__file__).resolve().parents[1]
    result = validate(root)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
