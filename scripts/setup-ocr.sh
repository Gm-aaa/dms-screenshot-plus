#!/usr/bin/env bash
# Set up the RapidOCR backend in a self-contained virtualenv.
#
#   ./scripts/setup-ocr.sh
#
# Creates a venv at $DSP_OCR_VENV (default ~/.local/share/rapidocr-venv) and
# installs rapidocr-onnxruntime. The OCR models (PP-OCRv3 det/cls/rec, ~14 MB)
# ship *inside* the pip wheel — there is nothing else to download.
#
# dms-screenshot-plus auto-detects this venv, so no extra configuration is
# needed afterwards.
set -euo pipefail

VENV="${DSP_OCR_VENV:-$HOME/.local/share/rapidocr-venv}"
PYTHON="${PYTHON:-python3}"

command -v "$PYTHON" >/dev/null || { echo "error: $PYTHON not found" >&2; exit 1; }

if [[ ! -d "$VENV" ]]; then
    echo "Creating venv: $VENV"
    "$PYTHON" -m venv "$VENV"
fi

echo "Installing rapidocr-onnxruntime (CPU, models bundled) ..."
"$VENV/bin/pip" install --upgrade pip >/dev/null
"$VENV/bin/pip" install --upgrade rapidocr-onnxruntime

echo
echo "Verifying ..."
"$VENV/bin/python" - <<'PY'
import rapidocr_onnxruntime, os, glob
base = os.path.join(os.path.dirname(rapidocr_onnxruntime.__file__), "models")
print("rapidocr-onnxruntime", rapidocr_onnxruntime.__version__ if hasattr(rapidocr_onnxruntime, "__version__") else "")
for m in sorted(glob.glob(base + "/*.onnx")):
    print("  model:", os.path.basename(m), f"({os.path.getsize(m)//1024} KB)")
print("OK — RapidOCR ready.")
PY

echo
echo "Done. dms-screenshot-plus will auto-detect: $VENV/bin/python"
echo "Verify with: dms-screenshot-plus --print-config | grep OCR"
