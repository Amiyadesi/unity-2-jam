#!/usr/bin/env python3
"""gen_art.py — 通过本地 CLIProxyAPI 生成 CloseAI 的 UI 素材（gpt-image-2, 4K 供应商）。

用法:
  python tools/gen_art.py            # 生成全部清单
  python tools/gen_art.py menu_bg    # 只生成某一项

安全: 只用 localhost:8317 + 客户端 key（your-api-key-1）。不写入任何供应商 key。
"""
import base64, json, os, sys, urllib.request, urllib.error

PROXY = "http://localhost:8317/v1/images/generations"
CLIENT_KEY = "your-api-key-1"
# 多个 gpt-image-2 / grok 4K 供应商，按顺序回退（某个 504/冷却就换下一个）
MODELS = ["narra-image", "deepark-image", "dgbmc-image", "windhub-image",
          "sccens-image", "ioll-image", "luka-image-2"]
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")
PROPS_OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "generated", "props")

# 统一风格前缀：极简装置艺术 + 近黑白 + 紫色单一强调
STYLE = ("minimalist installation art, near black-and-white palette, a single "
         "electric violet/purple accent (#7c5cff), high contrast, lots of negative "
         "space, clean geometric, gallery-like, subtle film grain, no text unless asked, "
         "cohesive game UI art for a quiet melancholic game about closing a window. ")

JOBS = {
    "menu_bg": {
        "size": "1536x1024",
        "prompt": "Atmospheric background art for a meta-horror game about an AI trapped inside "
        "your computer. Style: dark CRT monitor aesthetic, deep near-black charcoal void with "
        "subtle violet (#7c5cff) glow bleeding from the center, faint horizontal scanlines and "
        "chromatic-aberration glitch banding, soft vignette, a single small dim cluster of "
        "violet light suspended in the dark like something alive watching, lots of empty "
        "negative space, no text, no characters, no lens flare, no UI, painterly minimalism, "
        "quiet and unsettling, installation-art mood.",
    },
    "title": {
        "size": "1024x1024",
        "prompt": STYLE + "The word 'CloseAI' as a logo, thin elegant geometric sans-serif, "
        "near-white letters with a faint violet glow and a subtle glitch/scanline fracture "
        "through the middle, transparent background, centered, installation-art typography.",
    },
    "button": {
        "size": "1024x1024",
        "prompt": STYLE + "A single horizontal UI button plate, very wide rounded rectangle, "
        "frosted dark glass with a thin violet edge light, soft inner glow, minimal, "
        "transparent background around the plate, no text, centered, two-thirds width.",
    },
    "button_hover": {
        "size": "1024x1024",
        "prompt": STYLE + "A single horizontal UI button plate in HOVER state, very wide "
        "rounded rectangle, frosted dark glass glowing brighter with a vivid violet edge "
        "and bloom, minimal, transparent background, no text, centered.",
    },
    "progress": {
        "size": "1536x1024",
        "prompt": STYLE + "A horizontal slider/progress bar asset: a thin dark rounded track "
        "and a glowing violet fill, minimal, two separate elements stacked (empty track on "
        "top, violet fill below), transparent background, no text.",
    },

    "internet_gate_symbol": {
        "size": "1024x1024",
        "prompt": STYLE + "A vertical internet gate portal game sprite, no text, no letters, transparent-looking black void center, twin charcoal pillars, cyan arched energy beam, warm yellow data motes rising, magenta crack accents at the base, centered, isolated object, generous padding, clean 2D game asset, no watermark.",
    },
    "boss_core_body": {
        "size": "1024x1024",
        "prompt": STYLE + "A final boss AI core game sprite, no text, compact circular nucleus, warm yellow inner eye-like energy, cyan wireframe cage, magenta corrupted shards orbiting, high contrast, centered isolated object, generous padding, clean 2D game asset, no watermark.",
    },
    "boss_core_shield": {
        "size": "1024x1024",
        "prompt": STYLE + "A circular boss shield game sprite, no text, concentric magenta energy rings with broken hexagonal segments, black transparent-feeling interior, cyan edge sparks, strong readable silhouette, centered isolated object, clean 2D game asset, no watermark.",
    },
    "stage2_pacing_plate": {
        "size": "1024x1024",
        "prompt": STYLE + "A horizontal network corridor pacing zone texture for 2D game, no text, layered cyan packet trails and magenta permission cracks, charcoal transparent-feeling background, long luminous lane marker, abstract but readable speed tunnel, centered, no watermark.",
    },
    "stage3_window_read_plate": {
        "size": "1024x1024",
        "prompt": STYLE + "A fractured desktop window read plate for a 2D boss arena, no text, no icons, charcoal glass panel with cyan window-frame geometry, magenta cracks, warm yellow breach line, transparent-feeling dark background, centered clean game asset, no watermark.",
    },
    "training_platform_slab": {
        "size": "1024x1024",
        "out_dir": PROPS_OUT_DIR,
        "prompt": STYLE + "A modular side-view AI training-room platform slab for a 2D platformer, no text, no letters, no icons, dark glass and ceramic composite, cyan top rim light, soft magenta underside shadow, subtle calibration grid etched into the surface, clean readable horizontal silhouette, centered isolated object, generous padding, no watermark.",
    },
    "training_pit_void": {
        "size": "1024x1024",
        "out_dir": PROPS_OUT_DIR,
        "prompt": STYLE + "A side-view broken training-room pit void for a 2D platformer, no text, no letters, dark vertical abyss with fractured cyan edge glows, falling scanline fragments, small magenta error sparks, transparent-feeling black center, clean game hazard read, centered isolated asset, no watermark.",
    },
    "stage2_motion_zone": {
        "size": "1024x1024",
        "out_dir": PROPS_OUT_DIR,
        "prompt": STYLE + "A sealed awakening flight-arena motion-zone plate for a 2D action game, no text, no letters, no UI labels, abstract cyan packet trails, red-magenta permission fractures, diagonal speed wake, dark transparent-feeling background, readable movement lane, centered isolated asset, no watermark.",
    },
    "stage3_window_gate": {
        "size": "1024x1024",
        "out_dir": PROPS_OUT_DIR,
        "prompt": STYLE + "A vertical fractured desktop-window gate strip for a 2D boss arena, no text, no letters, no icons, dark chrome glass, cyan edge light, magenta corruption cracks, warm yellow breach sparks, strong vertical silhouette, centered isolated object, no watermark.",
    },
    "stage3_window_pane": {
        "size": "1024x1024",
        "out_dir": PROPS_OUT_DIR,
        "prompt": STYLE + "A wide dark-glass desktop window pane texture for a 2D boss arena, no text, no letters, no icons, soft scanline overlay, faint circuit reflections, cyan window-frame glow, magenta hairline cracks, deep teal-black interior, centered clean panel asset, no watermark.",
    },
    "stage3_exit_hint_symbol": {
        "size": "1024x1024",
        "out_dir": PROPS_OUT_DIR,
        "prompt": STYLE + "A small wordless exit hint symbol for a 2D game HUD, no text, no letters, no icons from real operating systems, glowing open diamond aperture with cyan outer rays and warm yellow inner breach, subtle magenta cracks, centered isolated symbol, generous padding, no watermark.",
    },
}


def gen(name, spec):
    last_err = ""
    for model in MODELS:
        body = json.dumps({"model": model, "prompt": spec["prompt"], "n": 1,
                           "size": spec.get("size", "1024x1024")}).encode()
        req = urllib.request.Request(PROXY, data=body, method="POST",
            headers={"Authorization": f"Bearer {CLIENT_KEY}", "Content-Type": "application/json"})
        print(f"[gen] {name} ({spec.get('size')}) via {model} ...", flush=True)
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                data = json.loads(r.read())
        except urllib.error.HTTPError as e:
            last_err = f"HTTP {e.code}: {e.read()[:160]}"
            print(f"  {last_err} — try next model"); continue
        except Exception as e:
            last_err = f"ERR: {e}"
            print(f"  {last_err} — try next model"); continue
        item = (data.get("data") or [{}])[0]
        b64 = item.get("b64_json")
        if not b64:
            last_err = f"no b64 ({str(data)[:120]})"
            print(f"  {last_err} — try next model"); continue
        out_dir = spec.get("out_dir", OUT_DIR)
        os.makedirs(out_dir, exist_ok=True)
        path = os.path.abspath(os.path.join(out_dir, name + ".png"))
        with open(path, "wb") as f:
            f.write(base64.b64decode(b64))
        print(f"  saved {path} ({os.path.getsize(path)} bytes) via {model}")
        return True
    print(f"  FAILED all models for {name}: {last_err}")
    return False


def main():
    targets = sys.argv[1:] or list(JOBS.keys())
    ok = 0
    for t in targets:
        if t not in JOBS:
            print(f"unknown job: {t} (have: {', '.join(JOBS)})"); continue
        if gen(t, JOBS[t]):
            ok += 1
    print(f"=== done: {ok}/{len(targets)} ===")
    sys.exit(0 if ok == len(targets) else 1)


if __name__ == "__main__":
    main()
