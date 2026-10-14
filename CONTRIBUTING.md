# Contributing a package

Community packages aren't open yet: for now this repository holds the
official packages, maintained by the Roostack project. This is how it will
work.

1. **Write** a package: copy one from `packages/` and follow the format
   reference in Roostack's help (Reference → Package format). Name the file
   after its version, put the project's logo beside it as `icon.png`, and
   fill in `about:` (maker, licence, source, categories).
2. **Check** it with Roostack's command line:

   ```sh
   roostack validate packages/<name>/<version>.yaml
   roostack render packages/<name>/<version>.yaml   # the files it generates
   ```

   Registry packages follow the package policy: images pinned by digest,
   memory set on every container, and nothing that reaches outside the
   service.
3. **Try it on a real lab**: add it as a package of your own and go
   through install, a backup, a restore onto a fresh server, an update from
   the previous version, and removal.
4. **Open a pull request** with what you tested. Don't add or change
   `registry.yaml`; the registry's maintainers do.

A new version of an existing package is a new file. Don't edit published
versions.
