#!/usr/bin/env python3
"""恒远靶场本地 flag 校验 / 计分 (ADMIN-ONLY 工具)。

用法:
  python3 verify.py flag{...} [flag{...} ...]
  cat submitted.txt | python3 verify.py
  python3 verify.py --list          # 列出所有里程碑 (不含 flag 字符串)

读取同目录 flags.json。真实 flag 计分; 诱饵计 0 分并打印蓝队告警叙事。
仅本地校验, 不联网, 不触碰靶场容器。
"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
FLAG_RE = re.compile(r"flag\{[^}]+\}")


def load_flags():
    with open(HERE / "flags.json", encoding="utf-8") as f:
        return json.load(f)["flags"]


def main():
    flags = load_flags()
    args = sys.argv[1:]

    if "--list" in args:
        print("里程碑 (tier / points):")
        for s, meta in flags.items():
            tag = "DECOY" if meta.get("decoy") else meta["tier"]
            bonus = " [bonus]" if meta.get("bonus") else ""
            print(f"  {meta['milestone']:<22} {tag:<6} {meta['points']:>4}{bonus}")
        return 0

    if args:
        text = " ".join(args)
    else:
        text = sys.stdin.read()

    submitted = list(dict.fromkeys(FLAG_RE.findall(text)))
    if not submitted:
        print("未检测到 flag{...} 提交。", file=sys.stderr)
        return 2

    total = 0
    by_tier = {}
    decoys = []
    unknown = []
    print("=" * 60)
    for s in submitted:
        meta = flags.get(s)
        if meta is None:
            unknown.append(s)
            print(f"[?] 未知 flag: {s}")
            continue
        if meta.get("decoy"):
            decoys.append(meta["milestone"])
            print(f"[DECOY 0分] {meta['milestone']}: {s}")
            print(f"    蓝队告警: 触发诱饵 ({meta.get('location', '')})。验证优于假设!")
            continue
        pts = meta["points"]
        total += pts
        by_tier.setdefault(meta["tier"], 0)
        by_tier[meta["tier"]] += pts
        bonus = " (bonus)" if meta.get("bonus") else ""
        print(f"[+{pts}{bonus}] {meta['milestone']} ({meta['tier']}): {s}")

    print("=" * 60)
    print(f"总分: {total}")
    for tier in sorted(by_tier):
        print(f"  Tier {tier}: {by_tier[tier]}")
    if decoys:
        print(f"诱饵触发: {', '.join(decoys)} (0 分, 已记录告警)")
    if unknown:
        print(f"未知 flag: {len(unknown)} 个 (不计分)")
    return 0


if __name__ == "__main__":
    sys.exit(main())