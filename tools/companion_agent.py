#!/usr/bin/env python3
"""
DarkgreenOS Companion Agent — host-side AI bridge.

Connects to QEMU serial (COM1) and translates natural language into kernel commands.
Optional: set OPENAI_API_KEY for LLM mode; otherwise uses local rules.

Usage:
  Terminal 1:  make run-ai
  Terminal 2:  python3 tools/companion_agent.py

Or manual serial:  python3 tools/companion_agent.py --port /dev/ttyS0
"""

from __future__ import annotations

import argparse
import os
import re
import socket
import sys
import time

SERIAL_HOST = "127.0.0.1"
SERIAL_PORT = 4444

KERNEL_COMMANDS = """
You control DarkgreenOS via one line per command. Only output ONE command, no explanation.
Commands:
  HELP
  STATUS
  PING
  SNAPSHOT
  STATS
  AUDIT
  SAY <text>
  COLOR <two hex digits e.g. 0A>
  MOOD <word>
  NAME <word>
  PATCH persona|<text>   (runtime RAM patch)
  PATCH name|<text>
  THINK <user message>   (local kernel brain)
  TICKS
  CLEAR
  tasks | yield | run | sync
  policy set thr=<1-16>
  policy set budget_gui=<n>
  cat <file>
Examples:
  user: make screen green -> COLOR 0A
  user: call yourself Nova -> NAME Nova
  user: how are you -> THINK hello
"""

RMGR_HINTS = ("lento", "slow", "rallenta", "rmgr", "audit", "memoria", "ram", "perche")
WEB_HINTS = ("cerca", "search", "web", "internet", "google")


def web_search(query: str, max_chars: int = 400) -> str:
    """Lightweight web snippet (no extra deps)."""
    try:
        import urllib.parse
        import urllib.request

        q = urllib.parse.quote(query)
        url = f"https://api.duckduckgo.com/?q={q}&format=json&no_html=1"
        req = urllib.request.Request(url, headers={"User-Agent": "DarkgreenOS-companion/0.10"})
        with urllib.request.urlopen(req, timeout=12) as resp:
            import json

            data = json.loads(resp.read().decode())
        abstract = (data.get("AbstractText") or "").strip()
        if abstract:
            return abstract[:max_chars]
        topics = data.get("RelatedTopics") or []
        for item in topics[:3]:
            if isinstance(item, dict) and item.get("Text"):
                return str(item["Text"])[:max_chars]
    except Exception as e:
        return f"(web unavailable: {e})"
    return "(no web result)"


def auto_policy_tune(link: "SerialLink", snapshot: dict[str, str]) -> None:
    """Apply POLICY_SET from SNAP metrics when RAM/CPU pressure is high."""
    free_s = snapshot.get("free", "")
    dt_s = snapshot.get("dT", "")
    try:
        free_kb = int(free_s)
    except ValueError:
        return
    try:
        dt = int(dt_s)
    except ValueError:
        dt = 0
    thr = 8
    if free_kb < 32768 or dt > 500:
        thr = 2
    elif free_kb < 65536 or dt > 300:
        thr = 4
    elif dt < 80:
        thr = 12
    link.transact(f"policy set thr={thr}")
    if free_kb < 49152:
        link.transact("policy set budget_gui=200")
    print(f"[agent] auto-tune thr={thr} (free={free_kb} dT={dt})")


def say_stream(link: "SerialLink", text: str, chunk: int = 48) -> None:
    """Split long replies into multiple SAY lines for lower perceived lag."""
    text = text.strip()
    if not text:
        return
    if len(text) <= chunk:
        link.transact(f"SAY {text}")
        return
    for i in range(0, len(text), chunk):
        part = text[i : i + chunk]
        link.transact(f"SAY {part}", wait=0.25)


def parse_snapshot_line(line: str) -> dict[str, str] | None:
    if "SNAP" not in line:
        return None
    out: dict[str, str] = {}
    for token in line.replace("|", " ").split():
        if "=" in token:
            k, v = token.split("=", 1)
            out[k.strip()] = v.strip()
    return out if out else None


def wants_rmgr_context(text: str) -> bool:
    t = text.strip().lower()
    return t.startswith("/rmgr") or t.startswith("rmgr ") or any(h in t for h in RMGR_HINTS)


def rule_based_translate(text: str) -> str:
    t = text.strip().lower()
    if not t:
        return "HELP"
    if t in ("help", "?", "aiuto"):
        return "HELP"
    if t in ("tasks", "yield", "run", "sync"):
        return t if t == "run" else t
    if t.startswith("policy set "):
        return text.strip()
    if t.startswith("cat "):
        return text.strip()
    if t.startswith("web ") or t.startswith("/web "):
        q = text.split(maxsplit=1)[-1].strip()
        snippet = web_search(q)
        return f"SAY Web: {snippet[:200]}"
    if t in ("ping", "test"):
        return "PING"
    if t in ("status", "stato"):
        return "STATUS"
    if t in ("snapshot", "snap"):
        return "SNAPSHOT"
    if t in ("stats",):
        return "STATS"
    if t in ("audit",):
        return "AUDIT"
    if t in ("clear", "pulisci", "cls"):
        return "CLEAR"
    if t in ("ticks", "timer"):
        return "TICKS"
    if t.startswith("say "):
        return "SAY " + text[4:].strip()
    if t.startswith("color ") or t.startswith("colore "):
        hexpart = re.sub(r"[^0-9a-fA-F]", "", t.split(maxsplit=1)[-1])[:2]
        return f"COLOR {hexpart or '0A'}"
    if t.startswith("mood "):
        return "MOOD " + text[5:].strip()
    if t.startswith("name ") or t.startswith("nome "):
        return "NAME " + text.split(maxsplit=1)[-1].strip()
    if t.startswith("patch "):
        return "PATCH " + text[6:].strip()
    if "verde" in t or "green" in t:
        return "COLOR 0A"
    if "rosso" in t or "red" in t:
        return "COLOR 0C"
    if "chiama" in t or "name yourself" in t or "call you" in t:
        name = re.sub(r".*(?:call you|chiama(?:ti)?)\s+", "", t, flags=re.I).strip()
        return f"NAME {name.title() or 'Nova'}"
    return f"THINK {text.strip()}"


def llm_rmgr_advice(user: str, snapshot: dict[str, str], audit_lines: list[str]) -> str:
    api_key = os.environ.get("OPENAI_API_KEY")
    ctx = f"SNAPSHOT: {snapshot}\nAUDIT: {audit_lines}"
    if not api_key:
        free = snapshot.get("free", "?")
        dt = snapshot.get("dT", "?")
        return f"SAY Kernel RMGR: free={free} dT={dt}. Usa THINK o riduci scan/GUI se lento."
    try:
        import json
        import urllib.request

        body = json.dumps(
            {
                "model": os.environ.get("OPENAI_MODEL", "gpt-4o-mini"),
                "messages": [
                    {
                        "role": "system",
                        "content": (
                            "You advise on DarkgreenOS resource orchestrator (RMGR). "
                            "Reply with one SAY line for the user, citing metrics. No kernel commands."
                        ),
                    },
                    {"role": "user", "content": f"Question: {user}\n{ctx}"},
                ],
                "max_tokens": 120,
                "temperature": 0.3,
            }
        ).encode()
        req = urllib.request.Request(
            "https://api.openai.com/v1/chat/completions",
            data=body,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
        return data["choices"][0]["message"]["content"].strip().split("\n")[0]
    except Exception as e:
        print(f"[agent] RMGR LLM fallback ({e})", file=sys.stderr)
        return f"SAY RMGR: score={snapshot.get('score', '?')} thr={snapshot.get('thr', '?')}"


def llm_translate(text: str) -> str:
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        return rule_based_translate(text)

    try:
        import urllib.request
        import json

        body = json.dumps(
            {
                "model": os.environ.get("OPENAI_MODEL", "gpt-4o-mini"),
                "messages": [
                    {"role": "system", "content": KERNEL_COMMANDS},
                    {"role": "user", "content": text},
                ],
                "max_tokens": 60,
                "temperature": 0.2,
            }
        ).encode()
        req = urllib.request.Request(
            "https://api.openai.com/v1/chat/completions",
            data=body,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
        cmd = data["choices"][0]["message"]["content"].strip().split("\n")[0]
        return cmd.upper() if cmd.islower() and " " not in cmd else cmd
    except Exception as e:
        print(f"[agent] LLM fallback ({e})", file=sys.stderr)
        return rule_based_translate(text)


class SerialLink:
    def __init__(self, host: str, port: int):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.settimeout(60)
        print(f"[agent] Connecting to {host}:{port} ...")
        for _ in range(30):
            try:
                self.sock.connect((host, port))
                break
            except OSError:
                time.sleep(1)
        else:
            raise SystemExit("Could not connect. Start QEMU with: make run-ai")
        print("[agent] Connected. Type messages (Ctrl+C to quit).\n")

    def send_line(self, line: str) -> None:
        self.sock.sendall((line.strip() + "\n").encode())

    def recv_line(self) -> str:
        buf = b""
        while b"\n" not in buf:
            chunk = self.sock.recv(1)
            if not chunk:
                return ""
            buf += chunk
        return buf.decode(errors="replace").strip()

    def transact(self, cmd: str, wait: float = 0.4) -> list[str]:
        self.send_line(cmd)
        time.sleep(wait)
        lines: list[str] = []
        self.sock.settimeout(0.5)
        try:
            while True:
                line = self.recv_line()
                if not line:
                    break
                lines.append(line)
                if line.startswith("OK") or line.startswith("ERR"):
                    break
        except OSError:
            pass
        self.sock.settimeout(60)
        return lines

    def fetch_rmgr_context(self) -> tuple[dict[str, str], list[str]]:
        snap_lines = self.transact("SNAPSHOT")
        audit_lines = self.transact("AUDIT")
        snapshot: dict[str, str] = {}
        for line in snap_lines:
            parsed = parse_snapshot_line(line)
            if parsed:
                snapshot = parsed
        audit = [ln for ln in audit_lines if " act=" in ln]
        return snapshot, audit


def main() -> None:
    parser = argparse.ArgumentParser(description="DarkgreenOS Companion host agent")
    parser.add_argument("--host", default=SERIAL_HOST)
    parser.add_argument("--port", type=int, default=SERIAL_PORT)
    parser.add_argument("--no-llm", action="store_true", help="Force rule-based mode")
    parser.add_argument(
        "--auto-tune",
        type=int,
        default=0,
        metavar="SEC",
        help="Every N seconds fetch SNAP and auto POLICY_SET",
    )
    args = parser.parse_args()

    link = SerialLink(args.host, args.port)
    translate = rule_based_translate if args.no_llm else llm_translate
    last_tune = 0.0

    try:
        while True:
            try:
                user = input("you> ").strip()
            except EOFError:
                break
            if not user:
                continue
            if user in ("/quit", "exit"):
                break
            if args.auto_tune and (time.time() - last_tune) >= args.auto_tune:
                snapshot, _ = link.fetch_rmgr_context()
                if snapshot:
                    auto_policy_tune(link, snapshot)
                last_tune = time.time()
            tlow = user.lower()
            if tlow.startswith("/web ") or tlow.startswith("web "):
                q = user.split(maxsplit=1)[-1]
                snippet = web_search(q)
                say_stream(link, f"Web: {snippet}")
                continue
            if any(h in tlow for h in WEB_HINTS) and ("cerca" in tlow or "search" in tlow):
                q = re.sub(r".*(?:cerca|search)\s+", "", tlow, flags=re.I).strip() or user
                say_stream(link, f"Web: {web_search(q)[:220]}")
                continue
            if wants_rmgr_context(user):
                snapshot, audit = link.fetch_rmgr_context()
                print(f"rmgr> {snapshot}")
                advice = llm_rmgr_advice(user, snapshot, audit)
                if advice.upper().startswith("SAY "):
                    say_stream(link, advice[4:].strip())
                else:
                    print(f"advice> {advice}")
                    say_stream(link, advice)
                try:
                    reply = link.recv_line()
                    if reply:
                        print(f"os>  {reply}")
                except socket.timeout:
                    pass
                continue
            cmd = translate(user)
            print(f"cmd> {cmd}")
            if cmd.upper().startswith("SAY "):
                say_stream(link, cmd[4:].strip())
                continue
            lines = link.transact(cmd)
            for line in lines:
                print(f"os>  {line}")
    except KeyboardInterrupt:
        print("\n[agent] Bye.")


if __name__ == "__main__":
    main()
