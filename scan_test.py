#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
深度诊断：海尔空调局域网可达性
1. 从绑定端口 30000/48899 重发两种发现指令（部分模块只回固定源端口）
2. 扫描局域网内 TCP 80 端口（海尔部分机型提供本地 HTTP 服务）
3. 显示本机 IP/网关，确认网段
用法: python3 scan_test.py
"""

import socket
import struct
import sys
import time
import json

MAGICS = [b"HF-A11ASSISTHREAD", b"WIFIKIT-214028-READ"]
PORTS = [30000, 48899]


def local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"
    finally:
        s.close()


def udp_discovery():
    print(">> [1/3] UDP 发现（绑定固定源端口，双指令）")
    found = []
    for bind_port in PORTS:
        for magic in MAGICS:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                sock.bind(("", bind_port))
            except OSError as e:
                print(f"   绑定 {bind_port} 失败: {e}")
                sock.close()
                continue
            sock.settimeout(0.8)
            sock.sendto(magic, ("255.255.255.255", bind_port))
            try:
                data, addr = sock.recvfrom(2048)
                raw = data.decode(errors="replace").strip()
                print(f"   [响应] {addr[0]}:{addr[1]} magic={magic.decode()} -> {raw[:150]}")
                found.append((addr[0], raw))
            except socket.timeout:
                pass
            sock.close()
    if not found:
        print("   -> UDP 发现无响应")
    return found


def tcp_scan(ip, ports=(80, 8080, 30000, 46000), timeout=0.4):
    """快速并发 TCP 端口扫描单个 IP"""
    open_ports = []
    for port in ports:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(timeout)
        try:
            if s.connect_ex((ip, port)) == 0:
                open_ports.append(port)
        except OSError:
            pass
        s.close()
    return open_ports


def main():
    my_ip = local_ip()
    print(f">> 本机 IP: {my_ip}")

    # 网段
    parts = my_ip.split(".")
    network = ".".join(parts[:3])
    print(f">> 扫描网段: {network}.0/24")

    udp_discovery()

    print(f"\n>> [2/3] TCP 端口扫描（全 /24，4 端口并发，约 20-40 秒）")
    hits = []
    for host in range(1, 255):
        ip = f"{network}.{host}"
        if ip == my_ip:
            continue
        open_ports = tcp_scan(ip)
        if open_ports:
            hits.append((ip, open_ports))
            print(f"   [命中] {ip}: {open_ports}")

    print(f"\n>> [3/3] 结果汇总")
    if hits:
        for ip, ports in hits:
            print(f"   - {ip} 开放端口 {ports}")
        print("\n   -> 若其中有 80 端口设备，很可能是空调/智能设备，可尝试访问 http://<ip>/")
    else:
        print("   未发现开放端口的设备（也可能设备处于 5GHz 隔离或 AP 隔离模式）")


if __name__ == "__main__":
    main()
