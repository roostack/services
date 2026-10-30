# Review: five file-sharing services (2026-10-30)

A review before any packaging: ProjectSend, Chibisafe, Zipline, Palmr, and Seafile. For each, how it would fit Roostack's package format and, above all, what it would risk for roost.ac and Roostack Cloud's edges when a lab makes it public. Nothing is packaged yet: the maintainer decides which to do, and how, from the questions at the end.

Upstream facts were checked on 2026-10-30 against each project's repository, releases, security advisories, container registry, and documentation (sources at the end, with dates). Statements marked *code-read* come from reading the source, not from running the app.

## Summary

| | Seafile CE | ProjectSend v2 | Palmr | Zipline v4 | Chibisafe |
|---|---|---|---|---|---|
| **What it is** | File sync and share (a Dropbox replacement), with desktop and phone clients | A client portal: staff send files to client accounts, with share links | WeTransfer-style transfers with "reverse shares" for outsiders to upload | A ShareX upload target: image and file host, with a URL shortener | A pomf-style file host (lolisafe's successor) |
| **Licence** | Server core AGPL-3.0 (with an OpenSSL exception), web UI Apache-2.0; Pro proprietary (free to 3 users) | GPL-2.0-or-later (also sold under a commercial licence) | v3 Apache-2.0; v4 AGPL-3.0-only | MIT | MIT |
| **Health** | A company; 13.0.28 on 2026-09-18, about monthly | One main maintainer; v2 is a rebuild from 2026-08-14, 12 releases since (2.8.0 on 2026-10-29) | **Archived** 2026-02-27; v4 an unreleased rewrite | One maintainer; 4.8.2 on 2026-10-25 | One maintainer; 6.7.0 on 2026-10-22, after 15 months without a release |
| **Advisories (2 years)** | 6 CVEs, mostly stored XSS; fixed before publication | 15 GHSAs in Sept–Oct 2026 (pre-auth account takeover through OIDC among them); v1 exploited in the wild (CISA KEV, 2024) | None filed | 25 GHSAs (unauthenticated account takeover, path traversal, an open redirect) | 1 (stored XSS through uploaded HTML/SVG, CVSS 8.6, fixed 2026-10-18) |
| **Image** | `seafileltd/seafile-mc`, amd64 and arm64 (arm64 lags; SeaDoc 2.0.10 amd64 only); root inside, runit and nginx on :80 | `projectsend/projectsend`, amd64 and arm64; root inside, nginx on :80 | `kyantech/palmr`, amd64 and arm64; root, with MinIO inside | `ghcr.io/diced/zipline`, amd64 and arm64; root | Two images (amd64 and arm64) plus the project's own Caddy |
| **Needs** | MariaDB (**three databases**), Redis | MySQL 8.4 (Roostack's pin), Redis optional | SQLite, bundled MinIO (browsers reach it directly: a second public address) | PostgreSQL (or embedded PGlite) | SQLite |
| **Single sign-on** | OAuth2 in CE (no discovery), or Remote-User; set in `seahub_settings.py`, not env | Generic OIDC with discovery, set in its admin UI only; no groups | Generic OIDC, admin UI only; links accounts by email without checking it's verified (*code-read*) | OIDC by explicit endpoints; password sign-in can't really be turned off | **None**, and upstream won't add it (2026-09-30) |
| **Backups** | Dumps first, then `conf` and `seafile-data` (Roostack's order already); `seaf-fsck` after a restore; garbage collection needed | MySQL dump plus the whole `storage/` folder (holds `APP_KEY`) | SQLite plus MinIO's own format | PostgreSQL plus uploads | SQLite (holds every setting and the signing secret) plus uploads |
| **Anonymous uploads** | Upload links (into the owner's quota) | None | Reverse shares, which skip quotas (*code-read*) | Folders with "Allow anonymous uploads" | "Public mode", off by default, one switch in its admin UI |
| **Serves uploads inline** | HTML as a download, SVG sandboxed | Only a list of safe types; the rest as downloads | **HTML and SVG inline on its own address, no CSP** (*code-read*) | Inline with the uploader's type, sandboxed since 2026-07 | Inline; safe only behind its own Caddyfile's headers |
| **Abuse risk when public** | **Medium** | **Medium** | **High** | **High** | **High** |
| **Recommendation** | **Package first**, with locked-down defaults; two Roostack questions first | **Package later** (early 2027), once v2 has settled | **Don't package**; review v4 once it's released | **Don't package** | **Don't package** |

In short: Seafile is the one worth having now. It fills a real gap (the registry has no file sync), is maintained by a company, signs nobody up by default, and lets an administrator force expiry and passwords on share links. ProjectSend is a reasonable second, but its v2 is eleven weeks old and has just had fifteen advisories. Zipline and Chibisafe exist to make uploads public on a short address, which is exactly what harms roost.ac, and Palmr is archived.

## How Roostack and Cloud shape the risk

What a file-sharing app puts at risk, from Cloud's design (DESIGN §3d, §5; RUNBOOK-ABUSE):

- **roost.ac's reputation is shared.** A phishing kit or malware on `files.smiths.roost.ac` gets listed by Google's Web Risk and the like; enough of those and mail filters and browsers start distrusting roost.ac as a whole. roost.ac on the Public Suffix List keeps cookies apart, and blocklists usually list a lab's name rather than roost.ac, but neither stops the damage to the name's standing.
- **Cloud can't see content.** The edges never decrypt, so Cloud acts on hostnames: Web Risk, reports, certificate logs, and traffic volume ("sustained heavy downloads suggest file hosting", §5). File sharing makes that volume signal noisier: a family's legitimate 4 GB share looks like a malware mirror.
- **What reaches us within hours:** phishing, malware, and child sexual abuse material, and eSafety's 24-hour removal notices. A file drop is the most likely place for all of them: someone's account or upload link is used by somebody else.
- **The registry is the gate, but a soft one.** DESIGN §5 says free roost.ac names are "only for verified services: catalog packages, not custom ones". As far as I can see (2026-10-30), nothing enforces that yet: the lab sends Cloud only hostnames (`cloudapi.RelayRequest`), and `manager.publicHostsOf` includes services from the Owner's own packages. So not packaging Zipline keeps it out of the catalog and the one-click path, not off roost.ac. That's a Cloud-side gap, listed under the questions.

What each app risks, in order of how much it matters:

1. **Anyone uploading without an account** (public mode, anonymous folders, reverse shares, upload links). The worst case: a stranger hosts malware or a phishing page under the lab's name, and the Owner never notices.
2. **Uploads served inline on the app's own address.** An uploaded HTML or SVG file renders as a page of the lab's own site: a phishing page with a valid certificate under roost.ac. Sandboxing (`Content-Security-Policy: sandbox`) or serving as a download stops it.
3. **Short links and open redirects.** A roost.ac link that redirects anywhere is a spammer's favourite way to hide a phishing address (Zipline, Chibisafe).
4. **Takeover before setup, default passwords, open sign-ups.** An app that's public before its administrator exists belongs to whoever gets there first (ProjectSend's `/setup`, Zipline's setup page, Palmr's first registrant, Chibisafe's `admin`/`admin`). Roostack's install hooks normally close this; it's listed per app below.
5. **Share links handed on.** Every app here makes download links; links without expiry outlive their purpose and spread. Admin-enforced expiry is what limits it.
6. **Copyright** (films and music shared from a lab): slower, but the same hostname suspension.

Roostack's own protections help with the attacks on the app (CrowdSec, rate limits, the WAF, nothing public until the Owner says so), not with misuse by people who are allowed in.

## Each service

### Seafile Community Edition — medium; package first

**What it is:** file sync and share with libraries, desktop sync clients (Windows, macOS, Linux) and phone apps, WebDAV, share links, and upload links. The closest thing to Nextcloud's file part, faster and narrower. Seafile Ltd develops it; 13.0 is current (13.0.28, 2026-09-18) and 14.0 is in beta (14.0.9, 2026-10-14).

**Licence:** the server core (`seafile-server`) is AGPL-3.0 with an OpenSSL exception, the web UI (`seahub`) Apache-2.0, the sync library GPL-2.0 with the same exception. Whether the AGPL is "-only" or "-or-later" isn't stated (Roostack's `about.licence` needs one: an open question). Pro is proprietary, free for up to three users; S3 storage, virus scanning, SAML, and an administrator browsing users' files are Pro only. We'd package Community Edition.

**Packaging:**

- **Image:** `seafileltd/seafile-mc:13.0.x`, multi-arch (amd64 and arm64), built on Ubuntu 24.04 with runit, cron, and nginx inside on port 80, which maps `/`, `/seafhttp`, and `/seafdav` itself, so one Roostack route is enough. It starts as root inside the container (as most registry images do; under rootless Podman that's the `roostack` user). `NON_ROOT=true` runs Seafile as uid 8000 but still starts as root; not needed with Roostack. arm64 tags arrive after amd64 ones, so a version is ready to package once its multi-arch digest exists.
- **Left out:** the official Compose file's Caddy (`caddy-docker-proxy`, which mounts the Docker socket: Roostack's Caddy replaces it). **SeaDoc** (`sdoc-server`, collaborative documents) is a separate container, and its current 2.0.10 is amd64 only: an optional part (`when:`), off at first. The notification server (WebSocket, live updates) is optional too.
- **Databases: the hard part.** Seafile needs three MariaDB databases (`ccnet_db`, `seafile_db`, `seahub_db`); SQLite went in 11.0 and PostgreSQL was never supported. Its first run creates them with the root password (`INIT_SEAFILE_MYSQL_ROOT_PASSWORD`), which Roostack never keeps, and Roostack's app user may only use its own database. Options (question 3): three `databases:` entries (three MariaDB containers, about 300 MB of memory more, as Roostack expects 150 MB each, and three dumps not taken at one moment), or a Roostack change letting one MySQL/MariaDB database give the app user more schemas of the same server. Seafile can use databases made for it (`USE_EXISTING_DB=1` in its setup script; undocumented for Docker, *code-read*), so either way needs a test.
- **Redis** as a cache (`CACHE_PROVIDER=redis`), `backup: false`.
- **Data:** `/shared` holds `seafile/conf` (configuration and `SECRET_KEY`: critical), `seafile/seafile-data` (libraries as content-addressed blocks, not plain files: critical), `seafile/seahub-data` (avatars critical, thumbnails replaceable), and logs (replaceable). Its storage goes on the `media` location (large).
- **Backups:** Seafile's guide says to dump the databases first and copy the data after, which is what Roostack does already (dumps, then restic). After a restore, `seaf-fsck` checks the libraries: an action hook ("Check the libraries"). Deleted files' blocks stay until garbage collection (`seaf-gc.sh`, online in CE since 12.0) runs; whether the image's cron runs it by itself needs checking, or storage only grows (question 7).
- **First administrator:** `INIT_SEAFILE_ADMIN_EMAIL` and `INIT_SEAFILE_ADMIN_PASSWORD`, read on the first start only, as `install_only` settings. The Compose file's defaults (`me@example.com` / `asecret`) must never be used, so the package requires them.
- **Its address:** `SEAFILE_SERVER_HOSTNAME`, `SEAFILE_SERVER_PROTOCOL`, a generated `JWT_PRIVATE_KEY`, and `CSRF_TRUSTED_ORIGINS`. Large uploads: no body-size limit for `/seafhttp` (the clients upload in blocks), long timeouts.
- **What fights the format:** most of Seafile's behaviour (share-link policy, sign-ups, OAuth) is in `seahub_settings.py`, a Python file in `conf`, not environment variables, and administrators can override much of it from the web UI (stored in the database) unless `ENABLE_SETTINGS_VIA_WEB = False`. Roostack's "config files a package declares" (SPEC §8.1, layer 3) isn't built. Until it is, an install hook would write a block of Roostack's settings into that file (marked as Roostack's, rewritten when settings change): it works but is a pattern no package uses yet (question 4). The image also edits files in its own code folder at start (`chown`, `sed`), so its root filesystem can't be read-only; nothing else in Roostack needs that.

**Single sign-on:** Community Edition has OAuth2 (`ENABLE_OAUTH`, explicit authorisation, token, and userinfo addresses, not OIDC discovery; Roostack's provider gives those addresses) and Remote-User. Both are set in `seahub_settings.py`. Unknown users are created at first sign-in (`OAUTH_CREATE_UNKNOWN_USER`); password sign-in can be refused for SSO users (`DISABLE_ADFS_USER_PWD_LOGIN`, which applies to OAuth too, *code-read*), though administrators keep theirs. No group mapping in CE. The desktop and phone clients sign in through the browser (`CLIENT_SSO_VIA_LOCAL_BROWSER`); WebDAV needs a token per person. So SSO uses an `on: sso` hook writing the OAuth block, like the other hook-configured apps.

**Abuse when public:**

- Nobody signs up by default (`ENABLE_SIGNUP = False`); the package keeps it off and doesn't offer it as a setting.
- **Upload links** let anyone with the link upload into a folder (into the owner's quota). **Share links** have optional passwords, expiry, and a download limit.
- An administrator can **enforce** link policy: a maximum and default expiry for share and upload links (`SHARE_LINK_EXPIRE_DAYS_MAX`, `UPLOAD_LINK_EXPIRE_DAYS_MAX` and their defaults), required passwords (`SHARE_LINK_FORCE_USE_PASSWORD`), and a "Report abuse" button on shared pages (`ENABLE_SHARE_LINK_REPORT_ABUSE`, in CE). The admin pages list and delete every share and upload link.
- Files are served safely: HTML as `application/octet-stream` with `nosniff`, SVG with a sandbox CSP (since CVE-2025-65516, fixed in 13.0.12). Previews stay in the web UI.
- No virus scanning in CE, and no file-type blocklist.
- No Seafile-specific abuse campaigns found. Its CVEs are mostly stored XSS, and fixes ship before publication.
- **Risk: medium.** The danger is a member's account or an upload link used by someone else, limited by expiry and the admin's view of links.

**Recommendation: package it, with locked-down defaults** (question 5 has the values): sign-ups off; share links expiring by default after 7 days and at most 90; upload links by default after 7 days and at most 30; "Report abuse" on; passwords on share links optional (the Owner's setting, off by default, since families share with family). Its address starts private, like every service. On a lab with Cloud, its page could say that share links are public through the lab's address.

### ProjectSend v2 — medium; package later

**What it is:** a client portal. Staff upload files for client accounts or groups, clients sign in to fetch them (and may upload back), and files can have share links. Useful to a small business (an accountant, a photographer), less to a family. Version 2 is a Laravel rebuild released 2026-08-14; the old app moved to `projectsend/legacy`, which linuxserver.io's image still ships.

**Licence:** GPL-2.0-or-later; also sold under a commercial licence (contributors sign a CLA), and a paid hosted edition exists. The image's label says MIT, which contradicts the project (to mention upstream).

**Health:** one main maintainer (501 of about 600 commits in the last year). Twelve releases in eleven weeks, and fifteen advisories published in September and October 2026, among them pre-auth account takeover through OIDC email matching, a trusted Entra `email` claim, a first-run setup race making several administrators, and uploads into public folders without permission. All were fixed the day they were published. In 2024, v1's CVE-2024-11680 was exploited in the wild (attackers turned sign-ups on, uploaded web shells; CISA KEV), which is the scenario that hurts a shared domain.

**Packaging:**

- **Image:** `projectsend/projectsend` (the project's own, Docker Hub), amd64 and arm64; nginx, PHP-FPM, three queue workers, and a scheduler under supervisord, as root inside, on port 80.
- **Database:** MySQL 8.0 or newer, tested on 8.4: Roostack's MySQL pin, as Ghost uses. Redis for sessions, cache, and queues (optional; `backup: false`).
- **Data:** the whole `storage/` folder is critical: uploads in `storage/app/files/`, and `storage/.env` with the generated `APP_KEY` that decrypts the SMTP, LDAP, and OAuth secrets in the database. Better: `APP_KEY` as a Roostack-generated secret in its environment. Thumbnails, previews, and zips are replaceable (a per-directory class).
- **Administrator:** `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `ADMIN_NAME` create it headless, ignored once a user exists: `install_only` settings, and `/setup` as a private path.
- **Its address:** `APP_URL`, and `TRUSTED_PROXIES` (without it, 419 errors and rate limits keyed on Caddy's address). Migrations run on every start.
- **Fights the format:** single sign-on is configured only in its admin UI (database rows, with an encrypted client secret), so it needs an `on: sso` hook through `artisan` or its API, still to find. An "AI assistant" (MCP) connector is on by default since 2.8.0; the package should turn it off, if it can from outside the UI.

**Single sign-on:** generic OIDC with discovery (good), but no group or role mapping: people it creates are always clients, never staff. Since 2.8.0 staff can be made to sign in through one provider; clients keep passwords.

**Abuse when public:** no anonymous uploads; sign-ups and auto-approval off by default; share links (`/s/<token>`) with expiry and a download limit but no password, rate-limited; an extension allow-list for every uploader that leaves out HTML and SVG; only a list of safe types served inline, the rest as downloads, from outside the web root; full activity and download logs; optional ClamAV (another container of about 1–1.5 GB; it lets files through unscanned when it's down). Sign-ups and public groups are settings in its database, which an administrator can turn on; Roostack can't hold them off.

**Risk: medium.** The design is right for public use; its youth and recent advisories are the worry.

**Recommendation: package later.** Look again in early 2027 (say February), after a quiet stretch with no high-severity advisories, packaged like Seafile: sign-ups off, the AI connector off, `/setup` private.

### Palmr — high; don't package

**What it is:** a WeTransfer-style service: uploads with share links, and "reverse shares" letting outsiders upload to you.

**Why not:**

- **Archived:** its README says so since 2026-02-27 (a solo developer without enough sponsors); the last release is 3.3.2-beta (2025-12-10), and every release was a beta.
- **v4** is a Rust rewrite on a branch (since 2026-09-24), not released, "not yet ready for production use", with no migration from v3.
- **v3 serves uploads inline on its own address:** HTML as `text/html` and SVG with `inline`, no CSP or `nosniff`, and a public `/e/<id>` embed address with a year's cache (*code-read*). That's a phishing page under the lab's name for anyone with a reverse-share link.
- **Reverse shares skip the owner's quota and size limits** until a file is copied into the owner's files, and trust the size the uploader declares (*code-read*). Files from an expired share without a password may still download by their direct address (*code-read*, not tried).
- The first person to register becomes its administrator; SSO links an account by email without checking it's verified (*code-read*).
- **Packaging:** root, supervisord, a MinIO inside the image that browsers must reach at a second public address (`STORAGE_URL`), and the schema synced with `prisma db push` on every start, without migrations.

**Recommendation: don't package v3.** v4 looks like a good fit on paper (AGPL-3.0-only, a non-root distroless image, SQLite, local or S3 storage, a documented backup with `VACUUM INTO`): review it once it's released, as a candidate for "transfers" if Seafile's links aren't enough.

### Zipline v4 — high; don't package

**What it is:** a ShareX/Flameshot upload target: screenshots and files get short public addresses (`/u/<name>`, or from the root), plus a URL shortener, embeds for Discord, and pastes.

**Why not:**

- **Its purpose is public hot-linkable hosting:** every upload is meant to be posted somewhere. Kept private it's pointless; public, it's an image and file host under roost.ac.
- **The URL shortener redirects to any http(s) address** (an open-redirect advisory was fixed in 4.5.0 by checking the scheme only). Short links on roost.ac redirecting to phishing are what Web Risk lists.
- **Anonymous uploads:** a folder can "Allow anonymous uploads", counted against its owner's quota.
- **Files are served inline with the uploader's MIME type** unless `FILES_ASSUME_MIMETYPES=true`; sandboxed since 2026-07, and the extension blocklist didn't work at all before 4.8.0.
- **25 advisories in two years** from one maintainer, including unauthenticated account takeover (2026-01), path traversal reading and writing files (three times), and stored XSS (twice).
- **Setup is open to whoever reaches it first,** with no environment variable to create the administrator; local password sign-in can't really be turned off (the SSO redirect is client-side only, `?local=true` brings the form back).

**Recommendation: don't package.** If it's ever wanted, only as private (home network), which Roostack has no way to enforce for a registry package (question 1).

### Chibisafe — high; don't package

**What it is:** lolisafe's successor, a pomf-style file host: every upload gets a public direct link, with albums, snippets, and a URL shortener.

**Why not:**

- **Every upload is a public link by design,** and **public mode** (uploads without an account) is one switch in its admin UI, stored in its database, beyond Roostack's reach.
- **The URL shortener takes any destination** (an unchecked string, *code-read*).
- **HTML and SVG uploads are allowed;** they're safe only behind the project's own Caddyfile, which adds a sandbox CSP since 6.6.0 (2026-10-18, after a CVSS 8.6 stored XSS). Packaging it means running a second Caddy inside the service, or copying those headers into Roostack's.
- **No single sign-on, and none coming** (issue #566, closed as not planned on 2026-09-30).
- **The first administrator's password falls back to `admin`** when none is given (`Util.ts`).
- One maintainer, 15 months without a release before October 2026, a backend that runs as root, and an unverified claim of malware in the repository (issue #566, 2026-10-12) that would need looking into first.
- No virus scanning, though it has good moderation tools (quarantine, IP bans, the uploader's address on each file).

**Recommendation: don't package.**

## Overlap

- **With each other:** Seafile's share and upload links cover most of what ProjectSend, Palmr, and Zipline's folders do for a lab: send a file, receive a file. ProjectSend's client accounts are the one thing Seafile doesn't do well (clients without a library of their own), and it matters to businesses, not families. Zipline and Chibisafe are the same niche (screenshot hosting), the riskiest one.
- **With the registry:** nothing does file sync today. Immich (shared albums and links) and Lychee (public albums) already share photos publicly; Papra and Paperless-ngx keep documents and don't share them publicly. Nextcloud isn't in the registry; Seafile would be the lighter choice, and Nextcloud's files (if it ever comes) would overlap it entirely.

**Order:** Seafile CE first; ProjectSend v2 in early 2027 if anyone asks for client portals; Palmr v4 when it's released, in place of ProjectSend if it's the better transfer service by then. Not Zipline or Chibisafe.

## Roostack and Cloud changes

**Needed for the recommended packages:**

1. **Seafile's three databases** (question 3): either nothing (three MariaDB containers) or a small change to the `mariadb`/`mysql` types: extra schemas for the same app user on the same server, dumped together. I'd recommend the change: one container instead of three, one consistent dump, and other PHP and Python apps need it too.
2. **A settings file written by a hook** (question 4) until "config files a package declares" exists: a package convention, not a Roostack change, but a first.

**Worth doing, not blocking Seafile:**

3. **"Only shared links public"** (question 2): a third choice besides Private and Public for routes whose package lists share-link paths (Seafile's `/d/`, `/f/`, `/u/`, and the `/seafhttp` paths they use). The app's sign-in and UI stay private (or behind the lab's sign-in, through the `forward_auth` wall that already exists when single sign-on is on), while the people a link was sent to can open it. It removes the sign-in page and every pre-auth bug from the internet, which for a family is all they want public. I'd make it the recommended choice for file-sharing packages, once Seafile's package shows which paths it needs.
4. **Enforcing "free roost.ac names only for verified services"** (DESIGN §5, Cloud): the lab could tell Cloud which hostnames are registry packages (name and tier) in its relay request and name claims, so the rule applies: a service from the Owner's own package goes only on the Owner's domain. A changed Roostack could lie, so it's a default for honest labs, not a guarantee; the outside checker and Web Risk remain the real checks. Without it, the registry's choices here don't keep Zipline off roost.ac.

**Not needed now:** a package flag that refuses public access or the relay (needed only if we packaged Zipline or Chibisafe, which I'd rather not), and Caddy adding sandbox headers to "user content" paths (Seafile and ProjectSend already serve safely).

## Questions for the maintainer

1. **Which to do:** Seafile CE now, ProjectSend v2 in early 2027, Palmr v4 when released, and not Zipline or Chibisafe? (Recommended.) Or package Zipline as private only, which needs a new package flag first?
2. **"Only shared links public"** for Seafile: build it in Roostack (my recommendation, after Seafile's first package), or leave Seafile with Private and Public only?
3. **Seafile's databases:** extra schemas on one MariaDB (recommended, a Roostack change), or three MariaDB containers (no change, about 300 MB more, dumps not taken together)?
4. **Seafile's settings file:** an install hook writing Roostack's block into `seahub_settings.py` (recommended for now), or wait for "config files a package declares"? And should administrators keep changing settings from Seafile's web UI (`ENABLE_SETTINGS_VIA_WEB`), which can undo the package's link policy? I'd turn it off, so that the policy follows Roostack's settings.
5. **Seafile's link policy defaults:** share links expire after 7 days by default and 90 at most, upload links 7 and 30, passwords optional, "Report abuse" on. Different numbers, or passwords required?
6. **Seafile's licence:** AGPL-3.0 "-only" or "-or-later" isn't stated, and Roostack needs one. Ask upstream, or read it as "-only" (the conservative reading) with the reason in a comment?
7. **Seafile's garbage collection:** if the image doesn't run it by itself, a weekly action hook the Owner presses, or a scheduled hook (which Roostack doesn't have yet)?
8. **Cloud:** enforce "verified services only" for free roost.ac names (item 4 above), and count bytes per hostname at the edges so that a file share's heavy use can be told from a lab hosting files for others?

## Sources

All read 2026-10-30 unless a date is given.

**Roostack and Cloud:** Roostack's SPEC.md §5.2, §6.8, §6.11, §8.1, §8.3.4; `cloudapi/cloudapi.go` (`RelayRequest`); `internal/manager/edge.go` (`publicHostsOf`); Roostack Cloud's docs/DESIGN.md §3d, §3f ("abuse intake", 2026-10-19), §5; docs/RUNBOOK-ABUSE.md (2026-10-19).

**Seafile:**
- Licences: https://github.com/haiwen/seafile-server, https://github.com/haiwen/seahub, https://github.com/haiwen/seafile (LICENSE files)
- Releases: https://plus.seafile.com/wiki/publish/seafile-wiki/5L80/ (13.0.28, 2026-09-18; 14.0.9 beta, 2026-10-14)
- Images: https://hub.docker.com/r/seafileltd/seafile-mc, https://hub.docker.com/r/seafileltd/sdoc-server (2.0.10, 2026-10-24, amd64 only)
- Image build: https://github.com/haiwen/seafile-docker (`image/seafile_13.0/Dockerfile`, `scripts/scripts_13.0/enterpoint.sh`)
- Manual: https://github.com/haiwen/seafile-admin-docs — `manual/setup/setup_pro_by_docker.md` (Pro free to 3 users), `manual/upgrade/upgrade_notes_for_11.0.x.md` (SQLite dropped), `manual/administration/backup_recovery.md` (commit of 2025-10-20), `manual/config/oauth.md` (2024-11-12), `manual/config/seahub_settings_py.md`, `manual/config/csp_configuration.md` (2026-04-25), `manual/setup/use_other_reverse_proxy.md`
- Code: seahub 13.0 `seahub/settings.py`, `seahub/oauth/views.py`, `seahub/utils/auth.py`; seafile-server `fileserver/fileop.go`
- CVEs: NVD, CVE-2025-45091 (2025-09-15), CVE-2025-41079 and CVE-2025-41080 (2025-12-04), CVE-2025-65516 (2025-12-04; fixed in 13.0.12, 2025-10-24), CVE-2026-30587 (2026-03-25; fixed in 13.0.17), CVE-2026-56768 (2026-06-25)

**ProjectSend:**
- https://github.com/projectsend/projectsend: releases (2.0.0 on 2026-08-14 to 2.8.0 on 2026-10-29), `LICENSING.md`, `INSTALL.md`, `DOCKER.md`, `docker/production/Dockerfile`, `compose.example.yaml`, `app/Modules/Platform/Settings/Setting.php`
- Advisories: https://github.com/projectsend/projectsend/security/advisories (11 on 2026-09-11, 4 on 2026-10-07)
- Legacy: https://github.com/projectsend/legacy; https://github.com/linuxserver/docker-projectsend (switched to legacy, 2026-08-10)
- Image: https://hub.docker.com/r/projectsend/projectsend (2.8.0, 2026-10-29)
- v1 exploitation: https://www.vulncheck.com/blog/projectsend-exploited-itw, https://censys.com/cve-2024-11680/ (CVE-2024-11680, CISA KEV, December 2024)

**Palmr:**
- https://github.com/kyantech/Palmr: README on `main` (archived 2026-02-27), releases (3.3.2-beta, 2025-12-10), the `v4` branch (2026-09-24 to 2026-10-16)
- Code on `main`: `apps/server/src/modules/file/controller.ts`, `apps/server/src/utils/mime-types.ts`, `apps/web/src/app/e/[id]/route.ts`, `infra/supervisord.conf`, `docker-compose.yaml`
- Image: https://hub.docker.com/r/kyantech/palmr (3.3.2-beta, 2025-12-10)

**Zipline:**
- https://github.com/diced/zipline: releases (4.8.2, 2026-10-25), `src/server/routes/api/upload/index.ts` (anonymous folder uploads), `src/lib/api/contentSecurity.ts`
- Advisories: https://github.com/diced/zipline/security/advisories (25 since 2024-10)
- Docs, read from https://github.com/diced/zipline-docs (branch `v4.1`, 2026-10-26; the docs site refuses automated readers): `guides/hardening.mdx`, `guides/oauth/index.mdx`, `config/core.mdx`, `guides/releases.mdx`
- Image: `ghcr.io/diced/zipline`

**Chibisafe:**
- https://github.com/chibisafe/chibisafe: releases (6.7.0, 2026-10-22; 6.5.5, 2025-07-05), `packages/backend/src/structures/settings.ts`, `packages/backend/src/utils/Util.ts` (the `admin` fallback), `packages/backend/src/routes/links/CreateLink.ts`, `docker-compose.example.yml`, `docker/DockerfileServer`
- Advisory: https://github.com/chibisafe/chibisafe/security/advisories/GHSA-7hmq-gf2f-c9c9 (2026-10-18)
- No SSO: https://github.com/chibisafe/chibisafe/issues/566 (closed 2026-09-30; the malware claim, 2026-10-12)
- lolisafe's history: https://wiki.archiveteam.org/index.php/Safe.moe
