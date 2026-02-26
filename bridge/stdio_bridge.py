#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SU MCP Stdio Bridge (Python)
=========================================
Cross-platform MCP stdio bridge for SketchUp.
Works on Windows, macOS, Linux without extra dependencies.

Usage:
    python3 stdio_bridge.py [host] [port]

Claude Desktop config:
    {
      "mcpServers": {
        "sketchup": {
          "command": "python3",
          "args": ["/path/to/bridge/stdio_bridge.py"],
          "env": { "SU_MCP_PORT": "9876" }
        }
      }
    }
    Note: On Windows use "python" instead of "python3" if needed.
"""

from __future__ import annotations

import json
import os
import socket
import sys
import time
from typing import BinaryIO, Tuple

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
HOST           = os.environ.get('SU_MCP_HOST', '127.0.0.1')
PORT           = int(os.environ.get('SU_MCP_PORT', '9876'))
RETRY_INTERVAL = 2    # seconds between connection retries
MAX_RETRIES    = 30   # give up after this many attempts
READ_TIMEOUT   = 30   # seconds to wait for a TCP response


def _log(msg: str) -> None:
    """Write to stderr so it doesn't interfere with JSON-RPC on stdout."""
    print(f'[SU-MCP-Bridge] {msg}', file=sys.stderr, flush=True)


# ---------------------------------------------------------------------------
# TCP Connection
# ---------------------------------------------------------------------------

def _connect() -> socket.socket:
    """Connect to SketchUp TCP server with retries."""
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            sock = socket.create_connection((HOST, PORT), timeout=5)
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            sock.settimeout(READ_TIMEOUT)
            return sock
        except (ConnectionRefusedError, OSError, TimeoutError) as exc:
            if attempt >= MAX_RETRIES:
                raise RuntimeError(
                    f'Cannot connect to SketchUp MCP Server at {HOST}:{PORT} '
                    f'after {MAX_RETRIES} attempts.\n'
                    f'Make sure SketchUp is running and the MCP Server is started '
                    f'(Extensions > SU MCP Server > Start Server).'
                ) from exc
            _log(f'Attempt {attempt}/{MAX_RETRIES} failed: {exc}'
                 f', retrying in {RETRY_INTERVAL}s...')
            time.sleep(RETRY_INTERVAL)
    # 这一行逻辑上不可达（MAX_RETRIES 次后 raise），
    # 但显式 raise 让 Pyre2 能正确推断函数总能返回 socket 或抛出异常
    raise RuntimeError('Unreachable: connection loop exhausted')


# ---------------------------------------------------------------------------
# Binary stdio helpers (handle Windows line-ending issues)
# ---------------------------------------------------------------------------

def _get_binary_stdio() -> Tuple[BinaryIO, BinaryIO]:
    """Return binary stdin/stdout. On Windows, switch to binary mode."""
    if sys.platform == 'win32':
        import msvcrt
        msvcrt.setmode(sys.stdin.fileno(), os.O_BINARY)
        msvcrt.setmode(sys.stdout.fileno(), os.O_BINARY)
    return sys.stdin.buffer, sys.stdout.buffer


# ---------------------------------------------------------------------------
# Main bridge loop
# ---------------------------------------------------------------------------

def _is_request(line: bytes) -> bool:
    """
    判断是否为 JSON-RPC request（有 id 字段）还是 notification（无 id 或 id 为 null）。
    MCP 协议：request 需要响应，notification 不需要响应。
    """
    try:
        msg = json.loads(line)
        # 有 'id' 字段且不为 None → request，需等待响应
        return isinstance(msg, dict) and msg.get('id') is not None
    except Exception:
        # 解析失败时保守地等待响应
        return True


def _make_sock_file(sock: socket.socket) -> BinaryIO:
    """将 socket 包装为二进制文件对象，并标注返回类型供 Pyre2 推断。"""
    return sock.makefile('rwb', buffering=0)  # type: ignore[return-value]


def main() -> None:
    # Allow host/port as positional args for convenience
    if len(sys.argv) >= 2:
        global HOST
        HOST = sys.argv[1]
    if len(sys.argv) >= 3:
        global PORT
        PORT = int(sys.argv[2])

    _log(f'Starting bridge → {HOST}:{PORT}')

    sock = _connect()
    sock_file: BinaryIO = _make_sock_file(sock)
    _log('Connected to SketchUp MCP Server')

    stdin, stdout = _get_binary_stdio()

    while True:
        # Read one line from Claude (MCP client) via stdin
        try:
            raw = stdin.readline()
        except (KeyboardInterrupt, EOFError):
            break

        if not raw:          # stdin closed
            break

        line = raw.strip()
        if not line:
            continue

        # Determine if this message is a request (needs response) or notification (no response)
        needs_response = _is_request(line)

        # Forward to SketchUp TCP server
        try:
            sock_file.write(line + b'\n')
            sock_file.flush()

            if needs_response:
                # Request: block waiting for response
                response = sock_file.readline()
            else:
                # Notification: do NOT wait for a response
                # (MCP notifications/initialized, etc. have no response)
                decoded = line.decode('utf-8', errors='replace')
                _log(f'Notification sent (no response expected): {decoded[:80]}')  # type: ignore
                continue

        except (BrokenPipeError, ConnectionResetError, OSError) as exc:
            _log(f'TCP connection lost: {exc}, reconnecting...')
            try:
                sock.close()
            except Exception:
                pass
            sock = _connect()
            sock_file = _make_sock_file(sock)
            # Retry once after reconnect (only for requests)
            if needs_response:
                try:
                    sock_file.write(line + b'\n')
                    sock_file.flush()
                    response = sock_file.readline()
                except OSError as retry_exc:
                    _log(f'Retry failed: {retry_exc}')
                    continue
            else:
                continue

        if response:
            stdout.write(response.strip() + b'\n')
            stdout.flush()


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        _log('Bridge stopped')
    except Exception as exc:
        _log(f'Fatal error: {exc}')
        sys.exit(1)
