#!/usr/bin/env python3
"""Fetch Anna's Archive pages with a cleared guard session.

AA's /search and /md5 sit behind DDoS-Guard. A browser that has cleared the
guard leaves the __ddg* clearance in its cookies.sqlite; AA also sets a
short-lived aa_ddg_check ticket (15 minutes) whose payload names the
matching __ddg5_ value. Replaying that state with a Firefox TLS fingerprint
works over plain HTTP. curl alone does not.

The panel uses this helper for two things:
  fetch <url>   fetch one page; prints the body and a marker
  ticket        print the age of the newest ticket (cheap local poll)

Markers (always the last line):
  __AAF:OK:<status>
  __AAF:STALE:<age|none>     browser ticket is missing/too old
  __AAF:CHALLENGE:<status>   guard intercepted the request
  __AAF:HTML:<status>        HTTP error that is not a guard challenge
  __AAF:NET:<message>        connection failure

No secrets are printed; cookie values stay in this process.
"""
import base64
import glob
import json
import os
import shutil
import sqlite3
import sys
import tempfile
import time
import urllib.parse

from curl_cffi import requests

UA = "Mozilla/5.0 (X11; Linux x86_64; rv:146.0) Gecko/20100101 Firefox/146.0"
IMPERSONATE = "firefox147"
FRESH_MAX = 720          # refresh well before the 15-minute expiry
CLEARANCE = ("__ddg1_", "__ddg2_", "__ddgid_", "__ddgmark_")
COOKIE_HOST = ".annas-archive.gl"


def is_aa(url):
    host = (urllib.parse.urlparse(url).hostname or "").lower()
    return "annas-archive." in host


def aa_host_filter(url):
    host = (urllib.parse.urlparse(url).hostname or "").lower()
    if host.endswith("annas-archive.gl"):
        return "%annas-archive.gl%"
    return "%annas-archive%"


def read_profile(db, host_filter):
    """Copy the profile DB (plus WAL) and return its AA cookies."""
    tmpdir = tempfile.mkdtemp(prefix="aa-ck-")
    tmp = os.path.join(tmpdir, "cookies.sqlite")
    try:
        shutil.copyfile(db, tmp)
        wal = db + "-wal"
        if os.path.exists(wal):
            shutil.copyfile(wal, tmp + "-wal")
        con = sqlite3.connect(tmp)
        rows = con.execute(
            "SELECT name, value, host, path FROM moz_cookies WHERE host LIKE ?",
            (host_filter,),
        ).fetchall()
        con.close()
        return rows
    except Exception:
        return []
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def decode_ticket(jwt):
    try:
        payload = jwt.split(".")[0]
        payload += "=" * (-len(payload) % 4)
        data = json.loads(base64.urlsafe_b64decode(payload))
        iat = int(data.get("iat", 0))
        ddg5 = str(data.get("ddg5", ""))
        if iat > 0 and ddg5:
            return iat, ddg5
    except Exception:
        pass
    return None


def newest_session(url):
    """Newest aa_ddg_check across Zen profiles, with its clearance cookies."""
    home = os.path.expanduser("~")
    host_filter = aa_host_filter(url) if is_aa(url) else "%annas-archive.gl%"
    best = None
    for db in glob.glob(home + "/.config/zen/*/cookies.sqlite"):
        rows = read_profile(db, host_filter)
        if not rows:
            continue
        by = {r[0]: r for r in rows}
        ticket = by.get("aa_ddg_check")
        if not ticket:
            continue
        decoded = decode_ticket(ticket[1])
        if not decoded:
            continue
        iat, ddg5 = decoded
        if best is None or iat > best["iat"]:
            best = {
                "iat": iat,
                "ddg5": ddg5,
                "ticket": ticket,
                "rows": rows,
                "profile": db,
            }
    return best


def build_session(session):
    s = requests.Session(
        impersonate=IMPERSONATE,
        headers={
            "User-Agent": UA,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.5",
        },
    )
    if session:
        by_name = {r[0]: r for r in session["rows"]}
        for name in CLEARANCE:
            row = by_name.get(name)
            if row:
                s.cookies.set(name, row[1], domain=row[2], path=row[3] or "/")
        for name, value, host, path in session["rows"]:
            if name.startswith("aa_account_id2"):
                s.cookies.set(name, value, domain=host, path=path or "/")
        s.cookies.set("__ddg5_", session["ddg5"], domain=COOKIE_HOST, path="/")
        s.cookies.set("aa_ddg_check", session["ticket"][1], domain=COOKIE_HOST, path="/")
    return s


def looks_like_challenge(body, status):
    if status in (403, 429):
        return True
    head = (body or "")[:6000].lower()
    if "ddos-guard" in head or "ddos guard" in head:
        return True
    if "checking your browser before accessing" in head:
        return True
    return False


def cmd_fetch(url):
    session = None
    if is_aa(url):
        session = newest_session(url)
        if session is None:
            print("__AAF:STALE:none")
            return 0
        age = int(time.time()) - session["iat"]
        sys.stderr.write("aa-fetch: profile=%s age=%ss\n" % (os.path.basename(os.path.dirname(session["profile"])), age))
        if age > FRESH_MAX:
            print("__AAF:STALE:%d" % age)
            return 0

    s = build_session(session)
    if is_aa(url):
        parsed = urllib.parse.urlparse(url)
        s.headers["Referer"] = "%s://%s/" % (parsed.scheme, parsed.netloc)

    try:
        r = s.get(url, timeout=40, allow_redirects=True)
    except Exception as exc:
        print("__AAF:NET:%s" % str(exc).replace("\n", " ")[:200])
        return 0

    body = r.text or ""
    if is_aa(url) and looks_like_challenge(body, r.status_code):
        print("__AAF:CHALLENGE:%d" % r.status_code)
        return 0
    if r.status_code >= 400:
        print("__AAF:HTML:%d" % r.status_code)
        return 0

    sys.stdout.write(body)
    if not body.endswith("\n"):
        sys.stdout.write("\n")
    sys.stdout.write("__AAF:OK:%d\n" % r.status_code)
    return 0


def cmd_ticket():
    session = newest_session("https://annas-archive.gl/")
    if session is None:
        print("__AAF:TICKET:none")
        return 0
    print("__AAF:TICKET:%d" % (int(time.time()) - session["iat"]))
    return 0


def main(argv):
    if len(argv) < 2:
        print("usage: aa-fetch.py fetch <url> | ticket", file=sys.stderr)
        return 2
    if argv[1] == "fetch" and len(argv) >= 3:
        return cmd_fetch(argv[2])
    if argv[1] == "ticket":
        return cmd_ticket()
    print("usage: aa-fetch.py fetch <url> | ticket", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
