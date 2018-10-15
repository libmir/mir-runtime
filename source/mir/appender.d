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
    import std.traits: isIterable, hasElaborateAssign, isAssignable;
    import mir.primitives: hasLength;
    import std.backdoor: emplaceRef;

    private enum size_t _bufferLength =  bytes / T.sizeof + (bytes % T.sizeof != 0);
    private T[] _buffer;
    private size_t _currentLength;
    private align(T.alignof) ubyte[_bufferLength * T.sizeof] _scopeBufferPayload = void;

    private ref scope T[_bufferLength] _scopeBuffer() @trusted
    {
        return *cast(T[_bufferLength]*)&_scopeBufferPayload;
    }

    private scope T[] prepare(size_t n) @trusted
    {
        import mir.internal.memory: realloc;
        _currentLength += n;
        if (_currentLength <= _bufferLength)
        {
            return _scopeBuffer[0 .. _currentLength];
        }
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
        _buffer._mir_destroy;
        if (_buffer.ptr is _scopeBuffer.ptr)
            (() @trusted => free(_buffer.ptr))();
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

    void put(Iterable)(Iterable range) scope
        if (isIterable!Iterable)
    {
        static if (hasLength!Iterable)
        {
            auto cl = _currentLength;
            auto d = prepare(range.length);
            static if (is(Iterable : R[]) && !hasElaborateAssign!T)
            {
                // import core.stdc.string: memcpy;
                (()@trusted=>memcpy(d.ptr + cl, range.ptr, range.length * T.sizeof))();
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

    void reset()
    {
        this.__dtor;
        _currentLength = 0;
        _buffer = null;
    }

    scope T[] data() @property @safe
    {
        return _buffer.length > _bufferLength ? _buffer[0 .. _currentLength] : _scopeBuffer[0 .. _currentLength];
    }
}

///
@safe pure nothrow @nogc unittest
{
    ScopedBuffer!char buf;
    buf.put('c');
    buf.put("str");
    assert(buf.data == "cstr");
}

///
struct strbuf
{
    ///
    ScopedBuffer!char buffer;
    ///
    // alias buffer this;

    ///
    alias opBinary(string op : "<<") = print;

@safe pure @nogc:

    ///
    ref typeof(this) print(char c) scope return
    {
        buffer.put(c);
        return this;
    }

    ///
    ref typeof(this) print(scope const(char)[] c) scope return
    {
        buffer.put(c);
        return this;
    }

    ///
    ref typeof(this) print(bool c) scope return
    {
        return print(c ? "true" : "false");
    }
}

