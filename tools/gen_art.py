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

# 统一风格前缀：极简装置艺术 + 近黑白 + 紫色单一强调
STYLE = ("minimalist installation art, near black-and-white palette, a single "
         "electric violet/purple accent (#7c5cff), high contrast, lots of negative "
         "space, clean geometric, gallery-like, subtle film grain, no text unless asked, "
         "cohesive game UI art for a quiet melancholic game about closing a window. ")

JOBS = {
    "menu_bg": {
        "size": "1536x1024",
        "prompt": STYLE + "A wide menu background: a vast dark void with a single small "
        "glowing violet point of light suspended in the center-right, faint concentric "
        "ripples around it, a barely-visible horizon line, deep blacks, atmospheric, "
        "lonely, like a sealed system waiting to be observed. Empty space at left for a title.",
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
        os.makedirs(OUT_DIR, exist_ok=True)
        path = os.path.abspath(os.path.join(OUT_DIR, name + ".png"))
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
