import os
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GODOT_BIN = os.environ.get("GODOT_BIN") or shutil.which("godot4") or shutil.which("godot")

assert GODOT_BIN, "GODOT_BIN must point to a Godot 4 executable for the runtime gate"
result = subprocess.run(
    [GODOT_BIN, "--headless", "--path", str(ROOT), "--quit-after", "8"],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    timeout=90,
    check=False,
)
output = result.stdout
assert result.returncode == 0, output
assert "ERROR:" not in output, output
assert "SCRIPT ERROR:" not in output, output
print("PASS Godot Boot -> MainMenu runtime")
