# Consuming coil-json

This package is `json`. `use json::{…}` resolves from this repo's `src/` once implementations land. This checkout is an empty scaffold. The living codec remains [coil-stdlib](https://github.com/ardax-corp/coil-stdlib) `src/codec/json.hy`.

coil-stdlib is a sibling `[module] roots` entry, not a dependency of this package. Do not add a `codec` spool dep.

Coil-to-Coil deps will be spool-owned once a public `spool` CLI exists. Until [COI-219](https://linear.app/ardax/issue/COI-219) `{ git }` parses and the pin is `coil.lock` `rev` + `content_hash`. Native libs stay on `[ffi] search_paths` until [COI-60](https://linear.app/ardax/issue/COI-60).

## Sibling checkout

Clone this repo next to your project and coil-stdlib. In the consumer `coil.toml`:

```toml
[module]
roots = ["./src", "../coil-json/src", "../coil-stdlib/src"]

[ffi]
search_paths = ["../coil-json/native"]
```

`roots` is what loads `src/json.hy`. `[ffi] search_paths` is a placeholder until native artifacts ship. The compiler does not follow path deps for discovery.

## Git dep and coil.lock

`{ git }` is the parseable form. `version` is optional schema, not a tag. `rev` on the dep is stored only. Do not run `spool add`. There is no public spool CLI.

```toml
[dependencies]
json = { git = "https://github.com/ardax-corp/coil-json.git" }

[module]
roots = ["./src", "./.spool/deps/json/src", "../coil-stdlib/src"]

[ffi]
search_paths = ["./.spool/deps/json/native"]
```

This repo has no tags. The pin is `coil.lock` `rev` + `content_hash`. Omit `tag`. Use sibling checkout until spool materializes `.spool/deps`. The compiler does not read `coil.lock` and does not inject roots.

```
# spool lockfile v1
[[package]]
name = 'json'
git = 'https://github.com/ardax-corp/coil-json.git'
rev = '<commit SHA>'
content_hash = '<tree SHA>'
```

`rev` is the commit. `content_hash` is that commit's git tree (`git rev-parse 'HEAD^{tree}'`). Replace both when you move the pin.

The native basename will be `coil_json` (`libcoil_json.so` / `.dylib` / `coil_json.dll`). Nothing is built here yet.
