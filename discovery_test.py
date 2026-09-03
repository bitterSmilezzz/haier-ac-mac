#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
局域网发现测试：向当前 WiFi 广播 HF-A11ASSISTHREAD，
看海尔空调 WiFi 模块是否响应（返回 IP,MAC,SN 或 JSON）。
用法: python3 discovery_test.py [秒数]
"""

import socket
import sys
import time
import json

PORTS = [48899, 30000]
MAGIC = b"HF-A11ASSISTHREAD"


def main():
    timeout = float(sys.argv[1]) if len(sys.argv) > 1 else 4

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("", 0))
    sock.settimeout(1)

    print(f">> 广播发现指令到端口 {PORTS}，监听 {timeout} 秒 ...")
    for port in PORTS:
        sock.sendto(MAGIC, ("255.255.255.255", port))

    found = []
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            data, addr = sock.recvfrom(2048)
        except socket.timeout:
            continue
        raw = data.decode(errors="replace").strip()
        print(f"[响应] {addr[0]}:{addr[1]} -> {raw[:200]}")
        # 解析
        try:
            j = json.loads(raw)
            found.append((addr[0], j))
        except json.JSONDecodeError:
            found.append((addr[0], raw))

    if not found:
        print("\n>> 没有设备响应。可能原因：")
        print("   1. 空调 WiFi 模块型号不支持局域网发现")
        print("   2. 模块固件未开启发现响应")
        print("   3. 空调与 Mac 不在同一网段/VLAN")
    else:
        print(f"\n>> 发现 {len(found)} 台设备")
        for ip, info in found:
            print(f"   - {ip}: {info}")


if __name__ == "__main__":
    main()
