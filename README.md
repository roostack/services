# Roostack services

The packages [Roostack](https://roostack.cloud) can install. Each package
says how to run one self-hosted app: its containers, where its data lives,
its databases, its web address and its settings. Roostack generates the
rest (systemd units, web server config, secrets, folders, the backup plan).

This repository is the source of truth: every package and every change to
one is a reviewed commit. Labs read it through a signed index that CI builds
from it after each merge (not built yet; until then each Roostack release
fetches a pinned commit of this repository).

## Layout

```
packages/
  <name>/
    <version>.yaml   one file per version; never edited once published
    icon.png         the project's logo (about.icon)
    registry.yaml    tier, maintainers and any withdrawals
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

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Licence

The package files in this repository are under the
[Apache License 2.0](LICENSE). Each app they install, and its logo, belongs
to its own project, under its own licence (`about.licence` in its package).
