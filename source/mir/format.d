module mir.format;


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
            w.advance(printFloatingPoint(value, w.getBuffer(512).getStaticBuf!512), spec);
        }
        else
        {
            C[512] buf = void;
            auto n = printFloatingPoint(value, buf, spec);
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
ref W print(C = char, W)(scope return ref W w, bool b)
{
    enum N = 5;
    static if(isFastBuffer!W)
    {
        w.advance(printBoolean(value, w.getBuffer(N).getStaticBuf!N));
    }
    else
    {
        C[N] buf = void;
        auto n = printBoolean(value, buf);
        w.put(buf[0 .. n]);
    }
}

///
pragma(inline, false)
ref W print(C, W, V, K)(scope return ref W w, scope const V[K] c)
    if (!isSomeChar!T)
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
        {
            print!(C, sep)(w);
            first = false;
        }
        print!C(w, key);
        print!C(w, value);
    }
    w.put(right);
}

///
pragma(inline, false)
ref W print(C, W, T)(scope return ref W w, scope const(T)[] c)
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
        {
            print!(C, sep)(w);
            first = false;
        }
        print!C(w, e);
    }
    w.put(right);
}

///
ref W print(C = char, W)(scope return ref W w, char c)
{
    w.put('\'');
    switch(c)
    {
        case '\n': c = 'n'; goto case '\\';
        case '\r': c = 'r'; goto case '\\';
        case '\t': c = 't'; goto case '\\';
        case '\a': c = 'a'; goto case '\\';
        case '\b': c = 'b'; goto case '\\';
        case '\f': c = 'f'; goto case '\\';
        case '\v': c = 'v'; goto case '\\';
        case '\0': c = '0'; goto case '\\';
        case '\'': c = '\''; goto case '\\';
        case '\\': w.put('\\'); goto default;
        default:
            if ('!' <= c && c <= '~')
            {
                w.put(c);
            }
            else
            {
                print!(C, "\\x")(w);
                print!C(w, HexAddress!ubyte(cast(ubyte)c));
            }
    }
    if ('!' <= c && c <= '~')
    {
        w.put(c);
    }
    w.put('\'');
}

///
ref W print(C, W)(scope return ref W w, scope const(C)[] c)
{
    w.put(c);
}

///
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
}

///
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
}

///
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
}

///
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
}

static if (is(ucent))
///
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
}

static if (is(cent))
///
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
}

///
ref W print(C = char, W, T)(scope return ref W w, const T c)
    if(is(T == float) || is(T == double) || is(T == real))
{
    auto ff = FormattedFloating!T(c);
    return print!C(w, ff);
}

///
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
    return print(C, W, T)(w, c);
}

///
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

///
ref W print(C, C[] c, W, T, size_t N)(scope return ref W w)
    if (C.sizeof * c.length <= 512)
{
    static if (isFastBuffer!W)
    {
        printStaticString!str(w.getBuffer(c.length).getStaticBuf!(c.length));
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
        w.put(str[]);
    }
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

@safe pure @nogc:

/// Print Kernel
size_t printFloatingPoint(float c, scope ref const FormatSpec spec, scope ref char[512] buf);
/// ditto
size_t printFloatingPoint(double c, scope ref const FormatSpec spec, scope ref char[512] buf);
/// ditto
size_t printFloatingPoint(real c, scope ref const FormatSpec spec, scope ref char[512] buf);

/// ditto
size_t printFloatingPoint(float c, scope ref const FormatSpec spec, scope ref wchar[512] buf);
/// ditto
size_t printFloatingPoint(double c, scope ref const FormatSpec spec, scope ref wchar[512] buf);
/// ditto
size_t printFloatingPoint(real c, scope ref const FormatSpec spec, scope ref wchar[512] buf);

/// ditto
size_t printFloatingPoint(float c, scope ref const FormatSpec spec, scope ref dchar[512] buf);
/// ditto
size_t printFloatingPoint(double c, scope ref const FormatSpec spec, scope ref dchar[512] buf);
/// ditto
size_t printFloatingPoint(real c, scope ref const FormatSpec spec, scope ref dchar[512] buf);

nothrow:

/// ditto
size_t printUnsigned(uint c, scope ref char[10] buf);
/// ditto
size_t printUnsigned(ulong c, scope ref char[20] buf);
static if (is(ucent))
/// ditto
size_t printUnsigned(ucent c, scope ref char[39] buf);

/// ditto
size_t printUnsigned(uint c, scope ref wchar[10] buf);
/// ditto
size_t printUnsigned(ulong c, scope ref wchar[20] buf);
static if (is(ucent))
/// ditto
size_t printUnsigned(ucent c, scope ref wchar[39] buf);

/// ditto
size_t printUnsigned(uint c, scope ref dchar[10] buf);
/// ditto
size_t printUnsigned(ulong c, scope ref dchar[20] buf);
static if (is(ucent))
/// ditto
size_t printUnsigned(ucent c, scope ref dchar[39] buf);

/// ditto
size_t printSigned(uint c, scope ref char[10 + 1] buf, char sign = '\0');
/// ditto
size_t printSigned(ulong c, scope ref char[20 + 1] buf, char sign = '\0');
static if (is(cent))
/// ditto
size_t printSigned(cent c, scope ref char[39 + 1] buf, char sign = '\0');

/// ditto
size_t printSigned(uint c, scope ref wchar[10 + 1] buf, wchar sign = '\0');
/// ditto
size_t printSigned(ulong c, scope ref wchar[20 + 1] buf, wchar sign = '\0');
static if (is(cent))
/// ditto
size_t printSigned(cent c, scope ref wchar[39 + 1] buf, wchar sign = '\0');

/// ditto
size_t printSigned(uint c, scope ref dchar[10 + 1] buf, dchar sign = '\0');
/// ditto
size_t printSigned(ulong c, scope ref dchar[20 + 1] buf, dchar sign = '\0');
static if (is(cent))
/// ditto
size_t printSigned(cent c, scope ref dchar[39 + 1] buf, dchar sign = '\0');

/// ditto
size_t printHexadecimal(uint c, ref char[8] buf, bool upper = true);
/// ditto
size_t printHexadecimal(ulong c, ref char[16] buf, bool upper = true);
static if (is(ucent))
/// ditto
size_t printHexadecimal(ucent c, ref char[32] buf, bool upper = true);

/// ditto
size_t printHexadecimal(uint c, ref wchar[8] buf, bool upper = true);
/// ditto
size_t printHexadecimal(ulong c, ref wchar[16] buf, bool upper = true);
static if (is(ucent))
/// ditto
size_t printHexadecimal(ucent c, ref wchar[32] buf, bool upper = true);

/// ditto
size_t printHexadecimal(uint c, ref dchar[8] buf, bool upper = true);
/// ditto
size_t printHexadecimal(ulong c, ref dchar[16] buf, bool upper = true);
static if (is(ucent))
/// ditto
size_t printHexadecimal(ucent c, ref dchar[32] buf, bool upper = true);

/// ditto
size_t printHexAddress(ubyte c, ref char[2] buf, bool upper = true);
/// ditto
size_t printHexAddress(ushort c, ref char[4] buf, bool upper = true);
/// ditto
size_t printHexAddress(uint c, ref char[8] buf, bool upper = true);
/// ditto
size_t printHexAddress(ulong c, ref char[16] buf, bool upper = true);
static if (is(ucent))
/// ditto
size_t printHexAddress(ucent c, ref char[32] buf, bool upper = true);

/// ditto
size_t printHexAddress(ubyte c, ref wchar[2] buf, bool upper = true);
/// ditto
size_t printHexAddress(ushort c, ref wchar[4] buf, bool upper = true);
/// ditto
size_t printHexAddress(uint c, ref wchar[8] buf, bool upper = true);
/// ditto
size_t printHexAddress(ulong c, ref wchar[16] buf, bool upper = true);
static if (is(ucent))
/// ditto
size_t printHexAddress(ucent c, ref wchar[32] buf, bool upper = true);

/// ditto
size_t printHexAddress(ubyte c, ref dchar[2] buf, bool upper = true);
/// ditto
size_t printHexAddress(ushort c, ref dchar[4] buf, bool upper = true);
/// ditto
size_t printHexAddress(uint c, ref dchar[8] buf, bool upper = true);
/// ditto
size_t printHexAddress(ulong c, ref dchar[16] buf, bool upper = true);
static if (is(ucent))
/// ditto
size_t printHexAddress(ucent c, ref dchar[32] buf, bool upper = true);

/// ditto
size_t printBoolean(C)(bool c, ref C[5] buf)
    if(is(C == char) || is(C == wchar) || is(C == dchar))
{
    version(LDC) pragma(inline, true);
    if (c)
    {
        buf[0] = 'f';
        buf[1] = 'a';
        buf[2] = 'l';
        buf[3] = 's';
        buf[4] = 'e';
        return 5;
    }
    else
    {
        buf[0] = 't';
        buf[1] = 'r';
        buf[2] = 'u';
        buf[3] = 'e';
        return 4;
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
