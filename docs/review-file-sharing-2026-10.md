# Review: file-sharing services (2026-10-30)

A review before packaging: first ProjectSend, Chibisafe, Zipline, Palmr, and Seafile, then the alternatives the maintainer asked about, for a generic file-sharing app. For each: how it fits Roostack's package format and what it risks for roost.ac and Roostack Cloud's edges when a lab makes it public. The maintainer's decisions of 2026-10-30 are first; the plan to build them follows the assessment.

Upstream facts were checked on 2026-10-30 against each project's repository, releases, security advisories, container registry, and documentation (sources at the end, with dates). Statements marked *code-read* come from reading the source, not from running the app.

## Decisions (the maintainer, 2026-10-30)

- **No app is too risky to offer: it's the Owner's lab.** What we limit is what reaches roost.ac and our edges. Apps that are a risk to us as a service provider are offered, but their addresses stay private while they'd use a roost.ac name or the relay, unless the account has been approved (by asking support, or another measure later).
- **The hard rule: uploads must never be shown as a web page on the app's address.** Uploading is one thing, a phishing page another. An app that lets anyone upload must serve HTML (and SVG, which can carry scripts) as a download, refuse it, or sandbox it.
- **Copyright and big files aren't a reason to refuse an app:** anyone can host a film on Immich already. The abuse page handles it.
- **Packages: Seafile and ProjectSend.** Palmr is out (unmaintained). ProjectSend is maintained (2.8.0, 2026-10-29), and its September advisories were part of the wave that hit PHP apps, so they aren't held against it.
- **Seafile's three databases:** a Roostack change, extra schemas for the same app user on one MariaDB.
- **Seafile's settings file:** the strategic route, Roostack's "config files a package declares" (SPEC §8.1, layer 3), not a hook. `ENABLE_SETTINGS_VIA_WEB` off for now.
- **Seafile's link defaults:** share links expiring after 7 days by default and 90 at most, upload links 7 and 30, passwords optional, "Report abuse" on. Each is a setting the Owner can change.
- **Seafile's licence:** read conservatively, as AGPL-3.0-only.
- **"Only shared links public":** to build.
- **Free roost.ac names only for registry packages:** to build, as an option, also covering registry packages flagged as not to be made public through roost.ac without approval.
- **Takeover before setup:** keep addresses private until setup has finished.
- **Cloud's checks:** Cloud can't see content, but it can see public services, so the outside checker should recognise apps that host anything uploaded, and pages that shouldn't be there.
- **The generic file-sharing app: Pingvin Share X.** Chibisafe isn't packaged.
- **Plik and Gokapi too:** Plik at once, since it needs nothing new from Roostack (`packages/plik/1.4.3-roostack.1.yaml`), and Gokapi once config files and public-after-setup exist.
- **Scheduled hooks** in the package format, for Seafile's garbage collection and whatever else needs a routine (build plan, item 5).

## Which apps show uploaded HTML (question 2)

"Shown" means an uploaded `.html` (or script-capable `.svg`) opens as a page on the app's own address. A **sandbox** (`Content-Security-Policy: sandbox`) still shows the page, but without scripts and with forms that can't be sent, so it can't collect a password; it can still show a lure with a link out. **nosniff** stops browsers guessing that a download is a page.

| App | As shipped | Can the package stop it? |
|---|---|---|
| **Seafile CE** | No: HTML is a download (`application/octet-stream`, nosniff); SVG sandboxed | Already safe |
| **ProjectSend v2** | No: an allow-list of extensions leaves out HTML and SVG; only safe types shown | Already safe |
| **Zipline v4** | **Yes, sandboxed**: served with the uploader's own type, sandbox and nosniff since 4.6.4 (2026-07-06) | **Yes, enforced:** `FILES_DISABLED_TYPES` and `FILES_ASSUME_MIMETYPES` from the environment override its dashboard and lock it there (`src/lib/config/read`). HTML is then refused |
| **Chibisafe** | **Yes, sandboxed only by its own Caddyfile** (6.6.0, 2026-10-18); `.html` and `.svg` allowed | Partly: its blocklist is a database setting a hook can set, but its administrator can undo it |
| Palmr v3 | **Yes, unsandboxed**, no nosniff (*code-read*) | No; out anyway |
| Pingvin Share X | Sandboxed, with nosniff, for everything but audio, video, plain images, and text | Already acceptable |
| Plik | Sandboxed with a strict CSP, nosniff, `form-action 'none'` | Already safe |
| Gokapi | Sandboxed, no nosniff | Acceptable; nosniff to add in Caddy |
| SFTPGo | No: always a download (since 2.7.3) | Already safe |
| OpenCloud | No: download, nosniff, strict CSP | Already safe |
| Sharry | **Yes, unsandboxed** (inline, its detected type, no CSP) | Only by Caddy headers |
| FileBrowser Quantum | **Yes**, with scripts off (`script-src 'none'`) but not sandboxed: forms work | Only by Caddy headers |
| copyparty | **Yes** by default | Yes: `--no-html` |
| Filestash | **Yes** (its CSP allows scripts from its own address) | No |

**Recommendation:** a package passes when uploaded HTML is a download or refused, or, where the app gives no way to do that, sandboxed with nosniff. Where the app can refuse HTML from the environment (Zipline), the package does. And Roostack's Caddy should be able to enforce it, whatever the app's settings: change 7 in the build plan.

## Each service

### Seafile Community Edition — package

**What it is:** file sync and share with libraries, desktop sync clients (Windows, macOS, Linux), phone apps, WebDAV, share links, and upload links. Seafile Ltd develops it; 13.0 is current (13.0.28, 2026-09-18) and 14.0 is in beta (14.0.9, 2026-10-14).

**Licence:** the server core (`seafile-server`) is AGPL-3.0 with an OpenSSL exception (read as `AGPL-3.0-only`, the maintainer's choice), the web UI (`seahub`) Apache-2.0, and the sync library GPL-2.0 with the same exception. Pro is proprietary, free for up to three users; S3 storage, virus scanning, SAML, and an administrator browsing users' files are Pro only. We'd package Community Edition.

**Packaging:**

- **Image:** `seafileltd/seafile-mc:13.0.x`, multi-arch, built on Ubuntu 24.04 with runit, cron, and nginx inside on port 80, which maps `/`, `/seafhttp`, and `/seafdav` itself, so one Roostack route is enough. It starts as root inside the container, as most registry images do (under rootless Podman that's the `roostack` user). arm64 tags arrive after amd64 ones, so a version is ready to package once its multi-arch digest exists.
- **Left out:** the official Compose file's Caddy (`caddy-docker-proxy`, which mounts the Docker socket: Roostack's Caddy replaces it). **SeaDoc** (`sdoc-server`, collaborative documents) is a separate container whose current 2.0.10 is amd64 only: an optional part (`when:`), off at first. The notification server (live updates over WebSocket) is optional too.
- **Databases:** three MariaDB databases (`ccnet_db`, `seafile_db`, `seahub_db`) for one user, on one server: build plan, change 2. Seafile can use databases made for it (`USE_EXISTING_DB=1` in its setup script, undocumented for Docker, *code-read*), to test.
- **Redis** as its cache (`CACHE_PROVIDER=redis`), `backup: false`.
- **Data:** `/shared` holds `seafile/conf` (configuration and `SECRET_KEY`: critical), `seafile/seafile-data` (libraries as content-addressed blocks, not plain files: critical), `seafile/seahub-data` (avatars critical, thumbnails replaceable), and logs (replaceable), on the `media` location.
- **Backups:** Seafile's guide says to dump the databases first and copy the data after, which is Roostack's order already. After a restore, `seaf-fsck` checks the libraries: an action hook ("Check the libraries").
- **Garbage collection (question 7):** Seafile keeps files as blocks shared between versions. Deleting a file, or its old versions expiring, doesn't free the disk until garbage collection runs (`seaf-gc.sh`, online since 12.0). The image's cron runs only log rotation (`scripts_13.0/enterpoint.sh`); garbage collection is a script someone runs (`/scripts/gc.sh`). Without it, Seafile's storage only grows. Options in the questions.
- **First administrator:** `INIT_SEAFILE_ADMIN_EMAIL` and `INIT_SEAFILE_ADMIN_PASSWORD`, read on the first start only, as `install_only` settings. The Compose file's defaults (`me@example.com` / `asecret`) are never used: the package requires them.
- **Its address:** `SEAFILE_SERVER_HOSTNAME`, `SEAFILE_SERVER_PROTOCOL`, a generated `JWT_PRIVATE_KEY`, and `CSRF_TRUSTED_ORIGINS`. No body-size limit for `/seafhttp` (the clients upload in blocks), long timeouts.
- **Settings:** `seahub_settings.py` (Python, in `conf`) through Roostack's config files (change 1), with `ENABLE_SETTINGS_VIA_WEB = False` so the web UI can't override them. The image edits its own code folder at start (`chown`, `sed`), so its root filesystem can't be read-only.

**Single sign-on:** Community Edition has OAuth2 (`ENABLE_OAUTH`, with explicit authorisation, token, and userinfo addresses rather than OIDC discovery) and Remote-User, both set in `seahub_settings.py`, so through the config file too. Unknown users are created at first sign-in; password sign-in can be refused for SSO users (`DISABLE_ADFS_USER_PWD_LOGIN`, which applies to OAuth too, *code-read*), though administrators keep theirs. No group mapping in CE. The clients sign in through the browser (`CLIENT_SSO_VIA_LOCAL_BROWSER`); WebDAV needs a token per person.

**Abuse when public:** nobody signs up (`ENABLE_SIGNUP = False`, kept off). Upload links let anyone with the link upload into a folder, within the owner's quota; share links have optional passwords, expiry, and a download limit. The package enforces the link policy above (`SHARE_LINK_EXPIRE_DAYS_DEFAULT` and `_MAX`, `UPLOAD_LINK_EXPIRE_DAYS_DEFAULT` and `_MAX`, `ENABLE_SHARE_LINK_REPORT_ABUSE`), and the admin pages list and delete every link. Uploaded HTML is never shown (above). No virus scanning in CE. **Risk to us: medium.** No approval needed.

**Its settings (question 5):** the four numbers are the days: share links 7 by default and 90 at most, upload links 7 and 30. Each is a Roostack setting (`type: int`) on the service's Settings page, with "Require passwords on share links" (off) and "Show a Report abuse button" (on); saving rewrites the config file and restarts Seafile.

### ProjectSend v2 — package

**What it is:** a client portal: staff upload files for client accounts or groups, clients sign in to fetch them and may upload back, and files can have share links. Version 2 is a Laravel rebuild released 2026-08-14 (2.8.0 on 2026-10-29); the old app moved to `projectsend/legacy`, which linuxserver.io's image still ships.

**Licence:** GPL-2.0-or-later, also sold under a commercial licence (contributors sign a CLA). The image's label says MIT, which contradicts the project (to mention upstream).

**Packaging:**

- **Image:** `projectsend/projectsend` (the project's own), amd64 and arm64; nginx, PHP-FPM, three queue workers, and a scheduler under supervisord, as root inside, on port 80.
- **Database:** MySQL 8.0 or newer, tested on 8.4: Roostack's MySQL pin, as Ghost uses. Redis for sessions, cache, and queues (`backup: false`).
- **Data:** the whole `storage/` folder is critical: uploads in `storage/app/files/` and `storage/.env`, whose `APP_KEY` decrypts the SMTP, LDAP, and OAuth secrets in the database. Better: `APP_KEY` as a generated Roostack secret. Thumbnails, previews, and zips are replaceable.
- **Administrator:** `ADMIN_EMAIL`, `ADMIN_PASSWORD`, and `ADMIN_NAME` create it headless, ignored once a user exists: `install_only` settings, and `/setup` as a private path.
- **Its address:** `APP_URL`, and `TRUSTED_PROXIES` (without it, 419 errors and rate limits keyed on Caddy's address). Migrations run on every start.
- **Single sign-on:** generic OIDC with discovery, but configured only in its admin UI (database rows, the client secret encrypted with `APP_KEY`), so an `on: sso` hook through `artisan` or its API, still to find. No group mapping: people it creates are always clients, never staff; since 2.8.0 staff can be made to sign in through one provider.
- An "AI assistant" (MCP) connector is on by default since 2.8.0: off in the package, if it can be from outside the UI.

**Abuse when public:** no anonymous uploads; sign-ups and auto-approval off by default; share links (`/s/<token>`) with expiry and a download limit but no password, rate-limited; uploaded HTML never shown (above); full activity and download logs; optional ClamAV (another container of about 1–1.5 GB). Sign-ups and public groups are settings in its database that an administrator can turn on. **Risk to us: medium.** No approval needed.

### Zipline v4 — package, with approval for roost.ac

**What it is:** a ShareX/Flameshot upload target: screenshots and files get short public addresses (`/u/<name>`), plus a URL shortener, Discord embeds, and pastes. MIT; one maintainer; 4.8.2 on 2026-10-25.

**Why it's a risk to us:** its purpose is public, hot-linkable hosting. A folder can "Allow anonymous uploads" (counted against its owner's quota), and short links redirect to any http(s) address, a spammer's favourite way to hide a phishing address behind roost.ac. It has had 25 advisories in two years, including unauthenticated account takeover (2026-01) and path traversal (three times), all fixed the day they were published.

**What the package can enforce,** since its environment overrides and locks the dashboard's settings: HTML and SVG refused (`FILES_DISABLED_TYPES`, `FILES_ASSUME_MIMETYPES=true`), no sign-ups (`FEATURES_USER_REGISTRATION=false`), and SSO by explicit OIDC addresses. The shortener's links (`/go`, `URLS_ROUTE`) can be a private path the Owner opens if they want it public. The first administrator: an install hook posting to `/api/setup`, as Papra's hook signs up, with the address private until it has (change 3). Password sign-in can't really be turned off (the SSO redirect is client-side only).

**Packaging:** `ghcr.io/diced/zipline`, multi-arch, root inside, port 3000; PostgreSQL; uploads in `/zipline/uploads` (thumbnails among them, replaceable in principle but in the same folder).

**Risk to us: high.** Flagged in the registry as needing approval for roost.ac and the relay (change 6).

### Chibisafe — not packaged

Every upload is a public link by design, "public mode" (uploads without an account) is a switch in its admin UI, its URL shortener takes any destination, HTML is sandboxed only by the project's own Caddyfile, it has no single sign-on and won't (issue #566, closed 2026-09-30), and the first administrator's password falls back to `admin` (`Util.ts`). One maintainer, 15 months without a release before October 2026. It's the same niche as Zipline, with less a package can enforce. **Not packaged** (the maintainer, 2026-10-30).

### Palmr — removed

Archived on 2026-02-27; v4 is an unreleased rewrite. Out, as the maintainer decided.

## A generic file-sharing app: the alternatives

The maintainer wants a generic file-sharing app: someone signs in, uploads, and sends a link; ideally also a "file request" link for someone else to upload to them. Seafile does this inside a sync product, and ProjectSend inside a client portal; neither is the simple WeTransfer-style app. Surveyed 2026-10-30:

| App | Licence | Health | Image | Data | SSO | Uploaded HTML | Fit |
|---|---|---|---|---|---|---|---|
| **Pingvin Share X** | BSD-2-Clause | 2.1.0 (2026-10-25); one main maintainer; 9 advisories in 2026, fixed quickly | Multi-arch; root, drops to a user | SQLite, files on disk | Generic OIDC with discovery, admin role from a claim | Sandboxed, nosniff | **Best fit**: shares with expiry, password, visitor limit; reverse shares; admin maximum expiry and size |
| **Plik** | MIT | 1.4.3 (2026-10-21); two maintainers; no advisories | Multi-arch, non-root | PostgreSQL, MySQL, or SQLite; files on disk | Generic OIDC with discovery | Strict sandbox | Easiest to package (every setting an env var), but **no file requests** |
| **SFTPGo** | AGPL-3.0 (Enterprise edition apart) | 2.7.6 (2026-09-19); one maintainer, monthly | Multi-arch, non-root | PostgreSQL, MySQL, or SQLite; files on disk | OIDC by env, but users must exist first | Always a download | A file server: share and upload-only links, admin-enforced maximum expiry; less friendly for a family |
| **Gokapi** | AGPL-3.0 | 2.2.4 (2026-03-10), active | Multi-arch; root | SQLite; files on disk | OIDC with discovery, set in its setup wizard | Sandboxed, no nosniff | Good, but its setup page is open to anyone until configured, and its config is written by the wizard |
| Erugo | MIT | Stalled since 2026-01, after a critical RCE | | | | Download | No |
| Pingvin Share | | **Archived** 2025-06-29 (Pingvin Share X is the fork) | | | | | No |
| PsiTransfer, PicoShare, Send, Enclosed, Jirafeau, Lufi | | | | | **No accounts or OIDC** | | No: a shared password at most |
| Sharry, FileBrowser Quantum, Filestash | | | | | | **Shown as pages** | No, unless Roostack's Caddy sandboxes them |
| File Browser | | **Archived** 2026-09-01 | | | | | No |
| Cloudreve | GPL-3.0, OIDC Pro only | | | | | | No |
| DumbDrop, transfer.sh | | Stale, or critical advisories | | | | | No |

**For sync, the one serious alternative to Seafile is OpenCloud** (Apache-2.0, OpenCloud GmbH, 9.0.0 rolling on 2026-10-27, 7.2.4 stable): a non-root image, no database, files kept as plain folders on disk (PosixFS), OIDC set entirely by environment variables, desktop and phone clients, downloads never shown as pages. It would need neither Roostack change Seafile needs. Against it: its clients need fixed public client IDs at the lab's sign-in provider; a consistent backup needs it stopped or a filesystem snapshot, and its metadata lives in extended attributes (restic keeps them, to verify on restore); no maximum link expiry found. ownCloud Infinite Scale is the same design under an EULA that forbids redistributing its builds, and Nextcloud is much heavier.

**Chosen (the maintainer, 2026-10-30):**

- **Pingvin Share X as the generic file-sharing app.** It's the WeTransfer-style app with file requests, safe serving, and OIDC with roles. Its settings are a YAML file (`config.yaml`, which makes its admin UI read-only), so it builds on the same config files as Seafile: sign-ups off (`allowRegistration: false`, on by default upstream), the administrator from `initUser`, a maximum expiry and size. Risk to us: medium (file requests let outsiders upload, but nothing is shown as a page). Plik is the fallback if its advisories keep coming.
- **Stay with Seafile for sync, as decided.** OpenCloud fits Roostack's format better and keeps plain files, but Seafile's backups are consistent without stopping it, and the two Roostack changes it needs are wanted anyway. If Seafile's package stalls, OpenCloud is next.

## Overlap

- **Seafile** (sync), **Pingvin Share X** (send and receive files), and **ProjectSend** (a portal for clients) each have one job. Zipline is screenshot hosting.
- **With the registry:** nothing else does file sync or transfers. Immich and Lychee already share photos publicly; Papra and Paperless-ngx keep documents and don't share them.

## The build plan

Roostack (open source) first, since every package needs some of it. Each item is one session with its own branch, apart from the others unless it says so.

**Roostack:**

1. **Config files a package declares** (SPEC §8.1, layer 3, agreed 2026-10-18; strategic, the maintainer's choice): a package names files inside its own storage that Roostack writes from templates of its settings, and rewrites when they change, with a restart. For Seafile's `seahub_settings.py` and Pingvin Share X's `config.yaml`. Editing in the browser (Home Assistant, Frigate) can follow; for these two, Roostack writes the whole file.
2. **Extra schemas on one MySQL/MariaDB** for the same app user, dumped and restored together (Seafile's three).
3. **Public addresses wait for setup:** a service's public addresses stay private until its install hooks have succeeded, for every package. Closes takeover before setup (ProjectSend's `/setup`, Zipline's setup page).
4. **"Only shared links public":** a third choice beside Private and Public for routes whose package lists share-link paths. The app's sign-in and pages stay private (or behind the lab's sign-in when single sign-on is on); the people a link was sent to can open it.
5. **Scheduled hooks** (the maintainer, 2026-10-30), for Seafile's garbage collection first. Proposed design:

   ```yaml
   hooks:
     - on: schedule
       name: free-space            # in URLs and the service's history
       title: Free up space
       description: Removes blocks that no file or version uses any more.
       container: app
       every: week                 # day, week, or month
       timeout: 2h                 # optional; 1 hour when not given
       command: [/scripts/gc.sh]
   ```

   - **Roostack picks the time:** within the lab's maintenance window, after the nightly backup (SPEC §3.2's coordinator runs it, so it never overlaps a backup's prepare step, a restore, or an update of the same service), spread so that services' routines don't all start at once. Considered: a cron expression in the package (every package would pick 03:00, and the coordinator couldn't place it).
   - **A missed run happens at the next window** (the server was off); never two at once for one hook.
   - **Only while the service runs:** skipped while it's stopped, stopped by the registry, or waiting for its install hooks.
   - **Seen:** each run in the service's history (started, finished, how long, its log); on the service page, "Free up space: weekly, last ran Sunday 02:14", with **Run now**; two failures in a row go under "Needs attention", with **Try again**.
   - **Like other hooks:** a command in one of the service's containers, values only as environment variables and secrets, no inputs; checked by the same policy. Packages using it need the Roostack release that has it (`requires.roostack`).
6. **The lab tells Cloud what each public address is** (with Cloud's change 8): the package, whether it's from the registry or the Owner's own, and the registry's flag; and, when Cloud says an address needs approval, it stays private with the reason and how to ask, on the service's page and in the attention list. A package of the Owner's own on their own domain, without the relay, is untouched.
7. **Caddy enforcing the HTML rule:** routes may list the paths that serve uploads, and Caddy adds `Content-Security-Policy: sandbox` and nosniff there, whatever the app does (and serves HTML and SVG as downloads, if Caddy can match on the response's type: to check).

**The registry:**

- A flag in `registry.yaml` (kept by the registry's maintainers, so a package's author can't remove it, and it can change without a new version): `roost_ac: approval`, with a reason. Zipline gets it.

**Cloud** (private; within its launch):

8. **Free roost.ac names only for registry packages, and flagged packages only for approved accounts:** two options in `admin.yaml`, on by default; an account's approval in the admin console (support role, with a note, audited); `zone_records()` and `relay_routes()` leave out what isn't allowed, and the lab's check-in says why. A changed Roostack could lie about its packages, so this is the default for honest labs, and the checker is the real check.
9. **The outside checker recognises apps:** it already plans to check that "the expected app answers"; it would also recognise known upload hosts (Zipline, Chibisafe, and the like, by their pages), compare what answers with the package the lab declared (DESIGN §5's open question), and look for phishing pages.

**Packages** (this repository), each once its Roostack pieces are released:

- **Plik:** needs nothing new; packaged 2026-10-30 (below).
- **ProjectSend:** needs 3; nothing else new.
- **Gokapi:** needs 1 (its `config.json`, salts included) and 3 (its setup page is open to anyone until it's run).
- **Seafile:** needs 1, 2, and 5; 4 later.
- **Pingvin Share X:** needs 1.
- **Zipline:** needs 3 and 6, and Cloud's 8.

### Plik 1.4.3: what the package does, and what was checked

- **One container** (`rootgg/plik`, non-root, multi-arch), every setting from `PLIKD_` environment variables: uploads need an account (`FeatureAuthentication=forced`); files up to 10 GB, matching the route's body limit (Plik takes each file in one request); shares last at most the Owner's setting (30 days by default); archives uncompressed, as Plik's security guide suggests for public instances.
- **Data:** the uploads' details in SQLite (`/data/plik.db`, backed up by Roostack's SQLite dump), the files on the large data disk (`/files`), both critical.
- **The administrator** from an install hook running Plik's own `plikd user create` (safe to re-run). There's no sign-up page and no setup page.
- **Single sign-on:** generic OIDC from the issuer, PKCE, an account made at first sign-in. Plik has no groups, so the administrator made at install keeps its password and makes others administrators in Plik.
- **Found while testing:** with single sign-on on, Plik reads the provider's configuration as it starts and **exits if it can't** (as at boot, before the lab's sign-in page answers). The package retries every 10 seconds (`RestartSec`), so systemd doesn't give up after five quick tries.
- **Checked on 2026-10-30,** with the pinned image in Docker, using the package's settings:
  - it starts and reports the settings back (`/config`);
  - the install hook makes the administrator and, run again, keeps it;
  - an anonymous upload is refused;
  - the administrator signs in;
  - an uploaded `.html` comes back as `application/octet-stream` with nosniff and `Content-Security-Policy: … sandbox`, and with `?dl=1` as an attachment;
  - the database and files land in `/data` and `/files`;
  - with an unreachable provider it exits; with a stand-in provider it starts and sends people to sign in with the right client, PKCE, and `/auth/oidc/callback`;
  - local sign-in still works alongside;
  - it uses about 10 MB.
- **Tried on a lab, 2026-10-30:** dev VM 5 (arm64), Roostack `main` at 943763fe, a test address with Caddy's own certificates, added as a package of the Owner's own:
  - **Install:** the summary and the install form were right, and the install hook made the administrator.
  - **Under rootless Podman:** both folders belong to Roostack's user, so the user mapping works.
  - **Using it through the lab's address:** an anonymous upload was refused, and the administrator signed in. A 3 MB file came back identical, and an `.html` came back as `application/octet-stream` with the sandbox and nosniff.
  - **Backup:** `roostack backup run` covered the files, the SQLite dump, and the secrets.
  - **Restore:** both uploads were deleted in Plik, then restored with `roostack backup restore plik`; both came back (the file identical), and the administrator still signs in.
  - **Single sign-on:** turned on from the service page, Plik reached the lab's sign-in page but refused its test certificate, as expected on a test address. It then retried every 10 seconds, 10 times and counting, without systemd giving up. Turned off, Plik came straight back with its shares.
  - **Removal:** the container, units, and site went, and the data was kept.
- **Still not checked:** a restore onto a fresh server (this was a restore in place), and a real sign-in through a lab's provider with a trusted certificate.
- **Seen in Roostack, not the package:**
  - The single sign-on card says "Admins in Plik: the lab's Owners and Admins" and that Plik "finds it by their email address", which isn't true of an app that reads no groups and links no accounts.
  - Removing the service leaves its Podman network definition (`roostack-plik.json`).

## Questions for the maintainer

Answered on 2026-10-30: the generic app (Pingvin Share X), Seafile's garbage collection (scheduled hooks), and Chibisafe (not packaged). Still open:

1. **Scheduled hooks' timing:** `every: day | week | month`, with Roostack picking the time in the maintenance window (recommended), or a cron expression in the package?
2. **Is a sandbox enough?** The rule as recommended: HTML a download or refused where the app allows, sandboxed with nosniff otherwise (Pingvin Share X, Gokapi). Or only downloads and refusals?
3. **The flag:** in `registry.yaml`, set by the registry's maintainers (recommended), or in the package file?
4. **Approval:** per account, granted by support from the admin console (recommended for now), or per lab or per service?
5. **The build:** start sessions for Roostack's 1, 2, 3, 5, and 6 and Cloud's 8 now, then 4, 7, and 9?

## Sources

All read 2026-10-30 unless a date is given.

**Roostack and Cloud:** Roostack's SPEC.md §5.2, §6.8, §6.11, §8.1, §8.3.4; `cloudapi/cloudapi.go` (`RelayRequest`); `internal/manager/edge.go` (`publicHostsOf`); `internal/pkgspec/about.go` (memory defaults); Roostack Cloud's docs/DESIGN.md §3d, §3f ("abuse intake", 2026-10-19), §5; docs/RUNBOOK-ABUSE.md (2026-10-19).

**Seafile:**
- Licences: https://github.com/haiwen/seafile-server, https://github.com/haiwen/seahub, https://github.com/haiwen/seafile (LICENSE files)
- Releases: https://plus.seafile.com/wiki/publish/seafile-wiki/5L80/ (13.0.28, 2026-09-18; 14.0.9 beta, 2026-10-14)
- Images: https://hub.docker.com/r/seafileltd/seafile-mc, https://hub.docker.com/r/seafileltd/sdoc-server (2.0.10, 2026-10-24, amd64 only)
- Image build: https://github.com/haiwen/seafile-docker (`image/seafile_13.0/Dockerfile`, `scripts/scripts_13.0/enterpoint.sh` (cron: log rotation only), `scripts/scripts_13.0/gc.sh`)
- Manual: https://github.com/haiwen/seafile-admin-docs — `manual/setup/setup_pro_by_docker.md`, `manual/upgrade/upgrade_notes_for_11.0.x.md`, `manual/administration/backup_recovery.md` (2025-10-20), `manual/config/oauth.md` (2024-11-12), `manual/config/seahub_settings_py.md`, `manual/config/csp_configuration.md` (2026-04-25), `manual/setup/use_other_reverse_proxy.md`
- Code: seahub 13.0 `seahub/settings.py`, `seahub/oauth/views.py`, `seahub/utils/auth.py`; seafile-server `fileserver/fileop.go`
- CVEs (NVD): CVE-2025-45091 (2025-09-15), CVE-2025-41079 and CVE-2025-41080 (2025-12-04), CVE-2025-65516 (2025-12-04; fixed in 13.0.12, 2025-10-24), CVE-2026-30587 (2026-03-25), CVE-2026-56768 (2026-06-25)

**ProjectSend:** https://github.com/projectsend/projectsend (releases 2.0.0, 2026-08-14, to 2.8.0, 2026-10-29; `LICENSING.md`, `INSTALL.md`, `DOCKER.md`, `docker/production/Dockerfile`, `compose.example.yaml`, `app/Modules/Platform/Settings/Setting.php`); advisories at https://github.com/projectsend/projectsend/security/advisories; https://hub.docker.com/r/projectsend/projectsend; https://github.com/linuxserver/docker-projectsend (legacy since 2026-08-10).

**Zipline:** https://github.com/diced/zipline (4.8.2, 2026-10-25; `src/server/routes/api/upload/index.ts`, `src/server/routes/api/setup.ts`, `src/lib/config/read/index.ts` and `env.ts` (the environment overrides the database), `src/lib/api/contentSecurity.ts`); advisories at https://github.com/diced/zipline/security/advisories; docs from https://github.com/diced/zipline-docs (branch `v4.1`, 2026-10-26: `guides/hardening.mdx`, `guides/oauth/index.mdx`, `config/core.mdx`).

**Chibisafe:** https://github.com/chibisafe/chibisafe (6.7.0, 2026-10-22; `packages/backend/src/structures/settings.ts`, `packages/backend/src/utils/Util.ts`, `packages/backend/src/routes/admin/service/Settings.ts`, `packages/backend/src/routes/links/CreateLink.ts`); GHSA-7hmq-gf2f-c9c9 (2026-10-18); issue #566 (closed 2026-09-30).

**Palmr:** https://github.com/kyantech/Palmr (README archived 2026-02-27; 3.3.2-beta, 2025-12-10).

**Alternatives:**
- Pingvin Share X: https://github.com/smp46/pingvin-share-x (2.1.0, 2026-10-25; `backend/src/file/file.controller.ts` (sandbox and nosniff), `config.example.yaml`, `docs/docs/setup/configuration.md`); advisories at https://github.com/smp46/pingvin-share-x/security/advisories
- Pingvin Share: https://github.com/stonith404/pingvin-share (archived; 1.13.0, 2025-05-25)
- Plik: https://github.com/root-gg/plik (1.4.3, 2026-10-21; `server/handlers/get_file.go`, `server/plikd.cfg`, `docs/features/authentication.md`)
- SFTPGo: https://github.com/drakkan/sftpgo (2.7.6, 2026-09-19; `internal/httpd/api_utils.go`, `internal/dataprovider/share.go`); https://docs.sftpgo.com/latest/oidc
- Gokapi: https://github.com/Forceu/Gokapi (2.2.4, 2026-03-10; `internal/webserver/headers/Headers.go`, `internal/configuration/setup/Setup.go`)
- Erugo: https://github.com/ErugoOSS/Erugo (0.2.15, 2026-01-28; CVE-2026-24897)
- OpenCloud: https://github.com/opencloud-eu/opencloud (9.0.0, 2026-10-27); its docs `requirements.md`, `storage/posixfs.md`, `external-idp.md`, `maintenance/backup.md`
- ownCloud Infinite Scale: https://github.com/owncloud/ocis (8.2.2, 2026-10-21); https://owncloud.com/license-owncloud-infinite-scale
- File Browser: https://github.com/filebrowser/filebrowser (archived; 2.63.23, 2026-07-27)
- FileBrowser Quantum: https://github.com/gtsteffaniak/filebrowser (2.0.2-stable, 2026-10-23; `backend/internal/web/http.go`)
- copyparty: https://github.com/9001/copyparty (1.20.26, 2026-10-14; README "security")
- Sharry: https://github.com/eikek/sharry (1.17.0, 2026-10-05; `ByteResponse.scala`)
- Filestash: https://github.com/mickael-kerjean/filestash (`server/pkg/files/handler_cat.go`)
- Cloudreve: https://github.com/cloudreve/cloudreve (4.19.1, 2026-09-18); its docs `en/usage/oidc.md`
- PsiTransfer https://github.com/psi-4ward/psitransfer (2.4.5, 2026-10-24); PicoShare https://github.com/mtlynch/picoshare (1.5.4, 2026-05-26); Send https://github.com/timvisee/send (3.5.0, 2026-10-24); Enclosed https://github.com/CorentinTh/enclosed (1.16.1, 2026-10-23); Jirafeau https://gitlab.com/jirafeau/Jirafeau (4.7.2, 2026-06-27); Lufi https://framagit.org/fiat-tux/hat-softwares/lufi (0.07.4, 2026-09-14); DumbDrop https://github.com/DumbWareio/DumbDrop; transfer.sh https://github.com/dutchcoders/transfer.sh (1.6.1, 2023-12-04)
