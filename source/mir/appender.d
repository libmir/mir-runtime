module mir.appender;

// import std.traits: isAssignable, hasElaborateDestructorhasElaborateCopyConstructor, hasElaborateAssign;

package void _mir_destroy(T)(T[] ar)
{
    static if (__traits(hasMember, T, "__xdtor"))
        foreach (ref e; ar)
            static if (__traits(isSame, T, __traits(parent, e.__xdtor)))
            {
                pragma(inline, false)
                e.__xdtor();
            }
}

private extern(C) @system nothrow @nogc pure void* memcpy(scope void* s1, scope const void* s2, size_t n);


///
struct ScopedBuffer(T, size_t bytes = 4096)
    if (bytes)
{
    import std.traits: isIterable, hasElaborateAssign, isAssignable, isArray;
    import mir.primitives: hasLength;
    import mir.conv: emplaceRef;

    private enum size_t _bufferLength =  bytes / T.sizeof + (bytes % T.sizeof != 0);
    private T[] _buffer;
    private size_t _currentLength;
    private align(T.alignof) ubyte[_bufferLength * T.sizeof] _scopeBufferPayload = void;

    private ref T[_bufferLength] _scopeBuffer() @trusted scope
    {
        return *cast(T[_bufferLength]*)&_scopeBufferPayload;
    }

    private T[] prepare(size_t n) @trusted scope
    {
        import mir.internal.memory: realloc, malloc;
        _currentLength += n;
        if (_buffer.length == 0)
        {
            if (_currentLength <= _bufferLength)
            {
                return _scopeBuffer[0 .. _currentLength];
            }
            else
            {
                auto newLen = _currentLength << 1;
                _buffer = (cast(T*)malloc(T.sizeof * newLen))[0 .. newLen];
                memcpy(_buffer.ptr, _scopeBuffer.ptr, T.sizeof * (_currentLength - n));
            }
        }
        else
        if (_currentLength > _buffer.length)
        {
            auto newLen = _currentLength << 1;
            _buffer = (cast(T*)realloc(_buffer.ptr, T.sizeof * newLen))[0 .. newLen];
        }
        return _buffer[0 .. _currentLength];
    }

    static if (isAssignable!(T, const T))
        private alias R = const T;
    else
        private alias R = T;

    @disable this(this);

    ~this()
    {
        import mir.internal.memory: free;
        data._mir_destroy;
        (() @trusted => free(_buffer.ptr))();
    }

    void popBackN(size_t n)
    {
        sizediff_t t = _currentLength - n;
        if (t < 0)
            assert(0, "ScopedBffer.popBackN: n is too large.");
            import mir.exception;
        data[t .. _currentLength]._mir_destroy;
        _currentLength = t;
    }

    void put(R e) @safe scope
    {
        auto cl = _currentLength;
        prepare(1);
        emplaceRef(data[cl], e);
    }

    static if (T.sizeof > 8 || hasElaborateAssign!T)
    void put(ref R e) scope
    {
        auto cl = _currentLength;
        auto d = prepare(1);
        emplaceRef(d[cl], e);
    }

    static if (!hasElaborateAssign!T && isAssignable!(T, const T))
    void put(scope const(T)[] e) scope
    {
        auto cl = _currentLength;
        auto d = prepare(e.length);
        auto len = e.length * T.sizeof;
        if (!__ctfe)
            (()@trusted=>memcpy(d.ptr + cl, e.ptr, len))();
        else
            (()@trusted { (d.ptr + cl)[0 .. len] = e[0 .. len]; })();
    }

    static if (!hasElaborateAssign!T && !isAssignable!(T, const T))
    void put()(scope T[] e) scope
    {
        auto cl = _currentLength;
        auto d = prepare(e.length);
        auto len = e.length * T.sizeof;
        if (!__ctfe)
            (()@trusted=>memcpy(d.ptr + cl, e.ptr, len))();
        else
            (()@trusted { (d.ptr + cl)[0 .. len] = e[0 .. len]; })();
    }

    void put(Iterable)(Iterable range) scope
        if (isIterable!Iterable && !isArray!Iterable)
    {
        static if (hasLength!Iterable)
        {
            auto cl = _currentLength;
            auto d = prepare(range.length);
            static if (is(Iterable : R[]) && !hasElaborateAssign!T)
            {
                auto len = range.length * T.sizeof;
                if (!__ctfe)
                    (()@trusted=>memcpy(d.ptr + cl, e.ptr, len))();
                else
                    (()@trusted { (d.ptr + cl)[0 .. len] = e[0 .. len]; })();
            }
            else
            {
                foreach(ref e; range)
                    emplaceRef(d[cl++], e);
                assert(_currentLength == cl);
            }
        }
        else
        {
            foreach(ref e; range)
                put(e);
        }
    }

    void reset() scope nothrow
    {
        this.__dtor;
        _currentLength = 0;
        _buffer = null;
    }

    T[] data() @property @safe scope
    {
        return _buffer.length ? _buffer[0 .. _currentLength] : _scopeBuffer[0 .. _currentLength];
    }
}

///
@safe pure nothrow @nogc 
unittest
{
    ScopedBuffer!char buf;
    buf.put('c');
    buf.put("str");
    assert(buf.data == "cstr");

    buf.popBackN(2);
    assert(buf.data == "cs");
}

@safe pure nothrow @nogc 
unittest
{
    ScopedBuffer!(char, 3) buf;
    buf.put('c');
    buf.put("str");
    assert(buf.data == "cstr");

    buf.popBackN(2);
    assert(buf.data == "cs");
}
