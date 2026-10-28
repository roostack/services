# Roostack services

The packages [Roostack](https://roostack.cloud) can install. Each package
says how to run one self-hosted app: its containers, where its data lives,
its databases, its web address and its settings. Roostack generates the
rest (systemd units, web server config, secrets, folders, the backup plan).

This repository is the source of truth: every package and every change to
one is a reviewed commit. Labs read it through a signed index that CI builds
from it after each merge, published at
[registry.roostack.cloud](https://registry.roostack.cloud) with a page
anyone can browse.

## Layout

```
packages/
  <name>/
    <version>.yaml   one file per version; never edited once published
    icon.png         the project's logo (about.icon)
    registry.yaml    tier, maintainers and any withdrawals
web/                 the registry's page (below)
tools/               copying Roostack's files for the page, and checking them
```

- **`<version>.yaml`** is the package itself, named by its `version`:
  the upstream release plus a package revision, as `1.34.3-roostack.1`. A
  better definition for the same release is a new revision, in a new file.
  Published versions are never changed, only withdrawn and superseded. The
  format is documented in Roostack's help, under Reference → Package format.
- **`icon.png`** is the project's real logo: a square PNG, at least 256×256
  pixels and at most 100 KB.
- **`registry.yaml`** is kept by the registry's maintainers, not the
  package's author:

  ```yaml
  tier: official          # official or community
  maintainers:
    - roostack            # GitHub users or teams who look after it
  withdrawals:            # only when needed
    - version: 1.34.2-roostack.1
      level: warning      # notice, warning or stop
      reason: A security fix is in 1.34.3; update.
  ```

## Tiers

- **Official:** maintained by the Roostack project, reviewed, and tested on
  a real lab for each Roostack release.
- **Community** (opening later): written and maintained by its author,
  reviewed against the same checklist before each version is published.

Review checks how Roostack sets the app up, and where its images come from.
The app itself is its own project's work.

## Publishing

On every merge to `main`, and once a day, the Publish workflow
(`.github/workflows/publish.yml`) checks every package, builds the signed
index Roostack labs read, and publishes it with the package files at
`https://registry.roostack.cloud/v1/`. Pull requests get the same checks,
with nothing signed or published, and the run's summary shows what each
added or changed package generates (its default settings in an example
lab), with the difference from the package's previous version.

Each package's newest version has a bill of materials for each of its
images, in `boms/`: what Syft finds inside, cut down to each library's
name, version and package URL. A pull request's summary compares a new
version's bills with its `built_with:`, saying what an image has that
`built_with:` doesn't name, and the other way round. After the merge,
the Bills of materials workflow (`.github/workflows/boms.yml`) keeps the
bills on `main`, and Roostack's watcher checks the exact versions in them
for known security problems. How it works is in Roostack's
`docs/REGISTRY-WATCH.md`.

Every hour, the Watch workflow (`.github/workflows/watch.yml`) looks for
security problems in the registry's packages: their projects' own
advisories, CISA's list of exploited vulnerabilities, and more. When a
version here is affected and the problem is critical or being used in
attacks, it opens a pull request adding a draft advisory to
`advisories/`, and pushes an urgent one to the maintainers' phones. A
maintainer checks the draft and merges it, and the next Publish run
sends it to labs. Weaker matches are collected for a digest issue each
Monday. What it has handled is kept in `watch/state.json`, so nothing is
drafted twice. How it works is in Roostack's `docs/REGISTRY-WATCH.md`.

`.github/CODEOWNERS` says who reviews what: the registry's maintainers
own everything, including every `registry.yaml`. Once community packages
open, each one's folder also lists its maintainers. `keys/` holds the root key's statement
naming the key CI signs with. How the keys are made and replaced is in
Roostack's `docs/REGISTRY-KEYS.md`.

## The registry's page

`https://registry.roostack.cloud/` is a page that lists every service, with
search and filters, and shows each one's full record. It's plain HTML, CSS
and JavaScript in `web/`, which Publish copies beside `v1/`; it reads the
same signed index labs do and, when a service is opened, its newest package
file, which it checks against the index's SHA-256 before showing it.

- **`web/roostack/`** is copied from Roostack: its design system (tokens,
  the default theme, `app.css`, the display font) and the YAML parser its
  package editor vendors. Don't edit these: run
  `tools/sync-roostack.sh <Roostack checkout> [ref]` to copy them from a
  Roostack commit, which `web/roostack/SYNCED` names. Publish checks them
  against that commit on every run (`tools/check-roostack.sh`).
- **`web/notices.json`** holds notices a project asks for on its service's
  page, by package name (Plex's trademark notice): package files can't
  change once published, so these live here.
- **Logos** are each project's own, shown to identify its app; where they
  came from, and any terms, is in each package's `registry.yaml`. The page
  says a listing doesn't mean a project is affiliated with Roostack or
  endorses it.

To try it, build an index into a folder (`roostack registry index -out
<dir>/v1`, with a development key: Roostack's docs/REGISTRY-KEYS.md), copy
`web/` into `<dir>`, and serve `<dir>` with any web server.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Licence

The package files in this repository are under the
[Apache License 2.0](LICENSE). Each app they install, and its logo, belongs
to its own project, under its own licence (`about.licence` in its package).
