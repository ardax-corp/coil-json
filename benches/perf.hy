// Decode/encode timing. Not part of `coil test`.
// Run: coil --opt-level aggressive benches/perf.hy
use json::{Json, JsonValue};
use clock::{mono_nanos};
use io::{stdout, write};
use string::{format, to_bytes, from_bytes};

fn push_str(Vec<byte> out, string s) {
    let b = to_bytes(s);
    let i = 0;
    while i < len(b) {
        out.push(b[i]);
        i = i + 1;
    }
}

fn push_int(Vec<byte> out, int n) {
    if n == 0 {
        out.push("0" as byte);
        return;
    }
    let buf: Vec<byte> = Vec::new();
    let v = n;
    while v > 0 {
        let d = v % 10;
        buf.push((("0" as byte as int) + d) as byte);
        v = v / 10;
    }
    let i = len(buf);
    while i > 0 {
        i = i - 1;
        out.push(buf[i]);
    }
}

fn as_string(Vec<byte> b) -> string {
    return match from_bytes(b) {
        Result::Ok(s) => s,
        Result::Err(_) => "",
    };
}

fn ints_doc(int n) -> string {
    let out: Vec<byte> = Vec::with_capacity(n * 4);
    out.push("[" as byte);
    let i = 0;
    while i < n {
        if i > 0 {
            out.push("," as byte);
        }
        push_int(out, i);
        i = i + 1;
    }
    out.push("]" as byte);
    return as_string(out);
}

fn strings_doc(int n) -> string {
    let out: Vec<byte> = Vec::with_capacity(n * 24);
    out.push("[" as byte);
    let i = 0;
    while i < n {
        if i > 0 {
            out.push("," as byte);
        }
        push_str(out, "\"item-");
        push_int(out, i);
        push_str(out, "\"");
        i = i + 1;
    }
    out.push("]" as byte);
    return as_string(out);
}

fn objects_doc(int n) -> string {
    let out: Vec<byte> = Vec::with_capacity(n * 48);
    out.push("[" as byte);
    let i = 0;
    while i < n {
        if i > 0 {
            out.push("," as byte);
        }
        push_str(out, "{\"id\":");
        push_int(out, i);
        push_str(out, ",\"name\":\"item-");
        push_int(out, i);
        push_str(out, "\",\"ok\":true}");
        i = i + 1;
    }
    out.push("]" as byte);
    return as_string(out);
}

fn pretty_doc(int n) -> string {
    let out: Vec<byte> = Vec::with_capacity(n * 8);
    push_str(out, "[\n");
    let i = 0;
    while i < n {
        push_str(out, "  ");
        push_int(out, i);
        if i + 1 < n {
            push_str(out, ",\n");
        } else {
            push_str(out, "\n");
        }
        i = i + 1;
    }
    push_str(out, "]\n");
    return as_string(out);
}

fn must_decode(Json j, string doc) -> JsonValue {
    return match j.decode_str(doc) {
        Result::Ok(v) => v,
        Result::Err(_) => panic "decode",
    };
}

fn must_encode(Json j, JsonValue v) -> int {
    return match j.encode(v) {
        Result::Ok(b) => len(b),
        Result::Err(_) => panic "encode",
    };
}

fn report(string name, int reps, int decode_ns, int encode_ns, int out_len, int sink) {
    write(
        stdout(),
        to_bytes(format(
            "%s reps=%i decode_ns=%i encode_ns=%i out=%i sink=%i\n",
            name,
            reps,
            decode_ns,
            encode_ns,
            out_len,
            sink,
        )),
    );
}

fn bench(string name, string doc, int reps) {
    let j = Json::strict();
    let warm = must_decode(j, doc);
    let warm_len = must_encode(j, warm);
    let t0 = mono_nanos();
    let i = 0;
    let sink = 0;
    while i < reps {
        let decoded = must_decode(j, doc);
        if decoded.is_array() {
            sink = sink + 1;
        }
        i = i + 1;
    }
    let t1 = mono_nanos();
    let v = must_decode(j, doc);
    let t2 = mono_nanos();
    let i2 = 0;
    let out_len = warm_len;
    while i2 < reps {
        out_len = must_encode(j, v);
        i2 = i2 + 1;
    }
    let t3 = mono_nanos();
    report(name, reps, t1 - t0, t3 - t2, out_len, sink);
}

fn main() {
    bench("ints", ints_doc(400), 30);
    bench("strings", strings_doc(200), 20);
    bench("objects", objects_doc(80), 20);
    bench("pretty", pretty_doc(200), 20);
}
