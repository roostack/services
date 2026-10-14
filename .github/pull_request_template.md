<!-- Adding or updating a package? Fill in the checklist below with what
you did while trying it on a lab:
https://help.roostack.cloud/packages/try/
Anything else (the README, the workflow): replace this with what changed and why. -->

## Package

- Package and version: <!-- e.g. myapp 2.4.1-roostack.1 -->
- Upstream release notes: <!-- link -->

## Tried on a lab

- Roostack version (at the foot of every page):
- Processor (`dpkg --print-architecture`): <!-- amd64, arm64, or both -->

- [ ] `roostack validate` passes:
  ```
  <!-- the line it printed -->
  ```
- [ ] Installed and started; I used it and added: <!-- an account, a note, … -->
- [ ] The summary before installing was right (what's backed up, the address, memory)
- [ ] Public access: the sign-in and private pages behaved as the package says (or: it has no web address)
- [ ] Memory measured with `podman stats` (each container):
  ```
  <!-- name  usage -->
  ```
- [ ] Backed up; `roostack backup snapshots` shows the service:
  ```
  <!-- the service's line -->
  ```
- [ ] Restored the whole lab onto a fresh server, and everything I added was there
- [ ] Removed: it stopped, and its data was kept

## Notes

<!-- Anything a reviewer should know: options you didn't try, quirks of the app, Quadlet lines and why they're needed. -->
