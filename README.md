# coil-json

Userland JSON for [coil](https://github.com/ardax-corp/coil-lang). Package name is `json`, so `use json::{…}` resolves here. Native lib basename is `coil_json` (`libcoil_json.so` / `.dylib` / `coil_json.dll`) once the FFI lands.

This repo is an empty package scaffold. The living codec is still [coil-stdlib](https://github.com/ardax-corp/coil-stdlib) `src/codec/json.hy` ([COI-40](https://linear.app/ardax/issue/COI-40)). It stays there until a later strip. Do not copy it into this tree.

## Scope

Later work here is strict RFC 8259 and JSONC (comments + trailing commas), streaming over `io::Stream`, and FFI to a native parser. Native artifact delivery is [COI-60](https://linear.app/ardax/issue/COI-60). Nothing in that list ships in this scaffold.

## Layout

| Path | Role |
|------|------|
| `src/json.hy` | Package root. Empty stub, no parse/stringify |
| `coil.toml` | `[package] name = "json"` so `use json::{…}` resolves |
| `native/` | `[ffi] search_paths` placeholder. Not shipped |

## Consume

Sibling checkout, or a git dep plus `coil.lock` pin. See [docs/consume.md](docs/consume.md).

```toml
[dependencies]
json = { git = "https://github.com/ardax-corp/coil-json.git" }
```

`{ git }` is the parseable form. `version` is optional schema, not a tag. The pin is `coil.lock` `rev` + `content_hash`. coil-stdlib is a sibling `[module] roots` entry, not a spool dependency of this package. Native libs stay on `[ffi] search_paths` until [COI-60](https://linear.app/ardax/issue/COI-60).

## License

MIT. See [LICENSE](LICENSE).
