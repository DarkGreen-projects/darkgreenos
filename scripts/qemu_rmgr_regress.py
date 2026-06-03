#!/usr/bin/env python3
"""Serial smoke test for RMGR audit/profile/snapshot + Phase B/C features."""

from __future__ import annotations

import argparse
import re
import socket
import subprocess
import sys
import time


DEFAULT_SERIAL_PORT = 45871


def read_until(sock: socket.socket, timeout: float = 3.0) -> str:
    deadline = time.time() + timeout
    sock.settimeout(0.2)
    buf = b""
    while time.time() < deadline:
        try:
            chunk = sock.recv(4096)
        except socket.timeout:
            chunk = b""
        if chunk:
            buf += chunk
        time.sleep(0.05)
    return buf.decode("utf-8", errors="replace")


def send(sock: socket.socket, cmd: str, wait: float = 0.5) -> str:
    sock.sendall((cmd + "\n").encode())
    time.sleep(wait)
    return read_until(sock, 2.0)


def connect_serial(port: int, timeout: float = 30.0) -> socket.socket:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            return socket.create_connection(("127.0.0.1", port), timeout=1)
        except OSError:
            time.sleep(0.2)
    raise SystemExit(f"serial TCP connect failed on 127.0.0.1:{port}")


def start_qemu(iso: str, mem: str, port: int) -> subprocess.Popen[bytes]:
    return subprocess.Popen(
        [
            "qemu-system-i386",
            "-cdrom",
            iso,
            "-m",
            mem,
            "-display",
            "none",
            "-serial",
            f"tcp:127.0.0.1:{port},server=on,wait=on",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def run_regress(port: int, iso: str, mem: str) -> None:
    qemu = start_qemu(iso, mem, port)
    time.sleep(0.5)
    try:
        with connect_serial(port) as ser:
            time.sleep(6)
            out = send(ser, "profile")
            print(out)
            if "thr=" not in out:
                raise SystemExit("profile output missing thr=")

            for _ in range(3):
                send(ser, "think test", 0.3)

            out = send(ser, "alloc 64")
            print(out)
            if "alloc" not in out.lower() and "OK" not in out:
                raise SystemExit("alloc command failed")

            snap1 = send(ser, "snapshot")
            print(snap1)
            if "SNAP" not in snap1 or "free=" not in snap1:
                raise SystemExit("snapshot missing SNAP free=")

            audit1 = send(ser, "audit")
            print(audit1)
            if "act=" not in audit1:
                raise SystemExit("audit missing act=")
            if "act=1" not in audit1 and "act=11" not in audit1:
                raise SystemExit("audit missing act=1 (think) or act=11 (alloc)")

            tasks = send(ser, "tasks")
            print(tasks)
            if "task=" not in tasks:
                raise SystemExit("tasks missing task=")
            if "bg=" not in tasks:
                raise SystemExit("tasks missing bg= (background task ticks)")

            send(ser, "yield")
            send(ser, "yield")
            tasks2 = send(ser, "tasks")
            print(tasks2)
            m_bg = re.search(r"bg=(\d+)", tasks2)
            if not m_bg or int(m_bg.group(1)) < 1:
                raise SystemExit("background task bg ticks not advancing")

            sync = send(ser, "sync")
            print(sync)
            if "OK" not in sync and "defer" not in sync.lower():
                raise SystemExit("sync command failed")

            run = send(ser, "run")
            print(run)

            send(ser, "policy set thr=9")
            send(ser, "sync")

            err_out = send(ser, "errors")
            if "ERR" not in err_out and err_out.strip() not in ("-", ""):
                print(f"errors line: {err_out!r}")

            send(ser, "free")
            snap2 = send(ser, "snapshot")
            print(snap2)
            if "tail=" not in snap2:
                raise SystemExit("snapshot missing tail= (DGFS audit.tail export)")
            m1 = re.search(r"dT=(\d+)", snap1)
            m2 = re.search(r"dT=(\d+)", snap2)
            if m1 and m2:
                print(f"delta ticks snapshot: {m1.group(1)} -> {m2.group(1)}")

            audit2 = send(ser, "audit")
            print(audit2)
            acts = set(re.findall(r"act=(\d+)", audit2))
            print(f"audit actions seen: {sorted(acts)}")
            if "11" in acts or "14" in acts:
                print("PMM free-list hooks: OK")

            print("qemu_rmgr_regress: OK")
    finally:
        qemu.terminate()


def cross_boot_test(iso: str, port: int, mem: str) -> None:
    import os

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    patch = os.path.join(root, "scripts", "patch_dgfs_profile.py")

    subprocess.run(["python3", patch, "--thr", "11"], check=True, cwd=root)
    subprocess.run(["make", "iso"], check=True, cwd=root, stdout=subprocess.DEVNULL)

    def boot_once() -> str:
        q = start_qemu(iso, mem, port)
        time.sleep(0.5)
        try:
            with connect_serial(port) as ser:
                time.sleep(6)
                return send(ser, "snapshot")
        finally:
            q.terminate()

    out = boot_once()
    m = re.search(r"thr=(\d+)", out)
    if not m or int(m.group(1)) != 11:
        raise SystemExit(f"cross-boot load expected thr=11 got: {out!r}")
    print("cross_boot_dgfs: OK")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=DEFAULT_SERIAL_PORT)
    parser.add_argument("--iso", default="build/darkgreenos.iso")
    parser.add_argument("--mem", default="2048")
    parser.add_argument("--cross-boot", action="store_true")
    args = parser.parse_args()
    if args.cross_boot:
        cross_boot_test(args.iso, args.port, args.mem)
    else:
        run_regress(args.port, args.iso, args.mem)


if __name__ == "__main__":
    main()
