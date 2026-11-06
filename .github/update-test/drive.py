#!/usr/bin/env python3
"""Drives a fresh lab through a package's update (.github/update-test/run.sh).

Goes through Roostack's own pages and commands, as a person would, so it
tests what labs do: installs the previous version with made-up settings,
backs it up, updates it through the service's page, and restores the
backup taken before the update. With no previous version labs can install
(--from is empty), it installs the update itself, backs it up and restores
it. Each step must end with every container running and passing its health
check, and its addresses answering. Prints a table of the steps for the
run's summary; exits 1 if a step failed.
"""
import argparse, base64, hashlib, hmac, html, http.cookiejar, os, re, secrets, shlex
import struct, subprocess, sys, time, urllib.error, urllib.parse, urllib.request

ap = argparse.ArgumentParser()
ap.add_argument("--ui"); ap.add_argument("--package"); ap.add_argument("--from", dest="old")
ap.add_argument("--to"); ap.add_argument("--repo", default=".")
a = ap.parse_args()
SSH = shlex.split(os.environ["UPDATE_TEST_SSH"])
STATE = "/var/lib/roostack"
SERVICES = f"{STATE}/services"
LOCAL = f"{STATE}/local-packages"
SETTLE = 30          # seconds healthy before a step counts as done
results = []


class Failed(Exception):
    pass


def vm(cmd, check=True, stdin=None):
    """Runs a command in the VM as the tester, who has sudo."""
    r = subprocess.run(SSH + [cmd], input=stdin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = r.stdout.decode(errors="replace")
    if check and r.returncode != 0:
        raise Failed(f"{cmd.split()[0:4]}: exit {r.returncode}: {out[-1500:]}")
    return out


def as_roostack(cmd, check=True):
    """Runs a command as the roostack user, in its session."""
    inner = "cd /var/lib/roostack/home; XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus exec bash -c " + shlex.quote(cmd)
    return vm("sudo -u roostack sh -c " + shlex.quote(inner), check)


class Browser:
    def __init__(self):
        self.op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))

    def go(self, path, data=None):
        url = a.ui + path if path.startswith("/") else path
        body = urllib.parse.urlencode(data).encode() if data is not None else None
        req = urllib.request.Request(url, data=body, headers={"Origin": a.ui, "Referer": a.ui + "/"})
        try:
            r = self.op.open(req, timeout=120)
        except urllib.error.HTTPError as e:
            return urllib.parse.urlparse(e.geturl()).path, e.read().decode(errors="replace"), e.code
        return urllib.parse.urlparse(r.geturl()).path, r.read().decode(errors="replace"), r.status


def forms(page):
    out = []
    for m in re.finditer(r"<form\b([^>]*)>(.*?)</form>", page, re.S):
        action = re.search(r'action="([^"]*)"', m.group(1))
        fields = {}
        for f in re.finditer(r"<(input|select|textarea)\b([^>]*)>", m.group(2)):
            name = re.search(r'name="([^"]*)"', f.group(2))
            if not name:
                continue
            attrs = f.group(2)
            value = re.search(r'value="([^"]*)"', attrs)
            kind = re.search(r'type="([^"]*)"', attrs)
            if kind and kind.group(1) in ("checkbox", "radio") and not re.search(r"\bchecked\b", attrs):
                fields.setdefault(html.unescape(name.group(1)), "")
                continue
            fields[html.unescape(name.group(1))] = html.unescape(value.group(1)) if value else ""
        out.append((html.unescape(action.group(1)) if action else "", fields))
    return out


def text(page):
    page = re.sub(r"<(script|style)\b.*?</\1>", "", page, flags=re.S)
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", page))).strip()


def error_of(page):
    m = re.search(r'class="[^"]*error[^"]*"[^>]*>(.*?)</', page, re.S)
    return html.unescape(m.group(1)).strip() if m else text(page)[:300]


def totp(secret):
    step = int(time.time()) // 30
    h = hmac.new(base64.b32decode(secret), struct.pack(">Q", step), hashlib.sha1).digest()
    o = h[-1] & 15
    return "%06d" % ((struct.unpack(">I", h[o:o + 4])[0] & 0x7fffffff) % 1000000)


def sign_in(b):
    """Makes an Owner, as the help says to from the command line, and takes them through the wizard."""
    out = vm("sudo roostack user add tester -role owner")
    temp = re.search(r"Temporary password: (\S+)", out).group(1)
    # The running Roostack is still waiting for first-run setup.
    vm("sudo systemctl restart roostack")
    for _ in range(60):
        try:
            where, page, _ = b.go("/login")
            break
        except OSError:
            time.sleep(5)
    else:
        raise Failed("Roostack's pages never answered")
    action, f = next(x for x in forms(page) if "password" in x[1])
    f.update(username="tester", password=temp)
    where, page, _ = b.go(action or "/login", f)
    password = "Update-test-" + secrets.token_hex(12)
    for _ in range(12):
        if where in ("/account/2fa", "/2fa") or "name=\"secret\"" in page:
            action, f = next(x for x in forms(page) if "secret" in x[1])
            f["code"] = totp(f["secret"])
            where, page, _ = b.go(action or where, f)
        elif where == "/account" and "name=\"current\"" in page:
            action, f = next(x for x in forms(page) if "current" in x[1])
            f.update(current=temp, password=password, confirm=password)
            where, page, _ = b.go(action or where, f)
        elif where == "/account/notifications":
            action, f = next(x for x in forms(page) if "email" in x[1])
            f["email"] = "tester@example.com"
            where, page, _ = b.go(action or where, f)
        elif where == "/setup/timezone":
            action, f = next(x for x in forms(page) if "timezone" in x[1])
            f["timezone"] = f.get("timezone") or "UTC"
            where, page, _ = b.go(action or where, f)
        elif where == "/setup/ssh":
            action, f = next(x for x in forms(page) if "ssh" in x[1])
            f.update(ssh="any", login="key", confirm="on")
            where, page, _ = b.go(action or where, f)
        elif where == "/setup/domain":
            where, page, _ = b.go("/setup/domain/later", {})
        elif where == "/setup/backup":
            where, page, _ = b.go("/setup/backup/later", {})
        else:
            where, page, _ = b.go("/")
            if where == "/" or where == "/home":
                return
    raise Failed(f"signing in stopped at {where}: {text(page)[:300]}")


def add_package(version):
    """Puts a package file on the lab as one of the Owner's own."""
    folder = os.path.join(a.repo, "packages", a.package)
    files = [f"{version}.yaml"] + (["icon.png"] if os.path.exists(os.path.join(folder, "icon.png")) else [])
    tar = subprocess.run(["tar", "-C", folder, "-cf", "-"] + files, stdout=subprocess.PIPE, check=True).stdout
    vm(f"sudo -u roostack sh -c 'rm -rf {LOCAL}/{a.package}; mkdir -p {LOCAL}/{a.package} && tar -C {LOCAL}/{a.package} -xf -'", stdin=tar)
    vm("sudo systemctl restart roostack")
    for _ in range(30):
        if vm(f"curl -fsS -o /dev/null http://127.0.0.1:8480/login && echo up", check=False).strip() == "up":
            return
        time.sleep(2)
    raise Failed("Roostack didn't come back after restarting")


def instance():
    return vm(f"sudo cat {SERVICES}/{a.package}.yaml")


def containers():
    """Each of the service's long-running containers, and its status."""
    out = as_roostack(f"podman ps -a --filter name=^roostack-{a.package}- --format '{{{{.Names}}}}|{{{{.Status}}}}'", check=False)
    return [l.split("|", 1) for l in out.splitlines() if "|" in l]


def wait_healthy(deadline_minutes, want_version=None):
    """Waits for the service to be set up, all its containers up and healthy, and its addresses answering, and for that to last."""
    deadline = time.time() + float(os.environ.get("UPDATE_TEST_MINUTES", deadline_minutes)) * 60
    good_since, last = None, ""
    while time.time() < deadline:
        inst = instance()
        state = containers()
        problems = []
        if "setting_up: true" in inst:
            problems.append("still setting up")
        if want_version and not re.search(rf"^version: {re.escape(want_version)}$", inst, re.M):
            problems.append("version isn't " + want_version)
        if not state:
            problems.append("no containers")
        for name, status in state:
            if name.endswith(("-init", "-prepare")) or status.startswith("Exited (0)"):
                continue
            if not status.startswith("Up") or "starting" in status or "unhealthy" in status:
                problems.append(f"{name}: {status}")
        for port in re.findall(r"^\s+port: (\d+)$", inst, re.M):
            code = vm(f"curl -s -m 20 -o /dev/null -w '%{{http_code}}' http://127.0.0.1:{port}/", check=False).strip()
            if code == "000" or code.startswith("5"):
                problems.append(f"port {port} answered {code}")
        last = "; ".join(problems)
        if problems:
            good_since = None
        elif good_since is None:
            good_since = time.time()
        elif time.time() - good_since >= SETTLE:
            return
        time.sleep(10)
    raise Failed(f"not healthy in time: {last}")


def journal():
    logs = vm("sudo journalctl _UID=$(id -u roostack) -n 40 --no-pager | cut -c1-300", check=False)
    return logs + "\n" + vm("sudo journalctl -u roostack -n 25 --no-pager | grep -v setup_code | cut -c1-300", check=False)


def step(name, fn):
    started = time.time()
    print(f"==> {name}", flush=True)
    try:
        fn()
    except (Failed, StopIteration, AttributeError, OSError) as e:
        results.append((name, "failed", time.time() - started))
        print(f"FAILED: {name}: {e!r}", flush=True)
        print(journal(), flush=True)
        return False
    results.append((name, "passed", time.time() - started))
    return True


def install(b):
    add_package(a.old or a.to)
    where, page, status = b.go(f"/install/{a.package}")
    if status != 200:
        raise Failed(f"no install page: {status} at {where}")
    action, f = next(x for x in forms(page) if x[0].startswith("/install/"))
    f.pop("sso", None)
    f["accept_risks"] = "on"
    f["data"] = f.get("data") or "afresh"
    for k in list(f):
        if not k.startswith(("setting.", "secret.")) or f[k]:
            continue
        low = k.lower()
        if "pass" in low or "secret" in low or "token" in low or "key" in low:
            f[k] = "Update-test-" + secrets.token_hex(12)
        elif "mail" in low:
            f[k] = "tester@example.com"
        else:
            f[k] = "tester"
    where, page, status = b.go(action, f)
    if status >= 400:
        raise Failed(f"the install page said: {error_of(page)}")
    wait_healthy(25)


def backup_init():
    vm(f"sudo sed -i '/^backup:/,+1d' {STATE}/lab.yaml; printf 'backup:\\n  repository: /srv/roostack/test-backup\\n' | sudo tee -a {STATE}/lab.yaml >/dev/null; sudo install -d -o roostack -g roostack /srv/roostack/test-backup; sudo systemctl restart roostack")
    time.sleep(5)
    as_roostack("roostack backup init")


def has_backup():
    with open(os.path.join(a.repo, "packages", a.package, f"{a.old or a.to}.yaml")) as f:
        return re.search(r"^(storage|databases):", f.read(), re.M) is not None


def update(b):
    add_package(a.to)
    where, page, status = b.go(f"/services/{a.package}/update", {"to": a.to, "accept_risks": "on"})
    if status >= 400 or "UpdateError" in page:
        raise Failed(f"the update page said: {status} {error_of(page)}")
    wait_healthy(25, a.to)


def restore():
    # The oldest of the service's backups: the one from before the update.
    listing = as_roostack("roostack backup snapshots")
    snapshot = re.findall(rf"^\s*([0-9a-f]{{8}})\s+\S+ \S+\s+{re.escape(a.package)}\s", listing, re.M)
    if not snapshot:
        raise Failed("no backup to restore")
    as_roostack(f"roostack backup restore {a.package} -snapshot {snapshot[0]}")
    wait_healthy(15)


def report():
    lines = [f"### Update test: {a.package} {a.old or '(new)'} → {a.to}", "", "| Step | Result | Time |", "|---|---|---|"]
    lines += [f"| {n} | {r} | {int(t // 60)}m {int(t % 60)}s |" for n, r, t in results]
    out = "\n".join(lines) + "\n"
    print(out)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write(out)


def main():
    b = Browser()
    ok = step("Sign in to a new lab", lambda: sign_in(b))
    ok = ok and step(f"Install {a.old or a.to}", lambda: install(b))
    backed = ok and has_backup()
    if backed:
        ok = step("Back up", lambda: (backup_init(), as_roostack("roostack backup run")))
    if a.old:
        ok = ok and step(f"Update to {a.to}", lambda: update(b))
    if ok and backed:
        ok = step("Restore the backup from before the update", restore)
    report()
    sys.exit(0 if ok else 1)


main()
