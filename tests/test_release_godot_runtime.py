import os
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GODOT_BIN = os.environ.get("GODOT_BIN") or shutil.which("godot4") or shutil.which("godot")
assert GODOT_BIN, "GODOT_BIN is required for the release runtime integration gate"
result = subprocess.run(
    [GODOT_BIN, "--headless", "--path", str(ROOT), "--quit-after", "45", "tests/ReleaseRuntimeSmoke.tscn"],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    timeout=120,
    check=False,
)
output = result.stdout
assert result.returncode == 0, output
assert "RELEASE_RUNTIME_SMOKE_PASS" in output, output
assert "SCRIPT ERROR:" not in output, output
assert "ERROR:" not in output, output
print("PASS release Godot runtime integration")
