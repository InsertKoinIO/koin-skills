#!/usr/bin/env python3
"""Check what a new Codex session sees after installing this checkout."""

import json
import os
import re
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
expected_skills = {"koin:koin", "koin:koin-setup", "koin:di-migration", "koin:koin-diagnose"}

with tempfile.TemporaryDirectory(prefix="koin-codex-") as scratch:
    profile = Path(scratch) / ".codex"
    profile.mkdir()
    (profile / "config.toml").write_text(
        'cli_auth_credentials_store = "file"\nmcp_oauth_credentials_store = "file"\n'
    )
    # Use a fresh user profile and keep optional HTTP lookups off the network.
    env = {
        "PATH": os.environ["PATH"],
        "HOME": scratch,
        "CODEX_HOME": str(profile),
        "HTTP_PROXY": "http://127.0.0.1:9",
        "HTTPS_PROXY": "http://127.0.0.1:9",
    }

    def codex(*args):
        return subprocess.check_output(["codex", *args], cwd=scratch, env=env, text=True, timeout=60)

    codex("plugin", "marketplace", "add", str(root))
    codex("plugin", "add", "koin@koin-skills")

    # Read the skill catalog exposed to the model without submitting a prompt.
    visible_skills = set()
    for message in json.loads(codex("debug", "prompt-input")):
        if message.get("role") != "developer":
            continue
        for part in message.get("content", []):
            names = re.findall(r"^- (koin:[\w-]+): ", part.get("text", ""), re.MULTILINE)
            visible_skills.update(names)
    missing = expected_skills - visible_skills
    if missing:
        raise SystemExit("Missing from the Codex skill catalog: " + ", ".join(sorted(missing)))

    server = json.loads(codex("mcp", "get", "kotzilla", "--json"))
    transport = server["transport"]
    endpoint = "https://mcp.kotzilla.io/mcp"
    if not (server["enabled"] and transport["type"] == "streamable_http" and transport["url"] == endpoint):
        raise SystemExit(f"Expected the enabled Kotzilla Streamable HTTP endpoint at {endpoint}")

print("Codex plugin OK: " + ", ".join(sorted(expected_skills)) + " and the Kotzilla MCP endpoint")
