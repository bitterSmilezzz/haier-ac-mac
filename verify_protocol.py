#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
海尔智家云 API 协议验证脚本
- 登录（手机号+密码）
- 拉取设备列表
- 拉取每个设备的数字模型（属性定义+当前值），标注"亮度"相关属性
- 获取 WebSocket 网关地址（验证连通性）

用法:
    HAIER_PHONE=138xxxx HAIER_PASSWORD='xxx' python3 verify_protocol.py
或直接运行，交互式输入手机号和密码（密码不回显）。
"""

import getpass
import hashlib
import json
import os
import random
import sys
import time
import urllib.error
import urllib.request
from urllib.parse import urlparse

APP_ID = "MB-UZHSH-0001"
APP_KEY = "5dfca8714eb26e3a776e58a8273c8752"

LOGIN_API = "https://zj.haier.net/api-gw/oauthserver/account/v1/login"
GET_DEVICES_API = "https://uws.haier.net/uds/v1/protected/deviceinfos"
GET_DIGITAL_MODEL_API = "https://uws.haier.net/shadow/v1/devdigitalmodels"
GET_WSS_GW_API = "https://uws.haier.net/gmsWS/wsag/assign"


def _sign(url, body, app_id, app_key, timestamp):
    """sign = sha256(urlPath + body去空白 + appId + appKey + timestamp)"""
    content = (
        urlparse(url).path
        + body.replace("\t", "").replace("\r", "").replace("\n", "").replace(" ", "")
        + str(app_id)
        + str(app_key)
        + str(timestamp)
    )
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


def _common_headers(url, body, token, client_id):
    timestamp = str(int(time.time() * 1000))
    sequence_id = time.strftime("%Y%m%d%H%M%S") + str(random.randint(100000, 999999))
    return {
        "accessToken": token,
        "appId": APP_ID,
        "appKey": APP_KEY,
        "clientId": client_id,
        "sequenceId": sequence_id,
        "sign": _sign(url, body, APP_ID, APP_KEY, timestamp),
        "timestamp": timestamp,
        "timezone": "+8",
        "language": "zh-CN",
        "Content-Type": "application/json",
    }


def _request(url, payload, token, client_id, method="POST"):
    body = json.dumps(payload) if payload is not None else ""
    headers = _common_headers(url, body, token, client_id)
    req = urllib.request.Request(url, method=method)
    for k, v in headers.items():
        req.add_header(k, v)
    if payload is not None:
        req.data = body.encode("utf-8")

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", errors="replace")
        print(f"[HTTP {e.code}] {url}\n{raw[:500]}")
        sys.exit(1)

    try:
        content = json.loads(raw)
    except json.JSONDecodeError:
        print(f"[非JSON响应] {url}\n{raw[:500]}")
        sys.exit(1)

    if "retCode" in content and content["retCode"] != "00000":
        print(f"[接口错误] {url} -> retCode={content['retCode']} retInfo={content.get('retInfo')}")
        sys.exit(1)
    return content


def login(phone, password):
    print(">> 1/4 登录海尔智家云 ...")
    payload = {"username": phone, "password": password}
    content = _request(LOGIN_API, payload, token="", client_id=phone)
    token_info = content["data"]["tokenInfo"]
    print(f"   登录成功 accountToken={token_info['accountToken'][:16]}... expiresIn={token_info['expiresIn']}s")
    return token_info["accountToken"]


def get_devices(token, client_id):
    print(">> 2/4 拉取设备列表 ...")
    content = _request(GET_DEVICES_API, None, token, client_id, method="GET")
    devices = content.get("deviceinfos", [])
    print(f"   共 {len(devices)} 台设备:")
    for d in devices:
        print(
            f"   - [{d.get('deviceType')}] {d.get('deviceName')} | productNameT={d.get('productNameT')} "
            f"| wifiType={d.get('wifiType')} | online={d.get('online')} | deviceId={d.get('deviceId')}"
        )
    return devices


def get_digital_models(token, client_id, devices):
    print(">> 3/4 拉取设备数字模型（属性定义+当前值）...")
    ids = [d["deviceId"] for d in devices]
    payload = {"deviceInfoList": [{"deviceId": i} for i in ids]}
    content = _request(GET_DIGITAL_MODEL_API, payload, token, client_id)
    detail = content.get("detailInfo", {})

    brightness_hits = []
    for dev in devices:
        device_id = dev["deviceId"]
        print(f"\n   ==== 设备 {dev.get('deviceName')} ({device_id}) ====")
        raw = detail.get(device_id)
        if not raw:
            print("   无数字模型数据")
            continue
        try:
            attributes = json.loads(raw)["attributes"]
        except (json.JSONDecodeError, KeyError, TypeError):
            print(f"   数字模型解析失败: {str(raw)[:200]}")
            continue

        print(f"   属性总数: {len(attributes)}")
        for attr in attributes:
            name = attr.get("name")
            desc = attr.get("desc", "")
            value = attr.get("value")
            writable = attr.get("writable")
            vr = attr.get("valueRange") or {}
            if vr.get("type") == "STEP":
                ds = vr.get("dataStep") or {}
                rng = f"STEP [{ds.get('minValue')} ~ {ds.get('maxValue')} step={ds.get('step')}]"
            elif vr.get("type") == "LIST":
                rng = "LIST " + str([i.get("desc") for i in (vr.get("dataList") or [])])
            else:
                rng = str(vr.get("type"))

            flag = ""
            # 亮度相关属性高亮（中文描述或英文属性名）
            if any(k in str(desc) for k in ("亮度", "背光", "灯光")) or any(
                k in name.lower() for k in ("brightness", "backlight", "light")
            ):
                flag = "  <<< 亮度相关"
                brightness_hits.append((dev.get("deviceName"), name, desc, value, rng, writable))

            print(f"   {name} | {desc} | value={value} | writable={writable} | {rng}{flag}")

    print("\n>> 亮度相关属性汇总:")
    if brightness_hits:
        for name_, attr, desc, value, rng, writable in brightness_hits:
            print(f"   - {name_} / {attr} ({desc}) value={value} {rng} writable={writable}")
    else:
        print("   未发现名称/描述含'亮度'的属性，请把上方完整属性列表发给我分析。")

    return brightness_hits


def get_gateway(token, client_id):
    print("\n>> 4/4 获取 WebSocket 网关地址 ...")
    payload = {"clientId": client_id, "token": token}
    content = _request(GET_WSS_GW_API, payload, token, client_id)
    addr = content.get("agAddr", "")
    print(f"   网关: {addr.replace('http://', 'wss://')}")
    return addr


def main():
    phone = os.environ.get("HAIER_PHONE")
    password = os.environ.get("HAIER_PASSWORD")
    if not phone:
        phone = input("海尔智家手机号: ").strip()
    if not password:
        password = getpass.getpass("密码(输入不回显): ")

    token = login(phone, password)
    devices = get_devices(token, phone)
    if not devices:
        print("账号下没有设备，请确认空调已在海尔智家APP中绑定。")
        return
    get_digital_models(token, phone, devices)
    get_gateway(token, phone)
    print("\n全部验证通过 ✔")


if __name__ == "__main__":
    main()
