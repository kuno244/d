from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageStat


def validate(path: Path) -> dict:
    image = Image.open(path).convert("RGB")
    width, height = image.size
    crop = image.crop((int(width * 0.18), int(height * 0.16), int(width * 0.82), int(height * 0.84)))
    preview = crop.resize((320, 180))
    pixels = list(preview.getdata())
    luminance = [(r * 0.2126 + g * 0.7152 + b * 0.0722) for r, g, b in pixels]
    mean_luminance = sum(luminance) / max(1, len(luminance))
    dark_ratio = sum(value < 22 for value in luminance) / max(1, len(luminance))
    quantized_colors = len({(r // 16, g // 16, b // 16) for r, g, b in pixels})
    channel_mean = ImageStat.Stat(preview).mean
    errors = []
    if width < 960 or height < 540: errors.append("capture resolution is too small")
    if mean_luminance < 58.0: errors.append("world center is too dark")
    if dark_ratio > 0.48: errors.append("world center is predominantly black")
    if quantized_colors < 35: errors.append("world center lacks visual color variation")
    return {
        "passed": not errors,
        "errors": errors,
        "width": width,
        "height": height,
        "mean_luminance": round(mean_luminance, 2),
        "dark_ratio": round(dark_ratio, 4),
        "quantized_colors": quantized_colors,
        "mean_rgb": [round(value, 2) for value in channel_mean],
    }


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: check_world_screenshot.py SCREENSHOT.png")
    result = validate(Path(sys.argv[1]))
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result["passed"] else 1)
