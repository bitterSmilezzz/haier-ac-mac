#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
真实控制指令测试：通过 WebSocket 直接下发 lightStatus 开关指令，
验证"发送 -> 服务器 -> 空调"链路。运行期间请观察空调机身灯光。
默认动作：开灯 5 秒 -> 关灯。
用法:
    HAIER_PHONE='138xxxx' HAIER_PASSWORD='xxx' uv run --with websockets python3 send_control_test.py [on|off]
"""

import asyncio
import getpass
import json
import os
import random
import sys

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

    action = sys.argv[1] if len(sys.argv) > 1 else "toggle"
    if action not in ("on", "off", "toggle"):
        print("参数需为 on / off / toggle")
        return

    token = vp.login(phone, password)
    devices = vp.get_devices(token, phone)
    if not devices:
        print("无设备")
        return
    device_id = devices[0]["deviceId"]

    payload = {"clientId": phone, "token": token}
    content = vp._request(vp.GET_WSS_GW_API, payload, token, phone)
    server = content["agAddr"].replace("http://", "wss://")
    url = f"{server}/userag?token={token}&agClientId={token}"
    print(f">> 连接 {url[:80]}...")

    async with websockets.connect(url, max_size=10 * 1024 * 1024, proxy=None) as ws:
        await ws.send(json.dumps({
            "agClientId": token,
            "topic": "BoundDevs",
            "content": {"devs": [device_id]},
        }))
        print(">> 已订阅设备")

        async def send_cmd(cmd: dict, label: str):
            sn = random_str(32)
            print(f">> [{label}] 下发指令: {json.dumps(cmd, ensure_ascii=False)}")
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
                            "deviceId": device_id,
                            "cmdArgs": cmd,
                        }
                    ],
                },
            }))
            # 等待回复（最多 5 秒）
            try:
                while True:
                    msg = await asyncio.wait_for(ws.recv(), timeout=5)
                    parsed = json.loads(msg)
                    topic = parsed.get("topic")
                    if topic in ("BatchCmdResp", "BatchCmdResult"):
                        content_ = parsed.get("content", {})
                        print(f"[{topic}] {json.dumps(content_, ensure_ascii=False)[:400]}")
                        if topic == "BatchCmdResult":
                            res = content_.get("data", "")
                            # 提取执行结果
                            if isinstance(res, str):
                                try:
                                    ri = json.loads(res)
                                    info = ri.get("detailInfo", [{}])[0]
                                    print(f"   -> execResult={info.get('execResult')} code={info.get('execResultCode')} msg={info.get('execResultInfo')}")
                                except Exception:
                                    pass
                            return
                    elif topic == "GenMsgDown":
                        content_ = parsed.get("content", {})
                        data_raw = content_.get("data")
                        if isinstance(data_raw, str):
                            try:
                                inner = json.loads(data_raw)
                                args_raw = inner.get("args")
                                if isinstance(args_raw, str):
                                    import base64
                                    import zlib
                                    args = json.loads(zlib.decompress(base64.b64decode(args_raw), 16 + zlib.MAX_WBITS))
                                    for a in args.get("attributes", []):
                                        if a.get("name") == "lightStatus":
                                            print(f"[GenMsgDown] lightStatus 当前值 = {a.get('value')}  <<< 设备回读确认")
                            except Exception as e:
                                print(f"[GenMsgDown 解析失败] {e}")
            except asyncio.TimeoutError:
                print("!! 5 秒内未收到 BatchCmdResult 回复")

        # 依次测试两种值格式（布尔 vs 字符串）
        if action == "toggle":
            print("\n===== 测试 1: 布尔 true =====")
            await send_cmd({"lightStatus": True}, "bool")
            print(">> 观察灯光是否亮起 (3 秒)")
            await asyncio.sleep(3)
            print("\n===== 测试 2: 字符串 \"true\" =====")
            await send_cmd({"lightStatus": "true"}, "str")
            print(">> 观察灯光是否亮起 (3 秒)")
            await asyncio.sleep(3)
            print("\n===== 恢复: 布尔 false =====")
            await send_cmd({"lightStatus": False}, "bool")
            print(">> 已发送关闭，观察灯光是否熄灭")
        else:
            await send_cmd({"lightStatus": action == "on"}, "bool")
            print(f">> 已发送 {action}，观察灯光变化")
            await asyncio.sleep(3)


if __name__ == "__main__":
    asyncio.run(main())
