"""Smoke-test Unity2.Ai API credentials without leaking secrets."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path


PROFILE_PREFIXES = {
    "default": "UNITY2",
    "codex": "UNITY2_CODEX",
    "claude_code": "UNITY2_CLAUDE_CODE",
}

PLACEHOLDER_VALUES = {
    "replace_with_your_unity2_api_key",
    "replace_with_your_codex_key",
    "replace_with_your_claude_code_key",
}


def load_dotenv(path: Path) -> None:
    """Load simple KEY=VALUE entries from a local .env file."""
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


def join_url(base_url: str, path: str) -> str:
    """Join a base URL and API path with one slash."""
    return f"{base_url.rstrip('/')}/{path.lstrip('/')}"


def is_missing_secret(value: str) -> bool:
    """Return true when an env value is empty or a documented placeholder."""
    return not value or value in PLACEHOLDER_VALUES


def read_profile_config(profile: str) -> tuple[str, str, str]:
    """Read API key, base URL, and model for one Unity2 profile."""
    prefix = PROFILE_PREFIXES[profile]

    if profile == "default":
        api_key = os.environ.get("UNITY2_API_KEY", "").strip()
        model = os.environ.get("UNITY2_MODEL", "").strip()
    else:
        api_key = os.environ.get(f"{prefix}_API_KEY", "").strip()
        model = os.environ.get(f"{prefix}_MODEL", os.environ.get("UNITY2_MODEL", "")).strip()

    base_url = os.environ.get(f"{prefix}_BASE_URL", os.environ.get("UNITY2_BASE_URL", "https://api.unity2.ai/v1")).strip()
    return api_key, base_url, model


def post_json(url: str, api_key: str, payload: dict[str, object], timeout: int) -> dict[str, object]:
    """Send one JSON request to an OpenAI-compatible endpoint."""
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )

    with urllib.request.urlopen(request, timeout=timeout) as response:
        body = response.read().decode("utf-8")
        return json.loads(body)


def get_json(url: str, api_key: str, timeout: int) -> dict[str, object]:
    """Fetch JSON from an OpenAI-compatible endpoint."""
    request = urllib.request.Request(
        url,
        method="GET",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Accept": "application/json",
        },
    )

    with urllib.request.urlopen(request, timeout=timeout) as response:
        body = response.read().decode("utf-8")
        return json.loads(body)


def main() -> int:
    """Validate env config, then call /models or /chat/completions."""
    parser = argparse.ArgumentParser(description="Smoke-test Unity2.Ai API config.")
    parser.add_argument("--env-file", default=".env", help="Path to local env file.")
    parser.add_argument(
        "--profile",
        choices=sorted(PROFILE_PREFIXES),
        default=None,
        help="Config profile to use: codex, claude_code, or default.",
    )
    parser.add_argument("--prompt", default="Say pong in one short word.", help="Prompt for chat test.")
    parser.add_argument("--timeout", type=int, default=30, help="HTTP timeout seconds.")
    parser.add_argument("--dry-run", action="store_true", help="Only validate local env values.")
    args = parser.parse_args()

    load_dotenv(Path(args.env_file))

    profile = args.profile or os.environ.get("UNITY2_PROFILE", "default").strip() or "default"
    if profile not in PROFILE_PREFIXES:
        print(f"Unknown UNITY2_PROFILE: {profile}", file=sys.stderr)
        print("Use one of: codex, claude_code, default.", file=sys.stderr)
        return 2

    api_key, base_url, model = read_profile_config(profile)

    missing = []
    if is_missing_secret(api_key):
        key_name = "UNITY2_API_KEY" if profile == "default" else f"{PROFILE_PREFIXES[profile]}_API_KEY"
        missing.append(key_name)
    if not base_url:
        base_name = "UNITY2_BASE_URL" if profile == "default" else f"{PROFILE_PREFIXES[profile]}_BASE_URL"
        missing.append(base_name)

    if missing:
        print(f"Missing config: {', '.join(missing)}", file=sys.stderr)
        print("Copy .env.example to .env, fill values from Unity2.Ai dashboard, then retry.", file=sys.stderr)
        return 2

    if args.dry_run:
        print("Env ok. No network request sent.")
        print(f"Profile: {profile}")
        print(f"Base URL: {base_url}")
        print(f"Model: {model or '(not set; /models will be tested)'}")
        return 0

    try:
        if model:
            payload = {
                "model": model,
                "messages": [{"role": "user", "content": args.prompt}],
                "temperature": 0,
                "max_tokens": 16,
            }
            data = post_json(join_url(base_url, "chat/completions"), api_key, payload, args.timeout)
            content = (
                data.get("choices", [{}])[0]
                .get("message", {})
                .get("content", "")
            )
            print("Unity2.Ai chat request ok.")
            print(f"Profile: {profile}")
            print(f"Response: {content}")
        else:
            data = get_json(join_url(base_url, "models"), api_key, args.timeout)
            models = data.get("data", [])
            print("Unity2.Ai models request ok.")
            print(f"Profile: {profile}")
            if isinstance(models, list):
                names = [str(item.get("id", item)) for item in models[:8]]
                print("Models:", ", ".join(names) if names else "(empty list)")
            else:
                print(json.dumps(data, ensure_ascii=False, indent=2)[:1000])
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        print(f"Unity2.Ai request failed: HTTP {exc.code}", file=sys.stderr)
        print(body[:1000], file=sys.stderr)
        return 1
    except urllib.error.URLError as exc:
        print(f"Unity2.Ai request failed: {exc.reason}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
