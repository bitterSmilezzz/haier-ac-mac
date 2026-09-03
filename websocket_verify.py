#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
WebSocket 网关实测脚本
连接海尔智家云网关，订阅设备，下发 getAllProperty 强制全量上报，
解码 zlib+base64 数据，打印设备上报的全部属性（含数字模型之外的隐藏属性）。

用法（需要已装 uv，或用任意带 websockets 的 python 环境）:
    HAIER_PHONE='138xxxx' HAIER_PASSWORD='xxx' uv run --with websockets python3 websocket_verify.py [监听秒数]
"""

import asyncio
import base64
import getpass
import json
import os
import random
import sys
import time
import zlib

import websockets

import verify_protocol as vp


def random_str(length=32):
    return "".join(random.choice("abcdef1234567890") for _ in range(length))


async def main():
    phone = os.environ.get("HAIER_PHONE")
    password = os.environ.get("HAIER_PASSWORD")
    if not phone:
        phone = input("海尔智家手机号: ").strip()
    if not password:
        password = getpass.getpass("密码(输入不回显): ")

    listen_seconds = int(sys.argv[1]) if len(sys.argv) > 1 else 20

    token = vp.login(phone, password)
    devices = vp.get_devices(token, phone)
    if not devices:
        print("无设备，退出")
        return

    device_ids = [d["deviceId"] for d in devices]
    print(f"\n>> 获取网关地址 ...")
    payload = {"clientId": phone, "token": token}
    content = vp._request(vp.GET_WSS_GW_API, payload, token, phone)
    server = content["agAddr"].replace("http://", "wss://")
    print(f"   网关: {server}")

    url = f"{server}/userag?token={token}&agClientId={token}"
    print(f">> 连接 WebSocket: {url[:80]}...")
    async with websockets.connect(url, max_size=10 * 1024 * 1024, proxy=None) as ws:
        # 订阅设备
        await ws.send(json.dumps({
            "agClientId": token,
            "topic": "BoundDevs",
            "content": {"devs": device_ids},
        }))
        print(f">> 已订阅 {len(device_ids)} 台设备")

        # 下发全量上报指令
        sn = random_str(32)
        await ws.send(json.dumps({
            "agClientId": token,
            "topic": "BatchCmdReq",
            "content": {
                "trace": random_str(32),
                "sn": sn,
                "data": [
                    {
                        "sn": sn,
                        "index": 0,
                        "delaySeconds": 0,
                        "subSn": sn + ":0",
                        "deviceId": device_ids[0],
                        "cmdArgs": {"getAllProperty": "getAllProperty"},
                    }
                ],
            },
        }))
        print(">> 已下发 getAllProperty 全量上报指令，开始监听...")

        deadline = time.time() + listen_seconds
        seen_attrs = {}
        while time.time() < deadline:
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=deadline - time.time())
            except asyncio.TimeoutError:
                break
            except websockets.ConnectionClosed as e:
                print(f"!! 连接关闭: {e}")
                break

            try:
                parsed = json.loads(msg)
            except json.JSONDecodeError:
                print(f"[原始帧] {str(msg)[:200]}")
                continue

            topic = parsed.get("topic")
            if topic == "GenMsgDown":
                content_ = parsed.get("content", {})
                if content_.get("businType") != "DigitalModel":
                    print(f"[其他下行] businType={content_.get('businType')} data={str(content_.get('data'))[:100]}")
                    continue
                try:
                    data = json.loads(base64.b64decode(content_["data"]))
                    device_id = data["dev"]
                    args = json.loads(
                        zlib.decompress(base64.b64decode(data["args"]), 16 + zlib.MAX_WBITS).decode("utf-8")
                    )
                except Exception as e:
                    print(f"[解码失败] {e}")
                    continue

                for attr in args.get("attributes", []):
                    seen_attrs[attr.get("name")] = attr
                print(f"   [{time.strftime('%H:%M:%S')}] 设备 {device_id} 上报 {len(args.get('attributes', []))} 个属性 (累计 {len(seen_attrs)})")
            elif topic == "BatchCmdResult":
                # 设备对控制/查询指令的回复，data 可能是属性 JSON 字符串
                content_ = parsed.get("content", {})
                data_raw = content_.get("data")
                if isinstance(data_raw, str):
                    try:
                        result = json.loads(data_raw)
                        print(f"[BatchCmdResult] data={json.dumps(result, ensure_ascii=False)[:500]}")
                        # 尝试解析其中的属性结构
                        inner = result.get("data") or result
                        if isinstance(inner, str):
                            inner = json.loads(inner)
                        if isinstance(inner, dict) and "attributes" in inner:
                            for attr in inner["attributes"]:
                                seen_attrs[attr.get("name")] = attr
                            print(f"   -> 从 BatchCmdResult 解析出 {len(inner['attributes'])} 个属性 (累计 {len(seen_attrs)})")
                        elif isinstance(inner, dict):
                            for attr in inner.get("attributes", []):
                                seen_attrs[attr.get("name")] = attr
                            print(f"   -> 解析出 {len(inner.get('attributes', []))} 个属性 (累计 {len(seen_attrs)})")
                    except json.JSONDecodeError:
                        print(f"[BatchCmdResult] data(非JSON)={data_raw[:300]}")
                else:
                    print(f"[BatchCmdResult] content={json.dumps(content_, ensure_ascii=False)[:300]}")
            elif topic == "HeartBeat" or topic == "GenMsgUp":
                pass
            else:
                print(f"[消息] topic={topic} {str(parsed)[:200]}")

    print(f"\n>> 监听结束，共收到 {len(seen_attrs)} 个去重属性:")
    print(f"{'name':<28} {'desc':<16} {'value':<12} writable  range")
    print("-" * 100)
    for name, attr in sorted(seen_attrs.items()):
        vr = attr.get("valueRange") or {}
        if vr.get("type") == "STEP":
            ds = vr.get("dataStep") or {}
            rng = f"[{ds.get('minValue')}~{ds.get('maxValue')} step={ds.get('step')}]"
        elif vr.get("type") == "LIST":
            rng = str([i.get("desc") for i in (vr.get("dataList") or [])])
        else:
            rng = str(vr.get("type"))
        flag = ""
        if any(k in str(attr.get("desc", "")) for k in ("亮度", "背光", "灯光", "屏显")) or any(
            k in name.lower() for k in ("brightness", "backlight", "light", "screen")
        ):
            flag = "  <<<"
        print(f"{name:<28} {str(attr.get('desc','')):<16} {str(attr.get('value')):<12} {str(attr.get('writable')):<8} {rng}{flag}")


if __name__ == "__main__":
    asyncio.run(main())
