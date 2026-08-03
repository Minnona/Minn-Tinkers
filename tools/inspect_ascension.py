#!/usr/bin/env python3
from __future__ import annotations

import re
import ssl
import urllib.request
from pathlib import Path

URL = "https://db.ascension.gg/?spells=7.12"
OUT = Path("ascension-db-work")
OUT.mkdir(parents=True, exist_ok=True)

req = urllib.request.Request(
    URL,
    headers={
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/150 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml",
        "Accept-Language": "en-US,en;q=0.9",
    },
)

ctx = ssl.create_default_context()
with urllib.request.urlopen(req, timeout=60, context=ctx) as response:
    raw = response.read()
    status = response.status
    final_url = response.geturl()
    headers = dict(response.headers.items())

html = raw.decode("utf-8", errors="replace")
(OUT / "class12.html").write_text(html, encoding="utf-8")

lines: list[str] = []
lines.append(f"status={status}")
lines.append(f"final_url={final_url}")
lines.append(f"bytes={len(raw)}")
lines.append(f"chars={len(html)}")
lines.append(f"content_type={headers.get('Content-Type')}")
lines.append(f"listview_count={html.count('new Listview(')}")
lines.append(f"spell_link_count={len(re.findall(r'\\?spell=\\d+', html))}")
lines.append("")

for pattern in ["new Listview(", "data:", 'template:\\'spell\\'', 'template: \"spell\"', "g_spells", "lv_spells"]:
    positions = [m.start() for m in re.finditer(re.escape(pattern), html)]
    lines.append(f"PATTERN {pattern!r}: {positions[:30]}")
lines.append("")

for i, match in enumerate(re.finditer(r"new Listview\\(", html)):
    start = max(0, match.start() - 300)
    end = min(len(html), match.start() + 12000)
    lines.append(f"===== LISTVIEW {i + 1} @ {match.start()} =====")
    lines.append(html[start:end])
    lines.append("")

# Also record likely inline JSON/object fragments containing spell rows.
for i, match in enumerate(re.finditer(r"(?:data|rows)\\s*:\\s*\\[", html)):
    start = max(0, match.start() - 500)
    end = min(len(html), match.start() + 15000)
    lines.append(f"===== DATA BLOCK {i + 1} @ {match.start()} =====")
    lines.append(html[start:end])
    lines.append("")

(OUT / "inspection.txt").write_text("\n".join(lines), encoding="utf-8")
print("\n".join(lines[:20]))
