# Consuming coil-json

This package is `json`. `use json::{Json, JsonValue, JsonError}` resolves from `src/json.hy`. Strict one-shot encode/decode ships here. coil-stdlib is a sibling `[module] roots` entry, not a dependency of this package. Do not add a `codec` spool dep. Do not `use json` from stdlib.

Coil-to-Coil deps will be spool-owned once a public `spool` CLI exists. Until [COI-219](https://linear.app/ardax/issue/COI-219) `{ git }` parses and the pin is `coil.lock` `rev` + `content_hash`.

## Sibling checkout

Clone this repo next to your project and coil-stdlib. In the consumer `coil.toml`:

```toml
[module]
roots = ["./src", "../coil-json/src", "../coil-stdlib/src"]
```

`roots` is what loads `src/json.hy`. The compiler does not follow path deps for discovery.

## Git dep and coil.lock

`{ git }` is the parseable form. `version` is optional schema, not a tag. `rev` on the dep is stored only. Do not run `spool add`. There is no public spool CLI.

```toml
[dependencies]
json = { git = "https://github.com/ardax-corp/coil-json.git" }

[module]
roots = ["./src", "./.spool/deps/json/src", "../coil-stdlib/src"]
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

## Call Json::strict()

Signatures are in [`src/json.hy`](../src/json.hy). Call patterns are in [`tests/strict.hy`](../tests/strict.hy). `Json::strict()` is RFC 8259 one-shot.

`Json::jsonc()` is parse-only sugar: comments and trailing commas on decode. Encode stays RFC 8259. Not JSON5.

```coil
use json::{Json, JsonValue, JsonError};

let j = Json::strict();
let v = j.decode_str("{\"a\":[1,true,null],\"b\":\"x\"}")?;
let s = j.encode_str(v)?;
let bytes = j.encode(v)?;
```

`decode_str` takes `string` and returns `Result<JsonValue, JsonError>`. `encode_str` takes `JsonValue` and returns `Result<string, JsonError>`. `decode` takes `Vec<byte>` and returns `Result<JsonValue, JsonError>`. `encode` takes `JsonValue` and returns `Result<Vec<byte>, JsonError>`. Encode is compact. No extra spaces.

`decode_str` is `to_bytes` then `decode`. `encode_str` is `encode` then `from_bytes`. A `from_bytes` failure on encode is `JsonError::Utf8`.

```coil
use json::{Json, JsonValue, JsonError};
use string::{to_bytes};

let j = Json::strict();
let v = j.decode(to_bytes("[null]"))?;
let encoded = j.encode(v)?;
```

`string` comes from coil-stdlib via `[module] roots`, not from this package.

### JsonValue

`JsonValue` is a class plus arena handle, not an enum. The tree is an arena of primitive vecs. A `JsonValue` is a `(store, idx)` handle. Named-module recursive `Vec<JsonValue>` does not unify (`JsonValue` vs `json::JsonValue`).

Scalar constructors:

```coil
JsonValue::null()
JsonValue::from_bool(true)
JsonValue::from_int(7)
JsonValue::from_float(1.5)
JsonValue::from_string("hi")
```

`encode_str` of `null()`, `from_bool(true)`, `from_int(7)`, and `from_string("hi")` yields `null`, `true`, `7`, and `"hi"`.

Predicates: `is_null`, `is_bool`, `is_int`, `is_float`, `is_string`, `is_array`, `is_object`. Lengths: `array_len`, `object_len`. Scalar payloads on the handle are `flag`, `i`, `f`, `s`.

```coil
let t = j.decode_str("true")?;
let is_true = t.is_bool() && t.flag;

let n = j.decode_str("-42")?;
let is_neg = n.is_int() && n.i == (0 - 42);

let s = j.decode_str("\"hi\"")?;
let is_hi = s.is_string() && s.s == "hi";

let o = j.decode_str("{\"n\":1,\"ok\":true}")?;
let two = o.is_object() && o.object_len() == 2;
```

Nested objects and arrays come from decode. There is no `from_array` or `from_object`. Objects are ordered children. Duplicate keys are kept in encounter order. Not a HashMap.

A number token with no `.` / `e` / `E` that fits in i64 is an int. Otherwise it is a float.

### JsonError

```coil
enum JsonError {
    Invalid { line: int, column: int },
    Io { line: int, column: int },
    Utf8 { line: int, column: int },
    Number { line: int, column: int },
}
```

`line` and `column` are 1-based. Column counts bytes in the line. Malformed input returns `JsonError::Invalid` with position, not a panic. `tests/strict.hy` matches `Invalid` for empty input at 1,1, a trailing comma on line 2, a leading zero, and trailing junk.

```coil
match j.decode_str("{") {
    Result::Ok(_) => false,
    Result::Err(e) => match e {
        JsonError::Invalid { line, column } => line >= 1 && column >= 1,
        _ => false,
    },
}
```

`Number` and `Utf8` are on the enum. Extra cases are [COI-222](https://linear.app/ardax/issue/COI-222).

### stdlib

coil-stdlib must never `use json`. There is no `src/codec/json.hy` here or in stdlib. Do not add a `codec` spool dep.
