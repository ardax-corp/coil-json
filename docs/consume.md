# Consuming coil-json

This package is `json`. `use json::{Json, JsonValue, JsonError}` resolves from `src/json.coil`. Strict one-shot encode/decode ships here. coil-stdlib is not a dependency of this package. Do not add a `codec` spool dep. Do not `use json` from stdlib.

## Depend on it

With [spool](https://github.com/ardax-corp/spool):

```bash
spool add json --git https://github.com/ardax-corp/coil-json.git --rev <commit SHA>
```

This repo has no tags, so pin a commit with `--rev`. spool records the dep in `coil.toml`, writes `coil.lock` (`rev` + `content_hash`), links `.spool/deps/json`, and passes `--root` for it and coil-stdlib to `coil` on `spool build` / `run` / `test`.

Without spool, clone this repo next to your project and pass the roots yourself. coil reads no `coil.toml` and no `coil.lock`.

```bash
coil --root ../coil-json/src main.coil
```

## Call Json::strict()

Signatures are in [`src/json.coil`](../src/json.coil). Call patterns are in [`tests/strict.coil`](../tests/strict.coil). `Json::strict()` is RFC 8259 one-shot.

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

`string` is a compiler built-in module, not from this package.

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
    Utf8 { line: int, column: int },
    Number { line: int, column: int },
}
```

`line` and `column` are 1-based. Column counts bytes in the line. Malformed input returns `JsonError::Invalid` with position, not a panic. `tests/strict.coil` matches `Invalid` for empty input at 1,1, a trailing comma on line 2, a leading zero, and trailing junk.

```coil
match j.decode_str("{") {
    Result::Ok(_) => false,
    Result::Err(e) => match e {
        JsonError::Invalid { line, column } => line >= 1 && column >= 1,
        default => false,
    },
}
```

`Number` and `Utf8` are on the enum.

### stdlib

coil-stdlib must never `use json`. There is no `src/codec/json.coil` here or in stdlib. Do not add a `codec` spool dep.
