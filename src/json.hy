// Package root. Coil-side encode/decode (COI-55) plus jsonc parse mode (COI-56). Native FFI is COI-53.
// Named-module recursive `Vec<JsonValue>` does not unify (`JsonValue` vs `json::JsonValue`).
// The tree is an arena of primitive vecs; JsonValue is a (store, idx) handle.
use string::{from_bytes, to_bytes, format};

class Store {
    tags: Vec<int>,
    flags: Vec<bool>,
    ints: Vec<int>,
    floats: Vec<float>,
    strs: Vec<string>,
    keys: Vec<string>,
    first: Vec<int>,
    last: Vec<int>,
    next: Vec<int>,
}

impl Store {
    static fn new() -> Store {
        let tags: Vec<int> = Vec::new();
        let flags: Vec<bool> = Vec::new();
        let ints: Vec<int> = Vec::new();
        let floats: Vec<float> = Vec::new();
        let strs: Vec<string> = Vec::new();
        let keys: Vec<string> = Vec::new();
        let first: Vec<int> = Vec::new();
        let last: Vec<int> = Vec::new();
        let next: Vec<int> = Vec::new();
        return new Store(tags, flags, ints, floats, strs, keys, first, last, next);
    }

    fn add(int tag, bool flag, int n, float x, string s, string key) -> int {
        let idx = len(self.tags);
        self.tags.push(tag);
        self.flags.push(flag);
        self.ints.push(n);
        self.floats.push(x);
        self.strs.push(s);
        self.keys.push(key);
        self.first.push(-1);
        self.last.push(-1);
        self.next.push(-1);
        return idx;
    }

    fn attach(int parent, int child) {
        if self.first[parent] < 0 {
            self.first[parent] = child;
            self.last[parent] = child;
        } else {
            self.next[self.last[parent]] = child;
            self.last[parent] = child;
        }
    }

    fn count_children(int idx) -> int {
        let n = 0;
        let c = self.first[idx];
        while c >= 0 {
            n = n + 1;
            c = self.next[c];
        }
        return n;
    }
}

/// Strict JSON value. Objects are ordered children (`keys[child]` / child nodes).
class JsonValue {
    store: Store,
    idx: int,
    tag: int,
    flag: bool,
    i: int,
    f: float,
    s: string,
}

/// Decode/encode failure. `line` and `column` are 1-based (column counts bytes in the line).
enum JsonError {
    Invalid { line: int, column: int },
    Io { line: int, column: int },
    Utf8 { line: int, column: int },
    Number { line: int, column: int },
}

class Parser {
    bytes: Vec<byte>,
    i: int,
    line: int,
    col: int,
    store: Store,
    jsonc: bool,
}

impl JsonValue {
    static fn wrap(Store store, int idx) -> JsonValue {
        return new JsonValue(
            store,
            idx,
            store.tags[idx],
            store.flags[idx],
            store.ints[idx],
            store.floats[idx],
            store.strs[idx],
        );
    }

    static fn null() -> JsonValue {
        let st = Store::new();
        let idx = st.add(0, false, 0, 0.0, "", "");
        return JsonValue::wrap(st, idx);
    }

    static fn from_bool(bool flag) -> JsonValue {
        let st = Store::new();
        let idx = st.add(1, flag, 0, 0.0, "", "");
        return JsonValue::wrap(st, idx);
    }

    static fn from_int(int n) -> JsonValue {
        let st = Store::new();
        let idx = st.add(2, false, n, 0.0, "", "");
        return JsonValue::wrap(st, idx);
    }

    pub static fn from_float(float x) -> JsonValue {
        let st = Store::new();
        let idx = st.add(3, false, 0, x, "", "");
        return JsonValue::wrap(st, idx);
    }

    static fn from_string(string s) -> JsonValue {
        let st = Store::new();
        let idx = st.add(4, false, 0, 0.0, s, "");
        return JsonValue::wrap(st, idx);
    }

    fn is_null() -> bool {
        return self.tag == 0;
    }

    fn is_bool() -> bool {
        return self.tag == 1;
    }

    fn is_int() -> bool {
        return self.tag == 2;
    }

    fn is_float() -> bool {
        return self.tag == 3;
    }

    fn is_string() -> bool {
        return self.tag == 4;
    }

    fn is_array() -> bool {
        return self.tag == 5;
    }

    fn is_object() -> bool {
        return self.tag == 6;
    }

    fn array_len() -> int {
        return self.store.count_children(self.idx);
    }

    fn object_len() -> int {
        return self.store.count_children(self.idx);
    }

    fn append_str(Vec<byte> out, string s) {
        let b = to_bytes(s);
        let i = 0;
        while i < len(b) {
            out.push(b[i]);
            i = i + 1;
        }
    }

    fn append_string(Vec<byte> out, string s) {
        out.push("\"" as byte);
        let b = to_bytes(s);
        let i = 0;
        let sixteen: int = 16;
        let bs: int = 8;
        let ht: int = 9;
        let lf: int = 10;
        let ff: int = 12;
        let cr: int = 13;
        let sp: int = 32;
        let ten: int = 10;
        while i < len(b) {
            let c: int = b[i] as int;
            if c == ("\"" as byte as int) {
                out.push("\\" as byte);
                out.push("\"" as byte);
            } else if c == ("\\" as byte as int) {
                out.push("\\" as byte);
                out.push("\\" as byte);
            } else if c == bs {
                out.push("\\" as byte);
                out.push("b" as byte);
            } else if c == ff {
                out.push("\\" as byte);
                out.push("f" as byte);
            } else if c == lf {
                out.push("\\" as byte);
                out.push("n" as byte);
            } else if c == cr {
                out.push("\\" as byte);
                out.push("r" as byte);
            } else if c == ht {
                out.push("\\" as byte);
                out.push("t" as byte);
            } else if c < sp {
                let hi = c / sixteen;
                let lo = c % sixteen;
                out.push("\\" as byte);
                out.push("u" as byte);
                out.push("0" as byte);
                out.push("0" as byte);
                if hi < ten {
                    out.push((("0" as byte as int) + hi) as byte);
                } else {
                    out.push((("a" as byte as int) + (hi - ten)) as byte);
                }
                if lo < ten {
                    out.push((("0" as byte as int) + lo) as byte);
                } else {
                    out.push((("a" as byte as int) + (lo - ten)) as byte);
                }
            } else {
                out.push(c as byte);
            }
            i = i + 1;
        }
        out.push("\"" as byte);
    }

    fn append_float(Vec<byte> out, float x) -> Result<(), JsonError> {
        if x != x {
            raise JsonError::Number { line: 1, column: 1 };
        }
        if x != 0.0 {
            if x * 2.0 == x {
                raise JsonError::Number { line: 1, column: 1 };
            }
        }
        let s = format("%f", x);
        let b = to_bytes(s);
        let n = len(b);
        if n == 0 {
            raise JsonError::Number { line: 1, column: 1 };
        }
        let i = 0;
        let has_dot = false;
        let has_exp = false;
        if b[0] == "-" {
            i = 1;
            if n == 1 {
                raise JsonError::Number { line: 1, column: 1 };
            }
        }
        while i < n {
            let c = b[i];
            if c == "." {
                has_dot = true;
            } else {
                if c == "e" || c == "E" {
                    has_exp = true;
                } else {
                    let digit = c >= "0" && c <= "9";
                    let signc = c == "+" || c == "-";
                    if !digit {
                        if !signc {
                            raise JsonError::Number { line: 1, column: 1 };
                        }
                    }
                }
            }
            i = i + 1;
        }
        let j = 0;
        while j < n {
            out.push(b[j]);
            j = j + 1;
        }
        if !has_dot && !has_exp {
            out.push("." as byte);
            out.push("0" as byte);
        }
        return ();
    }

    #[max_depth(256)]
    fn emit_idx(Vec<byte> out, int idx) -> Result<(), JsonError> {
        let tag = self.store.tags[idx];
        if tag == 0 {
            self.append_str(out, "null");
            return ();
        }
        if tag == 1 {
            if self.store.flags[idx] {
                self.append_str(out, "true");
            } else {
                self.append_str(out, "false");
            }
            return ();
        }
        if tag == 2 {
            self.append_str(out, format("%i", self.store.ints[idx]));
            return ();
        }
        if tag == 3 {
            self.append_float(out, self.store.floats[idx])?;
            return ();
        }
        if tag == 4 {
            self.append_string(out, self.store.strs[idx]);
            return ();
        }
        if tag == 5 {
            out.push("[" as byte);
            let c = self.store.first[idx];
            let first = true;
            while c >= 0 {
                if !first {
                    out.push("," as byte);
                }
                first = false;
                self.emit_idx(out, c)?;
                c = self.store.next[c];
            }
            out.push("]" as byte);
            return ();
        }
        if tag == 6 {
            out.push("{" as byte);
            let c = self.store.first[idx];
            let first = true;
            while c >= 0 {
                if !first {
                    out.push("," as byte);
                }
                first = false;
                self.append_string(out, self.store.keys[c]);
                out.push(":" as byte);
                self.emit_idx(out, c)?;
                c = self.store.next[c];
            }
            out.push("}" as byte);
            return ();
        }
        raise JsonError::Invalid { line: 1, column: 1 };
    }

    fn emit(Vec<byte> out) -> Result<(), JsonError> {
        return self.emit_idx(out, self.idx)?;
    }
}

impl Parser {
    fn at_end() -> bool {
        return self.i >= len(self.bytes);
    }

    fn bump() {
        if self.i >= len(self.bytes) {
            return;
        }
        let c = self.bytes[self.i];
        self.i = self.i + 1;
        if c == "\r" {
            self.line = self.line + 1;
            self.col = 1;
            if self.i < len(self.bytes) {
                if self.bytes[self.i] == "\n" {
                    self.i = self.i + 1;
                }
            }
        } else {
            if c == "\n" {
                self.line = self.line + 1;
                self.col = 1;
            } else {
                self.col = self.col + 1;
            }
        }
    }

    fn cur() -> byte {
        return self.bytes[self.i];
    }

    fn skip_ws() -> Result<(), JsonError> {
        while !self.at_end() {
            let c = self.cur();
            if c == " " || c == "\t" || c == "\n" || c == "\r" {
                self.bump();
                continue;
            }
            if !self.jsonc || c != "/" {
                break;
            }
            if self.i + 1 >= len(self.bytes) {
                break;
            }
            let n = self.bytes[self.i + 1];
            if n == "/" {
                self.bump();
                self.bump();
                while !self.at_end() {
                    let x = self.cur();
                    if x == "\n" || x == "\r" {
                        break;
                    }
                    self.bump();
                }
                continue;
            }
            if n != "*" {
                break;
            }
            self.bump();
            self.bump();
            let closed = false;
            while !self.at_end() {
                if self.cur() == "*" {
                    self.bump();
                    if !self.at_end() && self.cur() == "/" {
                        self.bump();
                        closed = true;
                        break;
                    }
                } else {
                    self.bump();
                }
            }
            if !closed {
                raise JsonError::Invalid { line: self.line, column: self.col };
            }
        }
        return ();
    }

    fn hex_val(byte c) -> int {
        if c >= "0" && c <= "9" {
            return (c as int) - ("0" as byte as int);
        }
        if c >= "a" && c <= "f" {
            return (c as int) - ("a" as byte as int) + 10;
        }
        if c >= "A" && c <= "F" {
            return (c as int) - ("A" as byte as int) + 10;
        }
        return -1;
    }

    fn push_cp(Vec<byte> out, int cp) -> Result<(), JsonError> {
        let n64: int = 64;
        let n128: int = 128;
        let n192: int = 192;
        let n224: int = 224;
        let n240: int = 240;
        let n4096: int = 4096;
        let n262144: int = 262144;
        if cp < 0 || cp > 1114111 {
            raise JsonError::Utf8 { line: self.line, column: self.col };
        }
        if cp >= 55296 && cp <= 57343 {
            raise JsonError::Utf8 { line: self.line, column: self.col };
        }
        if cp <= 127 {
            out.push(cp as byte);
            return ();
        }
        if cp <= 2047 {
            out.push((n192 + (cp / n64)) as byte);
            out.push((n128 + (cp % n64)) as byte);
            return ();
        }
        if cp <= 65535 {
            out.push((n224 + (cp / n4096)) as byte);
            out.push((n128 + ((cp / n64) % n64)) as byte);
            out.push((n128 + (cp % n64)) as byte);
            return ();
        }
        out.push((n240 + (cp / n262144)) as byte);
        out.push((n128 + ((cp / n4096) % n64)) as byte);
        out.push((n128 + ((cp / n64) % n64)) as byte);
        out.push((n128 + (cp % n64)) as byte);
        return ();
    }

    fn parse_hex4() -> Result<int, JsonError> {
        let n = 0;
        let k = 0;
        while k < 4 {
            if self.at_end() {
                raise JsonError::Invalid { line: self.line, column: self.col };
            }
            let h = self.hex_val(self.cur());
            if h < 0 {
                raise JsonError::Invalid { line: self.line, column: self.col };
            }
            n = n * 16 + h;
            self.bump();
            k = k + 1;
        }
        return n;
    }

    fn parse_escape(Vec<byte> out) -> Result<(), JsonError> {
        let line = self.line;
        let col = self.col;
        if self.at_end() {
            raise JsonError::Invalid { line: line, column: col };
        }
        let c = self.cur();
        self.bump();
        if c == "\"" {
            out.push("\"" as byte);
            return ();
        }
        if c == "\\" {
            out.push("\\" as byte);
            return ();
        }
        if c == "/" {
            out.push("/" as byte);
            return ();
        }
        if c == "b" {
            out.push(8 as byte);
            return ();
        }
        if c == "f" {
            out.push(12 as byte);
            return ();
        }
        if c == "n" {
            out.push(10 as byte);
            return ();
        }
        if c == "r" {
            out.push(13 as byte);
            return ();
        }
        if c == "t" {
            out.push(9 as byte);
            return ();
        }
        if c != "u" {
            raise JsonError::Invalid { line: line, column: col };
        }
        let cp = self.parse_hex4()?;
        if cp >= 55296 && cp <= 56319 {
            if self.at_end() || self.cur() != "\\" {
                raise JsonError::Utf8 { line: self.line, column: self.col };
            }
            self.bump();
            if self.at_end() || self.cur() != "u" {
                raise JsonError::Utf8 { line: self.line, column: self.col };
            }
            self.bump();
            let low = self.parse_hex4()?;
            if low < 56320 || low > 57343 {
                raise JsonError::Utf8 { line: self.line, column: self.col };
            }
            let n65536: int = 65536;
            let n1024: int = 1024;
            cp = n65536 + ((cp - 55296) * n1024) + (low - 56320);
        } else {
            if cp >= 56320 && cp <= 57343 {
                raise JsonError::Utf8 { line: line, column: col };
            }
        }
        return self.push_cp(out, cp)?;
    }

    fn parse_string() -> Result<string, JsonError> {
        if self.at_end() || self.cur() != "\"" {
            raise JsonError::Invalid { line: self.line, column: self.col };
        }
        self.bump();
        let out: Vec<byte> = Vec::new();
        while true {
            if self.at_end() {
                raise JsonError::Invalid { line: self.line, column: self.col };
            }
            let c = self.cur();
            if c == "\"" {
                self.bump();
                break;
            }
            if c == "\\" {
                self.bump();
                self.parse_escape(out)?;
                continue;
            }
            if c < " " {
                raise JsonError::Invalid { line: self.line, column: self.col };
            }
            out.push(c);
            self.bump();
        }
        return match from_bytes(out) {
            Result::Ok(s) => s,
            Result::Err(_) => raise JsonError::Utf8 { line: self.line, column: self.col },
        };
    }

    fn parse_float_slice(int start, int end, int line, int column) -> Result<float, JsonError> {
        let ten: float = 10.0;
        let i = start;
        let sign = 1.0;
        if i < end {
            if self.bytes[i] == "-" {
                sign = 0.0 - 1.0;
                i = i + 1;
            }
        }
        if i >= end {
            raise JsonError::Number { line: line, column: column };
        }
        let value = 0.0;
        let saw_digit = false;
        while i < end {
            let c = self.bytes[i];
            if c < "0" || c > "9" {
                break;
            }
            let d: int = (c as int) - ("0" as byte as int);
            value = value * ten + (d as float);
            saw_digit = true;
            i = i + 1;
        }
        let frac_places = 0;
        if i < end {
            if self.bytes[i] == "." {
                i = i + 1;
                while i < end {
                    let c = self.bytes[i];
                    if c < "0" || c > "9" {
                        break;
                    }
                    let d: int = (c as int) - ("0" as byte as int);
                    value = value * ten + (d as float);
                    frac_places = frac_places + 1;
                    saw_digit = true;
                    i = i + 1;
                }
            }
        }
        if !saw_digit {
            raise JsonError::Number { line: line, column: column };
        }
        let pfrac = 0;
        while pfrac < frac_places {
            value = value / ten;
            pfrac = pfrac + 1;
        }
        let exponent = 0;
        let divide_exp = false;
        if i < end {
            let c = self.bytes[i];
            if c == "e" || c == "E" {
                i = i + 1;
                if i < end {
                    if self.bytes[i] == "-" || self.bytes[i] == "+" {
                        divide_exp = self.bytes[i] == "-";
                        i = i + 1;
                    }
                }
                let exp_start = i;
                while i < end {
                    let d = self.bytes[i];
                    if d < "0" || d > "9" {
                        break;
                    }
                    exponent = exponent * 10 + ((d as int) - ("0" as byte as int));
                    i = i + 1;
                }
                if i == exp_start {
                    raise JsonError::Number { line: line, column: column };
                }
            }
        }
        if i != end {
            raise JsonError::Number { line: line, column: column };
        }
        let scaled = sign * value;
        let e = 0;
        while e < exponent {
            if divide_exp {
                scaled = scaled / ten;
            } else {
                scaled = scaled * ten;
            }
            e = e + 1;
        }
        if scaled != scaled {
            raise JsonError::Number { line: line, column: column };
        }
        if scaled != 0.0 {
            if scaled * 2.0 == scaled {
                raise JsonError::Number { line: line, column: column };
            }
        }
        return scaled;
    }

    fn parse_int_slice(int start, int end, int line, int column) -> Result<int, JsonError> {
        let ten: int = 10;
        let i = start;
        let negative = false;
        if i < end {
            if self.bytes[i] == "-" {
                negative = true;
                i = i + 1;
            }
        }
        if i >= end {
            raise JsonError::Number { line: line, column: column };
        }
        let value = 0;
        while i < end {
            let d: int = (self.bytes[i] as int) - ("0" as byte as int);
            let next = value * ten + d;
            if value > 0 {
                if next < value {
                    raise JsonError::Number { line: line, column: column };
                }
            }
            value = next;
            i = i + 1;
        }
        if negative {
            if value == 0 {
                return 0;
            }
            return 0 - value;
        }
        return value;
    }

    fn parse_number() -> Result<int, JsonError> {
        let line = self.line;
        let col = self.col;
        let start = self.i;
        if !self.at_end() {
            if self.cur() == "-" {
                self.bump();
            }
        }
        if self.at_end() || self.cur() < "0" || self.cur() > "9" {
            raise JsonError::Invalid { line: self.line, column: self.col };
        }
        if self.cur() == "0" {
            self.bump();
            if !self.at_end() && self.cur() >= "0" && self.cur() <= "9" {
                raise JsonError::Invalid { line: self.line, column: self.col };
            }
        } else {
            while !self.at_end() && self.cur() >= "0" && self.cur() <= "9" {
                self.bump();
            }
        }
        let is_float = false;
        if !self.at_end() && self.cur() == "." {
            is_float = true;
            self.bump();
            if self.at_end() || self.cur() < "0" || self.cur() > "9" {
                raise JsonError::Invalid { line: self.line, column: self.col };
            }
            while !self.at_end() && self.cur() >= "0" && self.cur() <= "9" {
                self.bump();
            }
        }
        if !self.at_end() {
            if self.cur() == "e" || self.cur() == "E" {
                is_float = true;
                self.bump();
                if !self.at_end() {
                    if self.cur() == "+" || self.cur() == "-" {
                        self.bump();
                    }
                }
                if self.at_end() || self.cur() < "0" || self.cur() > "9" {
                    raise JsonError::Invalid { line: self.line, column: self.col };
                }
                while !self.at_end() && self.cur() >= "0" && self.cur() <= "9" {
                    self.bump();
                }
            }
        }
        let end = self.i;
        if is_float {
            let f = self.parse_float_slice(start, end, line, col)?;
            return self.store.add(3, false, 0, f, "", "");
        }
        let n = self.parse_int_slice(start, end, line, col)?;
        return self.store.add(2, false, n, 0.0, "", "");
    }

    fn parse_literal(string lit, int tag, bool flag) -> Result<int, JsonError> {
        let b = to_bytes(lit);
        let k = 0;
        while k < len(b) {
            if self.at_end() || self.cur() != b[k] {
                raise JsonError::Invalid { line: self.line, column: self.col };
            }
            self.bump();
            k = k + 1;
        }
        return self.store.add(tag, flag, 0, 0.0, "", "");
    }

    #[max_depth(256)]
    fn parse_value() -> Result<int, JsonError> {
        self.skip_ws()?;
        if self.at_end() {
            raise JsonError::Invalid { line: self.line, column: self.col };
        }
        let c = self.cur();
        if c == "n" {
            return self.parse_literal("null", 0, false)?;
        }
        if c == "t" {
            return self.parse_literal("true", 1, true)?;
        }
        if c == "f" {
            return self.parse_literal("false", 1, false)?;
        }
        if c == "\"" {
            let s = self.parse_string()?;
            return self.store.add(4, false, 0, 0.0, s, "");
        }
        if c == "-" || (c >= "0" && c <= "9") {
            return self.parse_number()?;
        }
        if c == "[" {
            self.bump();
            self.skip_ws()?;
            let arr = self.store.add(5, false, 0, 0.0, "", "");
            if !self.at_end() && self.cur() == "]" {
                self.bump();
                return arr;
            }
            while true {
                let kid = self.parse_value()?;
                self.store.attach(arr, kid);
                self.skip_ws()?;
                if !self.at_end() && self.cur() == "," {
                    self.bump();
                    self.skip_ws()?;
                    if !self.at_end() && self.cur() == "]" {
                        if self.jsonc {
                            self.bump();
                            break;
                        }
                        raise JsonError::Invalid { line: self.line, column: self.col };
                    }
                    continue;
                }
                if !self.at_end() && self.cur() == "]" {
                    self.bump();
                    break;
                }
                raise JsonError::Invalid { line: self.line, column: self.col };
            }
            return arr;
        }
        if c == "{" {
            self.bump();
            self.skip_ws()?;
            let obj = self.store.add(6, false, 0, 0.0, "", "");
            if !self.at_end() && self.cur() == "}" {
                self.bump();
                return obj;
            }
            while true {
                self.skip_ws()?;
                if self.at_end() || self.cur() != "\"" {
                    raise JsonError::Invalid { line: self.line, column: self.col };
                }
                let key = self.parse_string()?;
                self.skip_ws()?;
                if self.at_end() || self.cur() != ":" {
                    raise JsonError::Invalid { line: self.line, column: self.col };
                }
                self.bump();
                let kid = self.parse_value()?;
                self.store.keys[kid] = key;
                self.store.attach(obj, kid);
                self.skip_ws()?;
                if !self.at_end() && self.cur() == "," {
                    self.bump();
                    self.skip_ws()?;
                    if !self.at_end() && self.cur() == "}" {
                        if self.jsonc {
                            self.bump();
                            break;
                        }
                        raise JsonError::Invalid { line: self.line, column: self.col };
                    }
                    continue;
                }
                if !self.at_end() && self.cur() == "}" {
                    self.bump();
                    break;
                }
                raise JsonError::Invalid { line: self.line, column: self.col };
            }
            return obj;
        }
        raise JsonError::Invalid { line: self.line, column: self.col };
    }
}

/// RFC 8259 codec. `Json::jsonc()` is parse-only sugar on the same parser.
class Json {
    mode: int,
}

impl Json {
    /// Strict RFC 8259 mode. Rejects comments and trailing commas.
    static fn strict() -> Json {
        return new Json(0);
    }

    /// JSONC decode: `//` / `/* */` comments and trailing commas. Encode is still RFC 8259.
    static fn jsonc() -> Json {
        return new Json(1);
    }

    fn encode(JsonValue value) -> Result<Vec<byte>, JsonError> {
        let out: Vec<byte> = Vec::new();
        value.emit(out)?;
        return out;
    }

    fn decode(Vec<byte> bytes) -> Result<JsonValue, JsonError> {
        let jsonc = self.mode == 1;
        let p = new Parser(bytes, 0, 1, 1, Store::new(), jsonc);
        let root = p.parse_value()?;
        p.skip_ws()?;
        if !p.at_end() {
            raise JsonError::Invalid { line: p.line, column: p.col };
        }
        return JsonValue::wrap(p.store, root);
    }

    pub fn encode_str(JsonValue value) -> Result<string, JsonError> {
        let bytes = self.encode(value)?;
        return match from_bytes(bytes) {
            Result::Ok(s) => s,
            Result::Err(_) => raise JsonError::Utf8 { line: 1, column: 1 },
        };
    }

    pub fn decode_str(string s) -> Result<JsonValue, JsonError> {
        return self.decode(to_bytes(s))?;
    }
}
