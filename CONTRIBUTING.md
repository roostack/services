# Contributing a package

Community packages aren't open yet: for now this repository holds the
official packages, maintained by the Roostack project. Until it opens,
open an issue for an app you'd like to see. This is how it will work.

The whole process is in Roostack's help, under
[Make your own service](https://help.roostack.cloud/packages/):

1. **[Write](https://help.roostack.cloud/packages/write/)** the package:
   start from the package here closest to your app. Name the file after
   its version (`packages/<name>/<version>.yaml`), put the project's logo
   beside it as `icon.png`, and fill in `about:`. Pin every image by its
   multi-architecture digest.
2. **Check** it, on a Roostack server or any Linux computer with the
   `roostack` command:

   ```sh
   roostack validate packages/<name>/<version>.yaml
   ```

   Registry packages follow the package policy: images pinned by digest,
   memory set on every container, and nothing that reaches outside the
   service. To see the files it generates, see
   [Check it](https://help.roostack.cloud/packages/write/#check-it).
3. **[Try it on a lab](https://help.roostack.cloud/packages/try/)**: add it
   as a package of your own and go through install, a backup, a restore
   onto a fresh server, and removal, noting what you did.
4. **[Open a pull request](https://help.roostack.cloud/packages/submit/)**
   and fill in its checklist with what you tested. Don't add or change
   `registry.yaml`; the registry's maintainers do.

A new version of an existing package is a new file. Don't edit published
versions.
