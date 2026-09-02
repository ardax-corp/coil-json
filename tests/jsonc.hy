// JSONC decode tests for Json::jsonc (COI-56). Encode stays RFC 8259.
// Test bodies use assert's string error; JSON Results are matched, not `?`.
use json::{Json, JsonValue, JsonError};

fn jsonc() -> Json {
    return Json::jsonc();
}

fn strict() -> Json {
    return Json::strict();
}

fn must_decode(string s) -> JsonValue {
    return match jsonc().decode_str(s) {
        Result::Ok(v) => v,
        Result::Err(_) => panic "decode failed",
    };
}

fn must_encode(JsonValue v) -> string {
    return match jsonc().encode_str(v) {
        Result::Ok(s) => s,
        Result::Err(_) => panic "encode failed",
    };
}

fn is_invalid(Result<JsonValue, JsonError> r) -> bool {
    return match r {
        Result::Ok(_) => false,
        Result::Err(e) => match e {
            JsonError::Invalid { line, column } => line >= 1 && column >= 1,
            default => false,
        },
    };
}

test("line comment") {
    let v = must_decode("// leading\n{\"a\":1}");
    assert(v.is_object() && v.object_len() == 1, "line comment")?;
    assert(must_encode(v) == "{\"a\":1}")?;
}

test("block comment") {
    let v = must_decode("/* c */[1,2]");
    assert(v.is_array() && v.array_len() == 2, "block comment")?;
    assert(must_encode(v) == "[1,2]")?;
}

test("line and block comments together") {
    let v = must_decode("// top\n/* mid */ { \"a\": 1 } // end\n");
    assert(must_encode(v) == "{\"a\":1}")?;
}

test("trailing comma array") {
    let v = must_decode("[1,]");
    assert(v.is_array() && v.array_len() == 1, "[1,]")?;
    assert(must_encode(v) == "[1]")?;
}

test("trailing comma object") {
    let v = must_decode("{ \"a\": 1, }");
    assert(v.is_object() && v.object_len() == 1, "object trailing comma")?;
    assert(must_encode(v) == "{\"a\":1}")?;
}

test("comment after trailing comma") {
    let v = must_decode("[1, /* c */ ]");
    assert(must_encode(v) == "[1]")?;
    let o = must_decode("{\"a\":1, // c\n}");
    assert(must_encode(o) == "{\"a\":1}")?;
}

test("jsonc encode is strict json") {
    let v = must_decode("// c\n{ \"a\": 1, }");
    let out = must_encode(v);
    assert(out == "{\"a\":1}", "no comments or trailing comma")?;
    let back = match strict().decode_str(out) {
        Result::Ok(x) => x,
        Result::Err(_) => panic "strict should accept encoded",
    };
    assert(must_encode(back) == out)?;
}

test("strict rejects comments and trailing commas") {
    assert(is_invalid(strict().decode_str("// c\n1")), "line comment")?;
    assert(is_invalid(strict().decode_str("/* c */1")), "block comment")?;
    assert(is_invalid(strict().decode_str("// t\n/* b */ 1")), "both")?;
    assert(is_invalid(strict().decode_str("[1,]")), "[1,]")?;
    assert(is_invalid(strict().decode_str("{ \"a\": 1, }")), "object trailing")?;
    assert(is_invalid(strict().decode_str("[1, /* c */ ]")), "comment after comma")?;
}

test("jsonc still rejects json5") {
    assert(is_invalid(jsonc().decode_str("'hi'")), "single quotes")?;
    assert(is_invalid(jsonc().decode_str("{a:1}")), "unquoted key")?;
    assert(is_invalid(jsonc().decode_str("0x1")), "hex")?;
    assert(is_invalid(jsonc().decode_str("# c\n1")), "hash comment")?;
}

test("unterminated block comment is invalid") {
    let r = jsonc().decode_str("/* never");
    assert(match r {
        Result::Ok(_) => false,
        Result::Err(e) => match e {
            JsonError::Invalid { line, column } => line >= 1 && column >= 1,
            default => false,
        },
    }, "unterminated /*")?;
}

test("leading plus is invalid") {
    assert(is_invalid(jsonc().decode_str("+1")), "+1")?;
}

test("leading and trailing decimal point is invalid") {
    assert(is_invalid(jsonc().decode_str(".5")), ".5")?;
    assert(is_invalid(jsonc().decode_str("5.")), "5.")?;
}

test("infinity and nan are invalid") {
    assert(is_invalid(jsonc().decode_str("Infinity")), "Infinity")?;
    assert(is_invalid(jsonc().decode_str("NaN")), "NaN")?;
}

test("nested block comments are invalid") {
    assert(is_invalid(jsonc().decode_str("/* outer /* inner */ still */")), "nested /*")?;
}

test("comment markers inside strings stay content") {
    let v = must_decode("\"// not a comment\"");
    assert(v.is_string() && v.s == "// not a comment", "line marker")?;
    assert(must_encode(v) == "\"// not a comment\"")?;
    let b = must_decode("\"/* also not */\"");
    assert(b.is_string() && b.s == "/* also not */", "block marker")?;
    assert(must_encode(b) == "\"/* also not */\"")?;
}
