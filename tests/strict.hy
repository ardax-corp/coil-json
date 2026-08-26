// Round-trip and error-position tests for Json::strict (COI-55).
// Test bodies use assert's string error; JSON Results are matched, not `?`.
use json::{Json, JsonValue, JsonError};
use string::{from_bytes, to_bytes};

fn codec() -> Json {
    return Json::strict();
}

fn must_decode(string s) -> JsonValue {
    return match codec().decode_str(s) {
        Result::Ok(v) => v,
        Result::Err(_) => panic "decode failed",
    };
}

fn must_encode(JsonValue v) -> string {
    return match codec().encode_str(v) {
        Result::Ok(s) => s,
        Result::Err(_) => panic "encode failed",
    };
}

fn bytes_to_s(Vec<byte> b) -> string {
    return match from_bytes(b) {
        Result::Ok(s) => s,
        Result::Err(_) => panic "utf8",
    };
}

fn is_invalid(Result<JsonValue, JsonError> r) -> bool {
    return match r {
        Result::Ok(_) => false,
        Result::Err(e) => match e {
            JsonError::Invalid { line, column } => line >= 1 && column >= 1,
            _ => false,
        },
    };
}

test("empty object") {
    let v = must_decode("{}");
    assert(v.is_object() && v.object_len() == 0, "decode {}")?;
    assert(must_encode(v) == "{}")?;
}

test("empty array") {
    let v = must_decode("[]");
    assert(v.is_array() && v.array_len() == 0, "decode []")?;
    assert(must_encode(v) == "[]")?;
}

test("null bool string") {
    assert(must_decode("null").is_null(), "null")?;
    assert(must_decode("true").is_bool() && must_decode("true").flag, "true")?;
    assert(must_decode("false").is_bool() && !must_decode("false").flag, "false")?;
    assert(must_decode("\"hi\"").is_string() && must_decode("\"hi\"").s == "hi", "string")?;
    assert(must_encode(JsonValue::null()) == "null")?;
    assert(must_encode(JsonValue::from_bool(true)) == "true")?;
    assert(must_encode(JsonValue::from_bool(false)) == "false")?;
    assert(must_encode(JsonValue::from_string("hi")) == "\"hi\"")?;
}

test("int and float") {
    let z = must_decode("0");
    assert(z.is_int() && z.i == 0, "0")?;
    let n = must_decode("-42");
    assert(n.is_int() && n.i == (0 - 42), "-42")?;
    let f = must_decode("1.5");
    assert(f.is_float() && f.f > 1.4 && f.f < 1.6, "1.5")?;
    assert(must_encode(JsonValue::from_int(7)) == "7")?;
}

test("round-trip nested object and array") {
    let src = "{\"a\":[1,true,null],\"b\":\"x\"}";
    let v = must_decode(src);
    let out = must_encode(v);
    assert(out == src, "nested compact round-trip")?;
    let v2 = must_decode(out);
    assert(must_encode(v2) == src, "second encode")?;
}

test("whitespace around values") {
    let v = must_decode("  { \"k\" : [ 1 , false ] }  ");
    assert(must_encode(v) == "{\"k\":[1,false]}")?;
}

test("string escapes") {
    let v = must_decode("\"a\\n\\t\\\"\\\\\"");
    assert(v.is_string() && v.s == "a\n\t\"\\", "escapes")?;
    assert(must_encode(v) == "\"a\\n\\t\\\"\\\\\"")?;
}

test("unicode escape") {
    let v = must_decode("\"\\u0041\"");
    assert(v.is_string() && v.s == "A", "u0041")?;
}

test("build object and encode") {
    let v = must_decode("{\"n\":1,\"ok\":true}");
    assert(v.is_object() && v.object_len() == 2, "two keys")?;
    assert(must_encode(v) == "{\"n\":1,\"ok\":true}")?;
}

test("bytes entry points") {
    let j = codec();
    let raw = to_bytes("[null]");
    let v = match j.decode(raw) {
        Result::Ok(x) => x,
        Result::Err(_) => panic "decode bytes",
    };
    let encoded = match j.encode(v) {
        Result::Ok(b) => b,
        Result::Err(_) => panic "encode bytes",
    };
    assert(bytes_to_s(encoded) == "[null]")?;
}

test("invalid json has line and column") {
    assert(is_invalid(codec().decode_str("{")), "unclosed object")?;
}

test("invalid on second line") {
    let r = codec().decode_str("[\n1,]");
    assert(match r {
        Result::Ok(_) => false,
        Result::Err(e) => match e {
            JsonError::Invalid { line, column } => line == 2 && column >= 1,
            _ => false,
        },
    }, "trailing comma line 2")?;
}

test("trailing junk is invalid") {
    assert(is_invalid(codec().decode_str("true false")), "trailing junk")?;
}

test("leading zero is invalid") {
    assert(is_invalid(codec().decode_str("01")), "leading zero")?;
}

test("empty input is invalid") {
    let r = codec().decode_str("");
    assert(match r {
        Result::Ok(_) => false,
        Result::Err(e) => match e {
            JsonError::Invalid { line, column } => line == 1 && column == 1,
            _ => false,
        },
    }, "empty")?;
}
