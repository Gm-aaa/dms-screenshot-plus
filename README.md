# dms-screenshot-plus

A polished, **menu-driven Wayland screenshot toolkit** for tiling compositors
(niri / Hyprland / Sway / wlroots). One launcher, four capture modes, and a
single notification that lets you decide what to do with each shot.

> Built to pair with [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
> and a `fuzzel`-style menu workflow, but it has **zero hard dependency** on any
> shell — it works with any `dmenu`-compatible launcher.

<p align="center"><em>Region · Fullscreen · OCR · Scrolling — from one keybind.</em></p>

## Features

- **Four modes from one menu** — region select, fullscreen/per-output,
  OCR-to-clipboard, and stitched scrolling capture.
- **RAM-first** — every capture lands in `tmpfs` and never touches disk until
  you ask it to. Nothing leaks to `~/Pictures` unless you pick *Save*.
- **One capture, six choices** — each shot raises a notification with:
  *copy path · copy image · save to disk · open folder · annotate · pin on top*.
  If you ignore it, the file path is already on your clipboard — and if no
  clipboard tool is installed, the shot is saved to disk automatically.
- **Frozen-screen selection** — the screen is frozen (via `hyprpicker`) while you
  drag a region, so fast-moving content stays put.
- **Pluggable OCR** — auto-detects [RapidOCR](https://github.com/RapidAI/RapidOCR)
  or `tesseract`, or plug in any command via `DSP_OCR_CMD`.
- **Compositor-agnostic** — output enumeration works on niri, Hyprland, Sway and
  generic wlroots (`wlr-randr`).
- **Set your shortcut from the menu** — *Settings → Keybinding* detects your
  compositor and writes a `Mod+F1` bind into its config (backing it up first),
  or just copies the snippet.
- **Self-check** — `dms-screenshot-plus doctor` reports what's installed and what
  each tool unlocks.
- **Bilingual UI** — Chinese / English, auto-selected from your locale.
- **Zero hardcoded paths** — everything is XDG-based, with a config file and
  environment-variable overrides.

## Requirements

This is a pure-Bash tool — no compilation, no runtime besides the binaries it
shells out to. Only the **core** set is mandatory; everything else unlocks one
specific feature and degrades gracefully when absent (the mode tells you what it
needs instead of crashing).

> **Tip:** run `dms-screenshot-plus doctor` to see, at a glance, which tools are
> present (✓/✗) and what each one unlocks.

### Core (required)

`bash` (≥ 4), `grim`, `slurp`, `wl-clipboard` (`wl-copy`), `libnotify`
(`notify-send`), and **one** menu backend — `fuzzel` (recommended), `wofi`,
`rofi` or `bemenu`. When launched from a real terminal it falls back to `fzf`
or a numbered prompt.

### Optional (per feature)

| Feature             | Needs                                                              |
| ------------------- | ----------------------------------------------------------------- |
| Frozen selection    | `hyprpicker`                                                      |
| Shutter sound       | `pw-play` / `paplay` / `ffplay` / `aplay` (first one found)        |
| Multi-output picker | `jq` + your compositor's CLI (`niri` / `hyprctl` / `swaymsg`)      |
| **OCR**             | A RapidOCR venv **or** `tesseract` — see [OCR backends & models](#ocr-backends--models) |
| Scrolling capture   | [`wayscrollshot`](https://github.com/ChrisCDeloye/wayscrollshot) (configurable via `DSP_SCROLL_CMD`) |
| Annotate            | `satty` (configurable via `DSP_EDITOR_CMD`)                       |
| Pin on top          | `imv` (configurable via `DSP_IMAGE_VIEWER`)                       |
| Reveal in folder    | A file manager exposing the freedesktop `FileManager1` D-Bus API  |

### Install dependencies

**Arch Linux**

```sh
# core
sudo pacman -S grim slurp wl-clipboard libnotify fuzzel
# optional goodies
sudo pacman -S hyprpicker pipewire jq satty imv
# OCR via tesseract (alternative to RapidOCR; install the language data you need)
sudo pacman -S tesseract tesseract-data-eng tesseract-data-chi_sim
```

**Debian / Ubuntu**

```sh
sudo apt install grim slurp wl-clipboard libnotify-bin fuzzel \
                 hyprpicker pipewire-bin jq imv
# tesseract OCR (optional)
sudo apt install tesseract-ocr tesseract-ocr-eng tesseract-ocr-chi-sim
```

`satty` and `wayscrollshot` are not in every distro's repos — grab them from
their upstream releases or the AUR (`satty`, `wayscrollshot`).

## Install

```sh
git clone https://github.com/Gm-aaa/dms-screenshot-plus
cd dms-screenshot-plus
./install.sh            # symlinks bin/dms-screenshot-plus into ~/.local/bin
```

`install.sh` creates a **symlink** (not a copy), so `git pull` updates the
installed command in place. Override the location with `PREFIX=~/bin ./install.sh`,
and uninstall with `./install.sh uninstall`.

> Make sure your install prefix (default `~/.local/bin`) is on the `PATH` seen by
> your compositor — for niri/Sway that's the systemd user environment. The
> installer warns you if it isn't.

Then bind a key.

**The easy way — from inside the app.** Launch it once (e.g. `dms-screenshot-plus`
from a terminal), open *Settings → Keybinding*, and it will detect your
compositor and offer to write a `Mod+F1` bind into its config for you — backing
the file up to `<config>.bak` first, and reloading where needed (niri hot-reloads
on its own). Prefer to do it yourself? It can just copy the snippet instead. Use
the manual route below if you want a different key or a bind straight to one mode.

**niri** (`~/.config/niri/.../binds.kdl`):

```kdl
Mod+F1 hotkey-overlay-title="截图菜单 Screenshot menu" { spawn "dms-screenshot-plus"; }
```

**Hyprland** (`hyprland.conf`):

```ini
bind = SUPER, F1, exec, dms-screenshot-plus
```

You can also bind modes directly, skipping the menu:

```kdl
F1            { spawn "dms-screenshot-plus" "region"; }
Mod+Shift+F1  { spawn "dms-screenshot-plus" "scroll"; }
```

## Usage

```text
dms-screenshot-plus [menu|region|fullscreen|ocr|scroll|settings|doctor]

  menu                 Show the picker (default)
  region               Select a region and capture
  fullscreen | full    Capture an output (or all outputs)
  ocr                  Select a region and OCR it to the clipboard
  scroll               Scrolling / long screenshot
  settings             Open the settings menu (UI language, keybinding)
  doctor               Check dependencies and what each one unlocks

  -h, --help           Show help
  -v, --version        Show version
      --print-config   Show the effective configuration
```

## Configuration

All settings live in `DSP_*` variables. Set them in
`~/.config/dms-screenshot-plus/config` (sourced as shell) or export them in the
environment. Copy [`config.example`](./config.example) to get started:

```sh
mkdir -p ~/.config/dms-screenshot-plus
cp config.example ~/.config/dms-screenshot-plus/config
```

| Variable             | Default                                   | Purpose                                  |
| -------------------- | ----------------------------------------- | ---------------------------------------- |
| `DSP_SAVE_DIR`       | `<Pictures>/Screenshots`                  | Where *Save to disk* writes              |
| `DSP_MEM_DIR`        | `$XDG_RUNTIME_DIR/dms-screenshot-plus`    | In-RAM staging dir                       |
| `DSP_LANG`           | `auto`                                    | UI language `auto` / `zh` / `en` (also switchable in the **Settings** menu, which persists it here) |
| `DSP_MENU_BACKEND`   | `auto`                                    | `fuzzel`/`wofi`/`rofi`/`bemenu`/`fzf`/`term` |
| `DSP_FREEZE`         | `yes`                                     | Freeze screen during region select       |
| `DSP_PLAY_SOUND`     | `yes`                                     | Shutter sound                            |
| `DSP_SHUTTER_SOUND`  | freedesktop `camera-shutter.oga`          | Sound file                               |
| `DSP_EDITOR_CMD`     | `satty`                                   | Annotation editor                        |
| `DSP_IMAGE_VIEWER`   | `imv`                                     | Viewer used to pin a shot                |
| `DSP_FILENAME_FMT`   | `%Y-%m-%d_%H-%M-%S`                        | `date(1)` filename format                |
| `DSP_OCR_BACKEND`    | `auto`                                    | `auto`/`rapidocr`/`tesseract`/`custom`   |
| `DSP_OCR_PYTHON`     | *(auto-detected)*                         | Python that can import RapidOCR          |
| `DSP_OCR_TESS_LANGS` | `chi_sim+eng`                             | tesseract `-l` value                     |
| `DSP_OCR_CMD`        | *(empty)*                                 | Custom OCR command (image path appended) |
| `DSP_OCR_DET_MODEL`  | *(bundled)*                               | Custom RapidOCR detection `.onnx`        |
| `DSP_OCR_REC_MODEL`  | *(bundled)*                               | Custom RapidOCR recognition `.onnx`      |
| `DSP_OCR_CLS_MODEL`  | *(bundled)*                               | Custom RapidOCR angle-cls `.onnx`        |
| `DSP_SCROLL_CMD`     | `wayscrollshot --no-border -w 400 -o`     | Scrolling command (output path appended) |

Run `dms-screenshot-plus --print-config` to see the resolved values, the chosen
menu backend, and the detected OCR backend.

## OCR backends & models

OCR is **optional** — only the *OCR text extraction* mode uses it. The backend is
auto-detected in this order: a custom command (`DSP_OCR_CMD`) → RapidOCR → tesseract.
Force one with `DSP_OCR_BACKEND`.

### Option A — RapidOCR (recommended)

[RapidOCR](https://github.com/RapidAI/RapidOCR) runs PaddleOCR's PP-OCR models on
ONNX Runtime — fast, CPU-only, and accurate on mixed Chinese/English.

**The default models ship inside the pip package — there is nothing to download
separately.** Installing `rapidocr-onnxruntime` already includes the PP-OCRv3 set
(~14 MB total): a detection model, an angle-classification model, and a Chinese+English
recognition model.

One-command setup (creates a self-contained venv and verifies it):

```sh
./scripts/setup-ocr.sh
```

Or do it by hand:

```sh
python3 -m venv ~/.local/share/rapidocr-venv
~/.local/share/rapidocr-venv/bin/pip install rapidocr-onnxruntime
```

dms-screenshot-plus **auto-detects** `~/.local/share/rapidocr-venv` (and any
`python3` on `PATH` that can import the module). Point elsewhere with
`DSP_OCR_PYTHON=/path/to/python`.

**Bundled models** (inside the wheel, under `…/rapidocr_onnxruntime/models/`):

| Role            | File                                   | Size  |
| --------------- | -------------------------------------- | ----- |
| Detection       | `ch_PP-OCRv3_det_infer.onnx`           | ~2 MB |
| Recognition     | `ch_PP-OCRv3_rec_infer.onnx` (zh + en) | ~11 MB |
| Angle classify  | `ch_ppocr_mobile_v2.0_cls_infer.onnx`  | ~0.5 MB |

**Using better / other-language models (optional).** Newer PP-OCRv4/v5 or
language-specific recognition models give higher accuracy. Download the `.onnx`
files and point the three variables at them — no code change needed:

```sh
# example: keep your models under a stable directory
mkdir -p ~/.local/share/rapidocr-models
# download e.g. PP-OCRv4 det/rec/cls .onnx into that folder, then:
export DSP_OCR_DET_MODEL=~/.local/share/rapidocr-models/det.onnx
export DSP_OCR_REC_MODEL=~/.local/share/rapidocr-models/rec.onnx
export DSP_OCR_CLS_MODEL=~/.local/share/rapidocr-models/cls.onnx
```

Where to get models:

- **RapidAI model zoo** — <https://github.com/RapidAI/RapidOCR> (see its docs for
  ONNX download links and the per-language recognition models).
- **ModelScope** — <https://www.modelscope.cn/models/RapidAI/RapidOCR> (mirror with
  fast downloads in mainland China).
- **PaddleOCR** ONNX exports — PP-OCRv4 / v5 detection & multilingual recognition.

Set any subset; unset variables keep the bundled default. Put the same lines in
`~/.config/dms-screenshot-plus/config` to make them permanent.

### Option B — tesseract

A lighter, ubiquitous alternative. Install it plus the language data you need
(see the dependency commands above), then:

```sh
DSP_OCR_BACKEND=tesseract DSP_OCR_TESS_LANGS=chi_sim+eng dms-screenshot-plus ocr
```

Tesseract's language data **are** its models — `tesseract-ocr-chi-sim`,
`-eng`, etc. — installed through your package manager, not downloaded manually.

### Option C — bring your own

For any other engine, set `DSP_OCR_CMD` to a command that takes the **image path
as its last argument** and prints recognised text to stdout:

```sh
DSP_OCR_CMD="my-ocr-wrapper --stdout" dms-screenshot-plus ocr
```

## How it works

1. A capture is written to `DSP_MEM_DIR` (tmpfs) under a per-run filename, so
   firing the hotkey twice never clobbers an in-flight shot; stale shots (older
   than an hour) are reaped on the next run.
2. The path is placed on the clipboard immediately.
3. A notification offers six actions; your choice may overwrite the clipboard
   (image bytes), move the file to `DSP_SAVE_DIR`, open it, annotate it, or pin
   it on top.
4. OCR is a separate flow: it recognises text and copies the **text** instead.

## Troubleshooting

- **`dms-screenshot-plus doctor`** prints a ✓/✗ report of every dependency and
  what it unlocks, plus the resolved menu and OCR backends. It exits non-zero
  when a *core* tool is missing.
- **Nothing happens when I press the key.** Usually no menu backend is installed
  — `doctor` will flag it; install `fuzzel` (or `wofi`/`rofi`/`bemenu`).
- **OCR found no text.** Re-run with `DSP_DEBUG=1 dms-screenshot-plus ocr` and
  read `$XDG_RUNTIME_DIR/dms-screenshot-plus.log`. A traceback there (and an
  *"OCR engine error"* notification) means the engine crashed; an *"No text
  recognised"* notification with an empty log means it ran but read nothing in
  that region.

## License

[MIT](./LICENSE) © Gm-aaa
