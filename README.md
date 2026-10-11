# coil-json

Userland JSON for [coil](https://github.com/ardax-corp/coil-lang). Package name is `json`, so `use json::{Json, JsonValue, JsonError}` resolves here.

This package owns one-shot encode/decode ([COI-55](https://linear.app/ardax/issue/COI-55)) and JSONC parse mode ([COI-56](https://linear.app/ardax/issue/COI-56)). coil-stdlib must not `use json`. There is no `src/codec/json.hy` here or in stdlib.

## API

```coil
use json::{Json, JsonValue, JsonError};

let j = Json::strict();
let v = j.decode_str("{\"a\":[1,true,null]}")?;
let bytes = j.encode(v)?;

let c = Json::jsonc();
let v2 = c.decode_str("// cfg\n{ \"a\": 1, }")?;
```

`Json::strict()` is RFC 8259 only. `Json::jsonc()` is parse-only sugar: comments and trailing commas on decode; encode stays RFC 8259; not JSON5. Invalid input returns `JsonError` with 1-based line/column (`Invalid`, `Io`, `Utf8`, `Number`), not panic.

| Method | Role |
|--------|------|
| `Json::strict()` | Strict RFC 8259 codec |
| `Json::jsonc()` | Same encode; decode allows comments and trailing commas |
| `decode` / `encode` | `Vec<byte>` |
| `decode_str` / `encode_str` | UTF-8 string helpers |

Reading a decoded value:

| Method | Role |
|--------|------|
| `is_null()` … `is_object()` | type checks |
| `get(key)` | object member (first match) or `None` |
| `at(i)` | array element or `None` |
| `keys()` | object member names in order |
| `as_str()` / `as_int()` / `as_float()` / `as_bool()` | the value when it has that type, else `None` |
| `array_len()` / `object_len()` | child counts |

`JsonValue` is a class (not an enum). Coil named modules do not unify recursive `Vec<JsonValue>` (`JsonValue` vs `json::JsonValue`), and `FFIType` already owns `Bool`/`Int`/`Float`/`String`. The tree is an arena of primitive vecs; a `JsonValue` is a `(store, idx)` handle.

Object representation: ordered children. Each object member is a child node whose `keys[child]` is the member name. Duplicates are kept in encounter order. Not a HashMap.

Numbers: a token with no `.` / `e` / `E` that fits in i64 is an int; otherwise float. Overflow and non-finite floats are `JsonError::Number`.

## Layout

| Path | Role |
|------|------|
| `src/json.hy` | `Json`, `JsonValue`, `JsonError`, Coil-side parser/stringify |
| `coil.toml` | spool manifest (`[package] name = "json"`); coil does not read it |

## Consume

```bash
spool add json --git https://github.com/ardax-corp/coil-json.git --rev <commit SHA>
```

No tags yet, so pin a commit. Without spool, pass `--root ../coil-json/src` to `coil`. Call `Json::strict()` from [docs/consume.md](docs/consume.md).

## License

MIT. See [LICENSE](LICENSE).
