/++
+/
module mir.format;

import std.traits;

import mir.format_impl;

@safe:

///
struct GetData {}

///
enum getData = GetData();

/++
+/
struct _stringBuf(C)
{
    import mir.appender: ScopedBuffer;

    ///
    ScopedBuffer!C buffer;

    ///
    alias buffer this;

    ///
    mixin StreamFormatOp!C;
}

///ditto
alias stringBuf = _stringBuf!char;
///ditto
alias wstringBuf = _stringBuf!wchar;
///ditto
alias dstringBuf = _stringBuf!dchar;

/++
+/
mixin template StreamFormatOp(C)
{
    ///
    ref typeof(this) opBinary(string op : "<<", T)(scope auto ref const T c) scope @safe
    {
        return print!C(this, c);
    }

    /// ditto
    const(C)[] opBinary(string op : "<<", T : GetData)(const T c) scope
    {
        return buffer.data;
    }
}

///
@safe pure nothrow @nogc
unittest
{
    auto name = "D";
    auto ver = 2;
    auto str = stringBuf() << "Hi " << name << ver << "!\n" << getData;
    assert(str == "Hi D2!\n");
}

///
@safe pure nothrow @nogc
unittest
{
    auto name = "D"w;
    auto ver = 2;
    auto str = wstringBuf() << "Hi "w << name << ver << "!\n"w << getData;
    assert(str == "Hi D2!\n"w);
}

///
@safe pure nothrow @nogc
unittest
{
    auto name = "D"d;
    auto ver = 2;
    auto str = dstringBuf() << "Hi "d  << name << ver << "!\n"d << getData;
    assert(str == "Hi D2!\n");
}

@safe pure nothrow @nogc
unittest
{
    auto str = stringBuf() << -1234567890 << getData;
    assert(str == "-1234567890", str);
}

// 16-bytes
/// C's compatible format specifier.
struct FormatSpec
{
    ///
    bool dash;
    ///
    bool plus;
    ///
    bool space;
    ///
    bool hash;
    ///
    bool zero;
    ///
    char format = 's';
    ///
    char separator = '\0';
    ///
    ubyte unitSize;
    ///
    int width;
    ///
    int precision = -1;
}

/++
+/
enum SwitchLU : bool
{
    ///
    lower,
    ///
    upper,
}

/++
+/
struct FormattedFloating(T)
    if(is(T == float) || is(T == double) || is(T == real))
{
    ///
    T value;
    ///
    FormatSpec spec;

    ///
    void toString(C = char, W)(scope ref W w) scope const
    {
        static if (isFastBuffer!W)
        {
            w.advance(printFloatingPoint(value, spec, w.getBuffer(512).getStaticBuf!512));
        }
        else
        {
            C[512] buf = void;
            auto n = printFloatingPoint(value, spec, buf);
            w.put(buf[0 ..  n]);
        }
    }
}

/// ditto
FormattedFloating!T withFormat(T)(const T value, FormatSpec spec)
{
    version(LDC) pragma(inline);
    return typeof(return)(value, spec);
}

/++
+/
struct HexAddress(T)
    if (isUnsigned!T && !is(T == enum))
{
    ///
    T value;
    ///
    SwitchLU switchLU = SwitchLU.upper;

    ///
    void toString(C = char, W)(scope ref W w) scope const
    {
        enum N = T.sizeof * 2;
        static if(isFastBuffer!W)
        {
            w.advance(printHexAddress(value, w.getBuffer(N).getStaticBuf!N, cast(bool) switchLU));
        }
        else
        {
            C[N] buf = void;
            printHexAddress(value, buf, cast(bool) switchLU);
            w.put(buf[]);
        }
    }
}

/++
Note: Non-ASCII Unicode characters are encoded as sequence of \xXX bytes. This may be fixed in the future.
+/
pragma(inline, false)
ref W printEscaped(C = char, W)(scope return ref W w, scope const(char)[] str)
{
    // TODO: replace with Mir implementation.
    import std.uni: isGraphical;
    w.put('\"');
    foreach (char c; str[])
    {
        if (c >= 0x20)
        {
            if (c < 0x7F)
            {
                if (c == '\"' || c == '\\')
                {
                L:
                    w.put('\\');
                }
                w.put(c);
            }
            else
            {
            M:
                printStaticStringInternal!(C, "\\x")(w);
                print!C(w, HexAddress!ubyte(cast(ubyte)c));
            }
        }
        else
        {
            switch(c)
            {
                case '\n': c = 'n'; goto L;
                case '\r': c = 'r'; goto L;
                case '\t': c = 't'; goto L;
                case '\a': c = 'a'; goto L;
                case '\b': c = 'b'; goto L;
                case '\f': c = 'f'; goto L;
                case '\v': c = 'v'; goto L;
                case '\0': c = '0'; goto L;
                default: goto M;
            }
        }
    }
    w.put('\"');
    return w;
}

///
// @safe pure nothrow @nogc
unittest
{
    import mir.appender: ScopedBuffer;
    ScopedBuffer!char w;
    assert(w.printEscaped("Hi\t" ~ `"@nogc"`).data == `"Hi\t\"@nogc\""`, w.data.idup);
    w.reset;
    assert(w.printEscaped("\xF3").data == `"\xF3"`, w.data);
}

///
ref W printElement(C = char, W, T)(scope return ref W w, scope auto ref const T c)
{
    static if (isSomeString!T)
    {
        return printEscaped!C(w, c);
    }
    else
    {
        return print!C(w, c);
    }
}

///
ref W print(C = char, W, T)(scope return ref W w, const T c)
    if (is(T == enum))
{
    static assert(!is(OriginalType!T == enum));
    string c = void;
    switch (c)
    {
        static foreach(member; __traits(allMembers, T))
        {
            case __traits(getMember, T, member):
            c = member;
            break;
        }
        default:
            w.put(c);
            static immutable C[] str = T.stringof;
            w.put(str[]);
            w.put('(');
            print!(w, cast(OriginalType!T) c);
            w.put(')');
            return w;
    }
    w.put(c);
    return w;
}

///
@safe pure nothrow @nogc
unittest
{
    import mir.appender: ScopedBuffer;
    ScopedBuffer!char w;
}

/// ditto
ref W print(C = char, W)(scope return ref W w, bool c)
{
    enum N = 5;
    static if(isFastBuffer!W)
    {
        w.advance(printBoolean(c, w.getBuffer(N).getStaticBuf!N));
    }
    else
    {
        C[N] buf = void;
        auto n = printBoolean(c, buf);
        w.put(buf[0 .. n]);
    }
    return w;
}

///
@safe pure nothrow @nogc
unittest
{
    import mir.appender: ScopedBuffer;
    ScopedBuffer!char w;
    assert(w.print(true).data == `true`, w.data);
    w.reset;
    assert(w.print(false).data == `false`, w.data);
}

/// ditto
pragma(inline, false)
ref W print(C = char, W, V, K)(scope return ref W w, scope const V[K] c)
{
    enum C left = '[';
    enum C right = ']';
    enum C[2] sep = ", ";
    enum C[2] mid = ": ";
    w.put(left);
    bool first = true;
    foreach (ref key, ref value; c)
    {
        if (!first)
            printStaticStringInternal!(C, sep)(w);
        first = false;
        printElement!C(w, key);
        printStaticStringInternal!(C, mid)(w);
        printElement!C(w, value);
    }
    w.put(right);
    return w;
}

///
@safe pure
unittest
{
    import mir.appender: ScopedBuffer;
    ScopedBuffer!char w;
    w.print(["a": 1, "b": 2]);
    assert(w.data == `["a": 1, "b": 2]` || w.data == `["b": 2, "a": 1]`, w.data);
}

/// ditto
pragma(inline, false)
ref W print(C = char, W, T)(scope return ref W w, scope const(T)[] c)
    if (!isSomeChar!T)
{
    enum C left = '[';
    enum C right = ']';
    enum C[2] sep = ", ";
    w.put(left);
    bool first = true;
    foreach (ref e; c)
    {
        if (!first)
            printStaticStringInternal!(C, sep)(w);
        first = false;
        printElement!C(w, e);
    }
    w.put(right);
    return w;
}

///
@safe pure nothrow @nogc
unittest
{
    import mir.appender: ScopedBuffer;
    ScopedBuffer!char w;
    string[2] array = ["a\ta", "b"];
    assert(w.print(array[]).data == `["a\ta", "b"]`, w.data);
}

/// ditto
pragma(inline, false)
ref W print(C = char, W)(scope return ref W w, char c)
{
    w.put('\'');
    if (c >= 0x20)
    {
        if (c < 0x7F)
        {
            if (c == '\'' || c == '\\')
            {
            L:
                w.put('\\');
            }
            w.put(c);
        }
        else
        {
        M:
            printStaticStringInternal!(C, "\\x")(w);
            print!C(w, HexAddress!ubyte(cast(ubyte)c));
        }
    }
    else
    {
        switch(c)
        {
            case '\n': c = 'n'; goto L;
            case '\r': c = 'r'; goto L;
            case '\t': c = 't'; goto L;
            case '\a': c = 'a'; goto L;
            case '\b': c = 'b'; goto L;
            case '\f': c = 'f'; goto L;
            case '\v': c = 'v'; goto L;
            case '\0': c = '0'; goto L;
            default: goto M;
        }
    }
    w.put('\'');
    return w;
}

///
@safe pure nothrow @nogc
unittest
{
    import mir.appender: ScopedBuffer;
    ScopedBuffer!char w;
    assert(w
        .print('\n')
        .print('\'')
        .print('a')
        .print('\xF4')
        .data == `'\n''\'''a''\xF4'`);
}

/// ditto
ref W print(C = char, W)(scope return ref W w, scope const(C)[] c)
    if (isSomeChar!C)
{
    w.put(c);
    return w;
}

/// ditto
ref W print(C = char, W)(scope return ref W w, uint c)
{
    enum N = 10;
    static if (isFastBuffer!W)
    {
        w.advance(printUnsigned(c, w.getBuffer(N).getStaticBuf!N));
    }
    else
    {
        C[N] buf = void;
        auto n = printUnsigned(c, buf);
        w.put(buf[0 ..  n]);
    }
    return w;
}

/// ditto
ref W print(C = char, W)(scope return ref W w, int c)
{
    enum N = 11;
    static if (isFastBuffer!W)
    {
        w.advance(printSigned(c, w.getBuffer(N).getStaticBuf!N));
    }
    else
    {
        C[N] buf = void;
        auto n = printSigned(c, buf);
        w.put(buf[0 ..  n]);
    }
    return w;
}

/// ditto
ref W print(C = char, W)(scope return ref W w, ulong c)
{
    enum N = 20;
    static if (isFastBuffer!W)
    {
        w.advance(printUnsigned(c, w.getBuffer(N).getStaticBuf!N));
    }
    else
    {
        C[N] buf = void;
        auto n = printUnsigned(c, buf);
        w.put(buf[0 ..  n]);
    }
    return w;
}

/// ditto
ref W print(C = char, W)(scope return ref W w, long c)
{
    enum N = 21;
    static if (isFastBuffer!W)
    {
        w.advance(printSigned(c, w.getBuffer(N).getStaticBuf!N));
    }
    else
    {
        C[N] buf = void;
        auto n = printSigned(c, buf);
        w.put(buf[0 ..  n]);
    }
    return w;
}

static if (is(ucent))
/// ditto
ref W print(C = char, W)(scope return ref W w, ucent c)
{
    enum N = 39;
    static if (isFastBuffer!W)
    {
        w.advance(printUnsigned(c, w.getBuffer(N).getStaticBuf!N));
    }
    else
    {
        C[N] buf = void;
        auto n = printUnsigned(c, buf);
        w.put(buf[0 ..  n]);
    }
    return w;
}

static if (is(cent))
/// ditto
ref W print(C = char, W)(scope return ref W w, cent c)
{
    enum N = 40;
    static if (isFastBuffer!W)
    {
        w.advance(printSigned(c, w.getBuffer(N).getStaticBuf!N));
    }
    else
    {
        C[N] buf = void;
        auto n = printSigned(c, buf);
        w.put(buf[0 ..  n]);
    }
    return w;
}

/// ditto
ref W print(C = char, W, T)(scope return ref W w, const T c)
    if(is(T == float) || is(T == double) || is(T == real))
{
    auto ff = FormattedFloating!T(c);
    return print!C(w, ff);
}

/// ditto
pragma(inline, false)
ref W print(C = char, W, T)(scope return ref W w, scope ref const T c)
    if (is(T == struct) || is(T == union))
{
    static if (__traits(hasMember, T, "toString"))
    {
        static if (is(typeof(c.toString!C(w))))
            c.toString!C(w);
        else
        static if (is(typeof(c.toString(w))))
            c.toString(w);
        else
        static if (is(typeof(c.toString((scope const(C)[] s) { w.put(s); }))))
            c.toString((scope const(C)[] s) { w.put(s); });
        else
        static if (is(typeof(w.put(c.toString))))
            w.put(c.toString);
        else static assert(0, "const " ~ T.stringof ~ ".toString definition is wrong");
    }
    else
    static if (hasIterableLightConst!T)
    {
        enum C left = '[';
        enum C right = ']';
        enum C[2] sep = ", ";
        w.put(left);
        bool first = true;
        foreach (ref e; c.lightConst)
        {
            if (!first)
            {
                print!(C, sep)(w);
                first = false;
            }
            print!C(w, e);
        }
        w.put(right);
    }
    else
    {
        enum C left = '(';
        enum C right = ')';
        enum C[2] sep = ", ";
        w.put(left);
        foreach (i, ref e; c.tupleof)
        {
            static if (i)
                print!(C, sep)(w);
            print!C(w, e);
        }
        w.put(right);
    }
    return w;
}

///
// FUTURE: remove it
pragma(inline, false)
ref W print(C = char, W, T)(scope return ref W w, scope const T c)
    if (is(T == struct) || is(T == union))
{
    return print!(C, W, T)(w, c);
}

/// ditto
pragma(inline, false)
ref W print(C = char, W, T)(scope return ref W w, scope const T c)
    if (is(T == class) || is(T == interface))
{
    static if (__traits(hasMember, T, "toString"))
    {
        if (c is null)
            w.print!(C, "null");
        else
        static if (is(typeof(c.toString!C(w))))
            c.toString!C(w);
        else
        static if (is(typeof(c.toString(w))))
            c.toString(w);
        else
        static if (is(typeof(c.toString((scope const(C)[] s) { w.put(s); }))))
            c.toString((scope const(C)[] s) { w.put(s); });
        else
        static if (is(typeof(w.put(c.toString))))
            w.put(c.toString);
        else static assert(0, "const " ~ T.stringof ~ ".toString definition is wrong");
    }
    else
    static if (hasIterableLightConst!T)
    {
        enum C left = '[';
        enum C right = ']';
        enum C[2] sep = ", ";
        w.put(left);
        bool first = true;
        foreach (ref e; c.lightConst)
        {
            if (!first)
            {
                print!(C, sep)(w);
                first = false;
            }
            print!C(w, e);
        }
        w.put(right);
    }
    else
    {
        w.put(T.stringof);
    }
    return w;
}

private template hasIterableLightConst(T)
{
    static if (__traits(hasMember, T, "lightConst"))
    {
        enum hasIterableLightConst = isIterable!(ReturnType!((const T t) => t.leghtConst));
    }
    else
    {
        enum hasIterableLightConst = false;
    }
}

private ref W printStaticStringInternal(C, immutable(C)[] c, W)(scope return ref W w)
    if (C.sizeof * c.length <= 512)
{
    static if (isFastBuffer!W)
    {
        printStaticString!c(w.getBuffer(c.length).getStaticBuf!(c.length));
        w.advance(c.length);
    }
    else
    static if (c.length <= 4)
    {
        static foreach(i; 0 .. c.length)
            w.put(c[i]);
    }
    else
    {
        w.put(c[]);
    }
    return w;
}

private @trusted ref C[N] getStaticBuf(size_t N, C)(scope return ref C[] buf)
{
    assert(buf.length >= N);
    return buf.ptr[0 .. N];
}

template isFastBuffer(W)
{
    enum isFastBuffer = __traits(hasMember, W, "getBuffer") && __traits(hasMember, W, "advance");
}

/// ditto
size_t printBoolean(C)(bool c, ref C[5] buf)
    if(is(C == char) || is(C == wchar) || is(C == dchar))
{
    version(LDC) pragma(inline, true);
    if (c)
    {
        buf[0] = 't';
        buf[1] = 'r';
        buf[2] = 'u';
        buf[3] = 'e';
        return 4;
    }
    else
    {
        buf[0] = 'f';
        buf[1] = 'a';
        buf[2] = 'l';
        buf[3] = 's';
        buf[4] = 'e';
        return 5;
    }
}

/// ditto
size_t printStaticString(string str, C)(scope ref C[str.length] buf)
    if((is(C == char) || is(C == wchar) || is(C == dchar)) && (C[str.length]).sizeof <= 512)
{
    version(LDC) pragma(inline, true);
    static foreach (i, e; str) buf[i] = e;
    return buf.length;
}

/// ditto
size_t printStaticString(wstring str, C)(scope ref C[str.length] buf)
    if((is(C == wchar) || is(C == dchar)) && (C[str.length]).sizeof <= 512)
{
    version(LDC) pragma(inline, true);
    static foreach (i, e; str) buf[i] = e;
    return buf.length;
}

/// ditto
size_t printStaticString(dstring str)(scope ref dchar[str.length] buf)
    if((dchar[str.length]).sizeof <= 512)
{
    version(LDC) pragma(inline, true);
    static foreach (i, e; str) buf[i] = e;
    return buf.length;
}
