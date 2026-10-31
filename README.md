# coil-json

Userland JSON for [coil](https://github.com/ardax-corp/coil-lang). Package name is `json`, so `use json::{Json, JsonValue, JsonError}` resolves here.

Pure Coil, no native library. One module, `json` (`src/json.hy`): the `Json` codec, the `JsonValue` handle it decodes to, and the `JsonError` it reports.

## Example

```coil
use json::{Json, JsonValue, JsonError};
use io::sync::{println};
use string::{format};

fn main() {
    let j = Json::strict();
    match j.decode_str("{\"name\":\"coil\",\"tags\":[\"vm\",\"lang\"]}") {
        Result::Ok(v) => {
            let name = v.get("name").map_or("?", fn (JsonValue n) => n.as_str().unwrap_or("?"));
            println(name)?;
            println(j.encode_str(v).unwrap_or("encode failed"))?;
        },
        Result::Err(JsonError::Invalid { line, column }) => {
            println(format("invalid JSON at %i:%i", line, column))?;
        },
        Result::Err(_) => {
            println("bad number or UTF-8")?;
        },
    }
}
```

Run it with `coil --root ../coil-stdlib/src --root ../coil-json/src main.hy` (prints `coil`, then the compact document).

## API

`Json::strict()` is RFC 8259 only. `Json::jsonc()` is parse-only sugar: comments and trailing commas on decode; encode stays RFC 8259; not JSON5. Invalid input returns `JsonError` with 1-based line/column (`Invalid`, `Utf8`, `Number`), not panic.

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

Numbers: a token with no `.` / `e` / `E` that fits in i64 is an int; otherwise it is a float. A float that is not finite is `JsonError::Number`.

## Layout

| Path | Role |
|------|------|
| `src/json.hy` | `Json`, `JsonValue`, `JsonError`, Coil-side parser/stringify |
| `coil.toml` | spool manifest (`[package] name = "json"`); coil does not read it |

## Consume

```bash
spool add json --git https://github.com/ardax-corp/coil-json.git --rev <commit SHA>
```

No tags yet, so pin a commit. Without spool, pass `--root ../coil-json/src` to `coil`. More call patterns are in [docs/consume.md](docs/consume.md).

## Test

```bash
coil test --root ../coil-stdlib/src
```

This runs `tests/` and the examples in the `///` docs of `src/json.hy`.

## License

MIT. See [LICENSE](LICENSE).
