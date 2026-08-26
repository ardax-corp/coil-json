# coil-json

Userland JSON for [coil](https://github.com/ardax-corp/coil-lang). Package name is `json`, so `use json::{Json, JsonValue, JsonError}` resolves here. Native lib basename is `coil_json` once the FFI lands ([COI-53](https://linear.app/ardax/issue/COI-53)).

This package owns strict one-shot encode/decode ([COI-55](https://linear.app/ardax/issue/COI-55)). coil-stdlib must not `use json`. There is no `src/codec/json.hy` here or in stdlib.

## API

```coil
use json::{Json, JsonValue, JsonError};

let j = Json::strict();
let v = j.decode_str("{\"a\":[1,true,null]}")?;
let bytes = j.encode(v)?;
```

`Json::strict()` is RFC 8259 only. Invalid input returns `JsonError` with 1-based line/column (`Invalid`, `Io`, `Utf8`, `Number`), not panic.

| Method | Role |
|--------|------|
| `Json::strict()` | Strict codec |
| `decode` / `encode` | `Vec<byte>` |
| `decode_str` / `encode_str` | UTF-8 string helpers |

`JsonValue` is a class (not an enum). Coil named modules do not unify recursive `Vec<JsonValue>` (`JsonValue` vs `json::JsonValue`), and `FFIType` already owns `Bool`/`Int`/`Float`/`String`. The tree is an arena of primitive vecs; a `JsonValue` is a `(store, idx)` handle.

Object representation: ordered children. Each object member is a child node whose `keys[child]` is the member name. Duplicates are kept in encounter order. Not a HashMap. Packed IR inflate/deflate stays [COI-54](https://linear.app/ardax/issue/COI-54).

Numbers: a token with no `.` / `e` / `E` that fits in i64 is an int; otherwise float. Overflow and non-finite floats are `JsonError::Number`.

## Layout

| Path | Role |
|------|------|
| `src/json.hy` | `Json`, `JsonValue`, `JsonError`, Coil-side parser/stringify |
| `coil.toml` | `[package] name = "json"` so `use json::{…}` resolves |
| `native/` | `[ffi] search_paths` placeholder. Not shipped |

## Consume

Sibling checkout, or a git dep plus `coil.lock` pin. Call `Json::strict()` from [docs/consume.md](docs/consume.md).

```toml
[dependencies]
json = { git = "https://github.com/ardax-corp/coil-json.git" }
```

`{ git }` is the parseable form. `version` is optional schema, not a tag. The pin is `coil.lock` `rev` + `content_hash`. coil-stdlib is a sibling `[module] roots` entry, not a spool dependency of this package. Native libs stay on `[ffi] search_paths` until [COI-60](https://linear.app/ardax/issue/COI-60).

## License

MIT. See [LICENSE](LICENSE).
