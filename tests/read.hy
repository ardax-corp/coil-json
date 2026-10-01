// Read API: get / at / keys / as_* on decoded values.
use json::{Json, JsonValue};

fn must_decode(string s) -> JsonValue {
    return match Json::strict().decode_str(s) {
        Result::Ok(v) => v,
        Result::Err(_) => panic "decode failed",
    };
}

fn str_of(Option<JsonValue> v) -> string {
    return match v {
        Option::Some(x) => match x.as_str() {
            Option::Some(s) => s,
            Option::None => "<not a string>",
        },
        Option::None => "<absent>",
    };
}

fn int_of(Option<JsonValue> v) -> int {
    return match v {
        Option::Some(x) => match x.as_int() {
            Option::Some(n) => n,
            Option::None => -1,
        },
        Option::None => -2,
    };
}

fn is_absent(Option<JsonValue> v) -> bool {
    return match v {
        Option::Some(_) => false,
        Option::None => true,
    };
}

test("get reads object members") {
    let v = must_decode("{\"a\":\"x\",\"b\":7,\"a\":\"dup\"}");
    assert(str_of(v.get("a")) == "x", "first of duplicate keys")?;
    assert(int_of(v.get("b")) == 7, "int member")?;
    assert(is_absent(v.get("c")), "missing key")?;
}

test("get on a non-object is None") {
    let v = must_decode("[1,2]");
    assert(is_absent(v.get("a")), "array has no members")?;
}

test("at reads array elements") {
    let v = must_decode("[\"p\",{\"k\":3},null]");
    assert(str_of(v.at(0)) == "p", "first element")?;
    let obj = match v.at(1) {
        Option::Some(o) => o,
        Option::None => panic "element 1 missing",
    };
    assert(int_of(obj.get("k")) == 3, "nested object")?;
    let last = match v.at(2) {
        Option::Some(o) => o,
        Option::None => panic "element 2 missing",
    };
    assert(last.is_null(), "null element")?;
    assert(is_absent(v.at(3)), "past the end")?;
    assert(is_absent(v.at(-1)), "negative index")?;
}

test("keys keeps document order") {
    let ks = must_decode("{\"z\":1,\"a\":2}").keys();
    assert(len(ks) == 2, "two keys")?;
    assert(ks[0] == "z" && ks[1] == "a", "order")?;
    assert(len(must_decode("[1]").keys()) == 0, "array has no keys")?;
}

test("as_* match only their own type") {
    let v = must_decode("{\"s\":\"t\",\"i\":-4,\"f\":1.5,\"b\":true}");
    let b = match v.get("b") {
        Option::Some(x) => x,
        Option::None => panic "b missing",
    };
    let on = match b.as_bool() {
        Option::Some(x) => x,
        Option::None => false,
    };
    assert(on, "bool")?;
    assert(int_of(v.get("i")) == -4, "negative int")?;
    assert(int_of(v.get("f")) == -1, "float is not an int")?;
    assert(str_of(v.get("i")) == "<not a string>", "int is not a string")?;
    let f = match v.get("f") {
        Option::Some(x) => x,
        Option::None => panic "f missing",
    };
    let got = match f.as_float() {
        Option::Some(x) => x,
        Option::None => 0.0,
    };
    assert(got == 1.5, "float")?;
}
