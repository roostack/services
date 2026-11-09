# Review: note-keeping apps (2026-11-09)

A review before packaging Kept, a Google Keep-style notes app, and a look at the other self-hosted note apps worth packaging. For each: how it fits Roostack's package format, and what it risks for roost.ac and Roostack Cloud's relay when a lab makes it public. Then Memos, Jotty, and AFFiNE, packaged and tried after the maintainer's decisions below.

Upstream facts were checked on 2026-11-09 against each project's repository (GitHub's API for stars, releases, and commits since May 2026), its container registry's manifests, and its documentation. Statements marked *code-read* come from reading the app's source at the packaged version, not from running it; everything else was tried on a lab.

## Decisions (the maintainer, 2026-11-09)

- **Kept: wait and see.** It's six months old and one person's project. Its package (`kept@1.9.4-roostack.1`, tried on a lab) stays on the branch `claude/kept`, unmerged; look at it again in 2027.
- **Package Memos and Jotty,** and **AFFiNE too** (despite its licence, below). All three are in this change.

## For the maintainer to decide

1. **Memos and Jotty on roost.ac.** Both show an uploaded SVG inline on a share link or public page, sandboxed or with a strict CSP but not as a download, which the decision of 2026-10-31 ("downloads only") doesn't allow. Their `registry.yaml` has the `roost_ac` approval flag for now, so their public addresses need Roostack Cloud's approval on roost.ac and the relay. The alternative is Roostack's Caddy making uploaded SVG a download (change 7 of the file-sharing review), after which the flag can go. Recommended: keep the flags until change 7.
2. **AFFiNE's licence for hosted labs.** Its server is under AFFiNE's Enterprise Edition licence except the parts "distributed as part of AFFiNE CE" (MPL-2.0), and nothing says which parts those are; its README calls the self-hosted version the Community Edition, "free for self-host". Fine for an Owner's own lab, but Roostack Cloud's hosted labs would be AFFiNE run for customers: a question for docs/LEGAL.md in Cloud's repository before hosted labs offer it.
3. **AFFiNE's telemetry.** Its web app sends usage events to `app.affine.pro` and errors to Sentry from each visitor's browser, on by default, with only a per-person switch (Settings, About). The package can't turn it off. Offer it anyway, with a line in its description or notes, or wait for a setting upstream (an issue to raise).
4. **The single sign-on card for Kept** (when Kept is looked at again): Roostack's card says "Kept will make each person an account the first time they sign in", which isn't true. Proposed: `sso.oidc.existing_accounts: connect`.

## Kept

**What it is:** quick notes, nested checklists, image notes, drawings, links, attachments, labels, colours, and reminders in cards, like Google Keep. It has its own iOS and Android apps (in the stores), which work on the phone alone or sync with a Kept server, a web app (PWA), real-time sharing of notes between people on the same server, Google Keep Takeout import, and an optional MCP server and OAuth 2.1 for AI tools. The author also sells hosting, Kept Cloud.

**Health:** the repository was created on 2026-04-28. 18 releases since (v1.1 on 2026-05-12 to v1.9.4 on 2026-11-06), weekly lately. 330 stars, 16 forks, 11 open issues, no published security advisories, and no `SECURITY.md`. One author: ericerkz has 254 of the 271 commits, and seven others have one to six each. A bus factor of one, and young, though the code has many security tests (SSRF guards on every outgoing request, a setup token, restore off by default, locked notes kept from AI tools).

**Licence:** `AGPL-3.0-only` (`LICENSING.md`). Contributions are under a CLA that lets the author relicense them, and the author offers Kept under other terms too (App Store, hosting), so a future version could change licence; the AGPL versions stay AGPL. The first UI came from an MIT project, credited.

**Image:** `ghcr.io/ericerkz/kept`, the project's own, multi-arch (amd64 and arm64), Node 24 on Alpine, tags per version (`1.9.4`, `1.9`, `1`, `latest`). Built and pushed from the author's own machine (`deploy-docker-images.ts`), not by CI: there are no workflows in the repository. The image starts as root and drops to user 1000 with `su-exec`, which fails under Roostack's Podman ("setgroups: Operation not permitted"), so the package runs `node server/server.js` as 1000 directly (upstream issue #80 asks for a non-root compose too).

**Database and data:** SQLite in WAL mode, and everything else in one folder, `/app/data`:

| What | Where | Class |
|---|---|---|
| The database: notes, accounts, sharing, sessions, settings | `kept.sqlite` (with `-wal`, `-shm`) | critical |
| Images in notes | `uploads/` | critical |
| Attachments (PDF, Office, text, archives; not HTML) | `attachments/` | critical |
| The keys for push notifications, and for signing browser sessions | `vapid.json`, `browser-session-secret` | critical (new ones would sign everyone out and break push subscriptions) |
| Kept's own scheduled backups, off by default | `backups/` | replaceable, but in the same folder |
| Takeout imports in progress | `imports/` | replaceable |

One storage entry, `data`, critical. **Backups:** Roostack copies the database with `VACUUM INTO` while Kept runs, then the folder, which is consistent enough: a file written between the two is only an orphan. Kept's own full backup (a ZIP from User management) is an alternative for moving a server, not needed with Roostack's.

**First account:** Kept's first visitor makes the administrator through `/api/setup/admin`, unless `KEPT_SETUP_TOKEN` is set, in which case only someone sending the token can. The package generates the token and its install hook makes the administrator with it, from the username and password chosen at install (`install_only`). So nobody can take Kept over before setup, even at home, and even if its database is lost later (tried below).

**Single sign-on:** generic OIDC with discovery, from the environment (`KEPT_OIDC_ISSUER`, `_CLIENT_ID`, `_CLIENT_SECRET`, `_NAME`), beside Kept's own passwords. Kept never makes or matches an account by itself, and never by email: someone with a Kept account connects the lab's sign-in under Settings, Security, Connect SSO account; someone without one gets one only if the administrator has turned on sign-ups, by filling in Kept's form (username, name, email, password) after signing in through the lab, and waits for approval if "Require approval" is on (its default). No groups, so no admins from the lab. `GET /api/auth/oidc/start` starts signing in, so it's the package's `start_path`. `KEPT_DISABLE_PASSWORD_LOGIN` (SSO only) refuses to start until an administrator is connected, so the package leaves it off.

**Public, and roost.ac:** low risk, so no `roost_ac` flag.

- Nothing is public: notes are shared only with other people on the same Kept. There are no public links or published notes.
- Images and attachments go only to someone signed in who can see the note (tried: anonymous gets 401). Attachments always come as downloads (`application/octet-stream`, `nosniff`); HTML attachments are refused (tried); images are served only as PNG, JPEG, GIF, or WebP, with `nosniff` (*code-read*). So it passes the "downloads only" rule.
- Sign-ups are off by default (an admin setting), with approval on when they're on.
- `/oauth/register` (OAuth dynamic client registration, for MCP clients) is open to anyone, rate-limited to 30 an hour; a registered client can't do anything until a person, with OAuth access turned on in their own settings, approves it (*code-read*). Left public, since an AI tool elsewhere needs it.
- **Link previews:** by default Kept asks `image.thum.io` for a screenshot of every page a note links to, so a third party sees those addresses (*code-read*: `previewScreenshotUrl`). The package turns that off (`KEPT_LINK_PREVIEW_SCREENSHOTS=0`), with a setting to turn it on. Kept still fetches each linked page itself for its title and image, with private addresses blocked.

### The package: `packages/kept/1.9.4-roostack.1.yaml` (on the branch `claude/kept`, not merged)

One container, SQLite, the address `notes`, private by default. `requires.roostack: "0.1.3"` for `start_path`. `BASE_URL` is the route's address. `max_body_size: 5GB`, Kept's own limit for a Takeout import (images and attachments are 100 MB at most). The monitor asks `/api/health`, which checks the database and the folder. The logo is the project's own 512-pixel icon, made 256 pixels. `built_with: [node]`.

### Tried on a lab (2026-11-09)

Dev VM 5, arm64, Roostack `main` at 755d3cff (v0.1.4-10), Kept added as a package of the Owner's own:

- **Install:** the first try failed: `su-exec` couldn't change groups and the container restarted until systemd gave up. Fixed in the package (above); the second install ran, the install hook made the administrator with the setup token, and Kept used 42 MB.
- **Use through the lab's address:** signed in with the password through `https://notes.<lab>`, made a note, attached a text file (a download, `nosniff`; anonymous 401), and an HTML attachment was refused.
- **Single sign-on:** on at install. The dev VM's sign-in page has Caddy's internal certificate, which Node doesn't trust, so for this test only the lab's root certificate was added to Kept's container with a Quadlet drop-in on the VM (`NODE_EXTRA_CA_CERTS`; removed afterwards). A real lab's sign-in page has a public certificate. Connected the lab's sign-in to the administrator under Settings, then `start_path` with the lab already signed in landed signed in as Kept's administrator. The card's wrong claim is decision 2. Not tried: someone from the lab without a Kept account (*code-read*: they land on Kept's sign-in page with "no account" while sign-ups are off).
- **Backup, delete, restore:** backed up (`roostack backup run`), added a second note, deleted the database and attachments, restarted Kept (which then had no accounts, and refused setup without the token), and restored (`roostack backup restore kept`): the first note and its attachment came back, the second didn't, and the administrator's link to the lab's sign-in was kept.
- **Removal with its data:** the container, network, secrets, units, address, and folder all went.
- Not tried: the phone apps, push notifications, a Takeout import, turning single sign-on off and on again, an update, and a public address.

### Roostack findings

- The single sign-on card always says the app will make each person an account (`internal/web/templates/service.html`, the `sso` card): decision 2.
- On a dev VM, single sign-on can't work for an app that checks certificates against its image's own list, since the sign-in page's certificate is Caddy's internal one. A dev-only way to give containers the lab's root would make trying single sign-on easier.

## Memos 26.11.0 — packaged

**What it is:** short notes in a timeline, like a private microblog, with Markdown, tags, checklists, attachments, comments, and share links. MIT; 64k stars; monthly releases (26.11.0 on 2026-11-01); two maintainers.

**Image:** `docker.io/neosmemo/memos`, the project's own, amd64, arm64, and armv7. Its entrypoint starts as root and drops to 10001 with `su-exec`, which fails under Roostack's Podman as Kept's does; started as 10001, it skips that, so the package runs it as `User: 10001` with `keep-id`.

**Data:** SQLite (`memos_prod.db`) and attachments (`assets/`, local storage by default) in one folder, critical. Postgres and MySQL are possible; SQLite is simpler and Roostack copies it consistently.

**Its configuration:** since 26.10, Memos applies a declarative configuration, JSON files in `/etc/memos/config`, at every start: identity providers, instance settings, and bootstrap users. The package writes one (`config_files`) holding the administrator, the sign-up and access settings, and the lab's sign-in. Each setting group it names is managed whole and read-only in Memos' settings, except the fields `lifecycle` releases (the instance's name, logo, and styles stay the administrator's). The administrator's password is sent only when the account is made.

**First account:** the administrator is in the configuration, so Memos makes it before it answers anyone: nobody can take it over, even at home. Roostack forgets the password after setup and writes the file again with `""`, which Memos accepts since the account exists. If the database is lost, Memos refuses to start ("password is required to create the user") until it's restored: safe, though not friendly.

**Sign-ups and public reading:** off by default (settings). Even in private mode, a memo's share link shows it and its attachments to anyone with the link; with "Let people read public memos" on, memos marked Public are shown to anyone.

**Uploads:** HTML, scripts, and XML come as `application/octet-stream` downloads, and anything but images and PDFs as attachments; images, **SVG included**, are shown inline with `Content-Security-Policy: default-src 'none'` and `nosniff` (tried: an SVG on a share link opens as an image page). Decision 1.

**Single sign-on:** OAuth2 (explicit addresses, from the configuration file). While it's on, the package lets people from the lab get an account at their first sign-in and turns off password sign-in and sign-ups for everyone else; administrators keep their passwords. Memos links by the lab's subject only, so an account made before is separate (the account it makes is named after the subject, a 32-character ID, until the person changes it in their settings). When it's off, the package removes the provider (`removed`, as Memos requires).

**Tried on dev VM 5** (2026-11-09):

- Installed with single sign-on off: the configuration applied (`create users/memosadmin`, sign-ups off, private). The first install had no install hook, and Roostack never forgot the password (finding below); the package now has a hook that waits for Memos to answer, and the second install forgot it and wrote `""` in the file.
- Signed in with the password through the lab's address, made a memo, attached an SVG, an HTML file, and a text file, and made a share link: anonymous visitors got 401 without it; with it, HTML and text came as downloads and the SVG inline.
- Single sign-on on (with the dev VM's test certificate, as for Kept): the configuration added the provider; the lab's Owner signed in through the lab (OAuth2 with PKCE) and got a new account; the administrator's password still worked.
- Backup, delete, restore: deleted the data folder and restarted (Memos refused to start, as above), restored; the memo from before the backup and its three attachments came back, the later one didn't. The restore's start failed at first because systemd had given up after the refused starts (finding below).
- Removed with its data: nothing left.

## Jotty 1.29.2 — packaged

**What it is:** notes and checklists (simple or kanban) kept as Markdown files, with categories, reminders, live editing together, sharing between people, public links, and an API. AGPL-3.0 (read as `-only`, as for Seafile); 2k stars; monthly releases; one main maintainer (fccview, 210 of about 320 commits since May) and regular contributors. One advisory (path traversal, fixed in 1.22.0).

**Image:** `ghcr.io/fccview/jotty`, multi-arch (amd64, arm64), Node 24 on Alpine, Next.js. Run as 1000 with `keep-id` (its own compose file does the same).

**Data:** no database: `data/` holds accounts, sessions, and settings as JSON, notes and checklists as Markdown, attachments, and PGP keys (critical); `config/` holds its admin's themes, emoji, and styles (critical, small). Its `.relations.db` is an index it rebuilds at start.

**First account:** Jotty's setup page makes whoever reaches it first its owner, and there's no command or API to make one. The install hook writes the administrator into `users.json` under Jotty's own lock, only while it's empty. **Jotty keeps passwords as unsalted SHA-256**, so the lab's sign-in is the better way in. If the accounts file is lost, Jotty's setup page is open again until it's restored.

**Public:** anyone with an account can publish a note, checklist, or folder at `/public/...`, with its attachments, and nothing turns that off. HTML comes as a download, SVG inline with a sandbox (*code-read*). Nobody can sign up: accounts come from an admin or the lab's sign-in. Decision 1.

**Single sign-on:** OIDC with discovery from the environment, beside its passwords (`SSO_FALLBACK_LOCAL`). It makes an account at first sign-in, or **uses the account with the same username**, and makes the lab's Owners and Admins its admins (`OIDC_ADMIN_GROUPS`); it never takes admin away. `start_path` is `/api/oidc/login`. The card says so (`existing_accounts: username`, `admins: true`).

**Tried on dev VM 5** (2026-11-09): installed; the hook made the administrator; signed in with the password through the lab's address (in a headless browser: its sign-in is a Next.js action) and made a checklist, which landed as Markdown; turned single sign-on on (test certificate as before) and signed in through the lab from the start path as the lab's Owner, who got a new account and was made an admin; backed up, deleted the checklists and accounts, restarted, restored: both came back and the administrator signed in again; removed with its data: nothing left. Jotty used 119 MB. Not tried: public links and attachments (*code-read*), live editing.

## AFFiNE 0.27.4 — packaged

**What it is:** documents, whiteboards ("edgeless"), and databases in workspaces, edited together live, with desktop and phone apps that sync to a server. 74k stars; stable releases every few months (0.27.4 on 2026-08-18; daily canaries); effectively one core maintainer (darkskygit, about half the commits) and many contributors. Two advisories, both fixed (one for the desktop app).

**Licence:** the web app MIT; the server under AFFiNE's Enterprise Edition licence, which needs a subscription for production use, except the parts in its Community Edition, MPL-2.0; the README says the self-hosted version is the Community Edition and free to self-host. Nothing lists which code is which; the only gate in the code is the free self-hosted plan's limits: 10 members per workspace, 100 GB of storage, 100 MB per file, and 30 days of history (*code-read*). `about.licence` is `MIT AND MPL-2.0 AND LicenseRef-AFFiNE-EE`. Decision 2.

**Image:** `ghcr.io/toeverything/affine`, multi-arch (amd64, arm64, armv7), Node 22, runs as root (Roostack's user under rootless Podman), port 3010.

**Databases and data:** Postgres (the documents, accounts, and settings saved in its admin panel) and Redis (cache, queues, and sync, not backed up), both run by Roostack. AFFiNE tests on Postgres 16 with pgvector; on Roostack's Postgres 17 without it, its migrations skipped only the AI search tables. `/root/.affine/storage` holds uploaded files (critical); `/root/.affine/config` holds `private.key`, its signing key (critical), and `config.json`, which Roostack writes.

**Migrations:** its compose file runs `self-host-predeploy.js` (the signing key the first time, then Prisma's and its data migrations) as a job before each start. The package runs it in the app's own container before the server, since every step is safe to repeat.

**Settings:** auth, OAuth, and flags come only from `config.json` or its admin panel, and a value saved in the panel wins. The package writes sign-ups (off: they'd need its email set up), sign-ups through the lab while single sign-on is on, the lab's OIDC provider, and no guest demo workspaces.

**First account:** AFFiNE's setup page makes whoever reaches it first the administrator; the install hook calls the same endpoint (`/api/setup/create-admin-user`). Passwords are 8 to 32 characters. If the database is lost, the setup page is open again until it's restored.

**Public:** a workspace's owner can publish documents to everyone (on by default per workspace, with no server-wide switch), and then anyone can fetch that workspace's files by their key. Files come with `nosniff`, and HTML, SVG, XML, and scripts as downloads (*code-read*), so it passes "downloads only"; new accounts can't share for their first 24 hours. No `roost_ac` flag.

**Outgoing:** the web app's telemetry (decision 3), fonts from `cdn.affine.pro`, and the admin panel's update check. Server telemetry, AI, the licence check, and the indexer are off.

**Single sign-on:** OIDC from `config.json`. It makes an account at first sign-in or **uses the account with the same email** (`existing_accounts: email`); no groups, so no admins from the lab. `start_path` is `/oauth/login?provider=OIDC`. Its fetcher refuses private and link-local addresses unless `allowPrivateNetwork` is on for the issuer, which the package sets: a lab's containers reach its sign-in page at 169.254.1.2.

**Tried on dev VM 5** (2026-11-09): installed; migrations ran on Postgres 17, the hook made the administrator; AFFiNE used 255 MB idle (400 MB RSS), against its documented 2 GB for comfortable use, so `memory: 1 GB`. Signed in through the lab's address in a headless browser, made a workspace, and edited a document's title (typed as a keyboard would: `execCommand` changes the page without AFFiNE's editor seeing it). Backed up, edited again, dropped its database schema and deleted its files and key, restored: the title came back as it was at the backup, read in a fresh browser. Removed with its data: nothing left. **Single sign-on wasn't tried:** AFFiNE's fetcher trusts only its built-in public roots (`safefetch`, webpki-roots), so it can't reach a dev VM's sign-in page with Caddy's internal certificate; on a real lab, with a public certificate, it should (*code-read*). The card turned on and the configuration was written.

## Roostack findings (2026-11-09)

- **Install-only secrets aren't forgotten without an install hook.** `node/hooks.go` forgets them, and writes config files again without them, only after install hooks succeed, and a package with none never gets there (`manager.go`: `setUp` only when it has install hooks). Memos' first install kept its administrator's password in the Podman secret and in its config file. Fix: treat a package with no install hooks as set up once it has started (or forget install-only secrets then). Memos' package has a hook in the meantime.
- **A restore can't start a service systemd has given up on.** After a crash loop ("Start request repeated too quickly"), `roostack backup restore` failed to start Memos on the restored data until `systemctl --user reset-failed`. Fix: reset-failed before starting after a restore.
- **The single sign-on card always claims the app makes accounts** (Kept; decision 4).
- **Trying single sign-on on a dev VM** needs the lab's root certificate in the container (Node: `NODE_EXTRA_CA_CERTS`; Go: `SSL_CERT_FILE`); AFFiNE can't be given one at all. A dev-only option to give containers the lab's root, or a public certificate for dev VMs, would make it possible.

## Other note apps

| App | Licence | Health | Image | Database | Single sign-on | Public content | Fits Roostack? |
|---|---|---|---|---|---|---|---|
| **Memos** (short notes, a timeline) | MIT | 64k stars; 26.11.0 (2026-11-01), monthly; 2 maintainers | `neosmemo/memos`, multi-arch, drops to 10001 | SQLite, or Postgres or MySQL | OAuth2 with explicit addresses (no discovery), presettable from a config file | Public memos and share links; `accessMode PRIVATE` stops anonymous reading | **Packaged** (above) |
| **Trilium** (TriliumNext, a hierarchical knowledge base) | AGPL-3.0 | 38.7k; v0.107.0 (2026-11-08), every 3–6 weeks; 2 | `triliumnext/trilium`, multi-arch, non-root with a read-only root from v0.107 | SQLite | Generic OIDC from env; one click to connect in its options | Single person; per-note `/share` pages are public | **Yes:** one container; `/share` needs thought for roost.ac |
| **Jotty** (notes and checklists) | AGPL-3.0 | 2k; 1.29.2 (2026-10-25), monthly; 1 main | `ghcr.io/fccview/jotty`, runs as 1000 | Markdown files | Generic OIDC from env, with groups | Read-only public links | **Packaged** (above) |
| **SilverBullet** (a Markdown personal wiki) | MIT | 6.5k; 2.12.1 (2026-10-12); 1 | `ghcr.io/silverbulletmd/silverbullet`, `PUID` | Markdown files | OIDC since 2.11, set only in its dashboard | A space can be open to anonymous readers or writers | Possible; less hands-off |
| **Kept** (Google Keep-style) | AGPL-3.0-only | 330; weekly; 1, since April 2026 | above | SQLite | above | None | Waiting (decided 2026-11-09) |
| Blinko (AI notes) | GPL-3.0 | 11.2k; slowing | root | Postgres | OAuth2 set in its UI | Share links | Later |
| **AFFiNE** | MIT, MPL-2.0, and its Enterprise licence (above) | 74k | root | Postgres (pgvector optional), Redis | OIDC from a config file | Publishing; sign-ups on by default upstream | **Packaged** (above), the maintainer's choice |
| Joplin Server | Personal, non-commercial licence | 57k (all of Joplin) | `joplin/server` | Postgres | SAML or LDAP only | Published notes | No: licence, for hosted labs |
| Outline | BSL 1.1 (no third-party "Document Service" until 2030) | 41k | `outlinewiki/outline` | Postgres, Redis | OIDC (required) | Share links | No: licence; overlaps Wiki.js |
| Docmost | AGPL-3.0 plus a paid edition | 22k | `docmost/docmost` | Postgres, Redis | Paid edition only | Public pages | No: overlaps Wiki.js, SSO is paid |
| Standard Notes | GPL-3.0 | quiet | root | MySQL, Redis, LocalStack, a separate web app | None | – | No: too many parts |
| Notesnook sync | AGPL-3.0 | beta | 7 images | MongoDB replica set, S3 | None | Publishing ("Monograph") | No: too many parts, publishing |
| Logseq, Anytype | AGPL-3.0, MIT/source-available | – | no sync server to package, or non-web ports | – | – | – | No |
| SiYuan, Flatnotes, NoteDiscovery, Glass Keep | various | – | root | files or SQLite | None (one password; NoteDiscovery's defaults to "admin") | some | No: no accounts or SSO |

**What the registry has:** HedgeDoc (collaborative Markdown documents), Wiki.js (a wiki), and Papra (a document archive). None is for quick personal notes or checklists, so Memos, Kept, and Jotty overlap nothing; Trilium and SilverBullet are personal wikis, closer to Wiki.js but for one person.

**Recommendation and order (before the decisions):** Memos first (the most used and healthiest, MIT, one container, and its config file can keep it private and turn off sign-ups), then Trilium (a personal knowledge base nothing here covers), then Jotty (Keep-style checklists, if Kept isn't offered). SilverBullet after those. Kept is ready if the maintainer accepts its age and single author (decision 1). Not AFFiNE, Joplin Server, or Outline (licences), nor Docmost (paid SSO). The maintainer chose Memos, Jotty, and AFFiNE, and to wait on Kept (2026-11-09).

## Sources (checked 2026-11-09)

- Kept: https://github.com/ericerkz/kept (README, `docker-compose.yml`, `Dockerfile`, `docker-entrypoint.sh`, `LICENSING.md`, `docs/oidc.md`, `server/server.js`, `server/oauth-mcp.js`), https://www.keepitkept.xyz/, `ghcr.io/ericerkz/kept` manifests.
- Memos: https://github.com/usememos/memos, https://usememos.com/docs/configuration/authentication, https://usememos.com/docs/configuration/declarative-configuration
- Trilium: https://github.com/TriliumNext/Trilium, https://docs.triliumnotes.org/user-guide/setup/server/openid-connect
- Jotty: https://github.com/fccview/jotty
- SilverBullet: https://github.com/silverbulletmd/silverbullet
- Blinko: https://github.com/blinkospace/blinko
- AFFiNE: https://github.com/toeverything/AFFiNE (`packages/backend/server/LICENSE`)
- Joplin Server: https://github.com/laurent22/joplin (`packages/server/LICENSE.md`)
- Outline: https://github.com/outline/outline (`LICENSE`)
- Docmost: https://docmost.com/docs/editions
- Standard Notes: https://github.com/standardnotes/server
- Notesnook: https://github.com/streetwriters/notesnook-sync-server
- Logseq: https://github.com/logseq/logseq; Anytype: https://github.com/anyproto/any-sync-dockercompose
- SiYuan, Flatnotes, NoteDiscovery, Glass Keep: their GitHub repositories.
