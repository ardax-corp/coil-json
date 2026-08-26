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

fn is_utf8(Result<JsonValue, JsonError> r) -> bool {
    return match r {
        Result::Ok(_) => false,
        Result::Err(e) => match e {
            JsonError::Utf8 { line, column } => line >= 1 && column >= 1,
            _ => false,
        },
    };
}

fn encode_is_number(Result<string, JsonError> r) -> bool {
    return match r {
        Result::Ok(_) => false,
        Result::Err(e) => match e {
            JsonError::Number { line, column } => line >= 1 && column >= 1,
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

test("from_float encode and scientific decode") {
    assert(must_encode(JsonValue::from_float(1.5)) == "1.5")?;
    let two = must_encode(JsonValue::from_float(2.0));
    assert(two == "2.0")?;
    let a = must_decode("1e2");
    assert(a.is_float() && a.f > 99.9 && a.f < 100.1, "1e2")?;
    let b = must_decode("1E-1");
    let lo = 1.0 / 20.0;
    let hi = 1.0 / 5.0;
    assert(b.is_float() && b.f > lo && b.f < hi, "1E-1")?;
}

test("duplicate keys kept in encounter order") {
    let v = must_decode("{\"a\":1,\"b\":2,\"a\":3}");
    assert(v.is_object() && v.object_len() == 3, "three members")?;
    assert(must_encode(v) == "{\"a\":1,\"b\":2,\"a\":3}")?;
}

test("lone surrogate is utf8") {
    assert(is_utf8(codec().decode_str("\"\\uD800\"")), "JsonError::Utf8")?;
}

test("non-finite float encode is number") {
    let nan = sqrt(0.0 - 1.0);
    assert(encode_is_number(codec().encode_str(JsonValue::from_float(nan))), "NaN")?;
    let inf = exp(1000.0);
    assert(encode_is_number(codec().encode_str(JsonValue::from_float(inf))), "Inf")?;
}

test("unterminated string is invalid") {
    assert(is_invalid(codec().decode_str("\"hello")), "unterminated")?;
}

test("raw control char in string is invalid") {
    assert(is_invalid(codec().decode_str("\"a\nb\"")), "raw newline")?;
}
