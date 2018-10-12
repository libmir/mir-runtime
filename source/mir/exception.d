/++
`@nogc` exceptions and errors definitions.
+/
module mir.exception;

version(D_Exceptions):

/++
+/
class MirException : Exception
{
    ///
    mixin MirThrowableImpl;
}

///
@safe pure nothrow @nogc
unittest
{
    @safe pure nothrow @nogc 
    bool func(scope const(char)[] msg)
    {
        /// scope messages are copied
        try throw new MirException(msg);
        catch(Exception e) assert(e.msg == msg);
    
        /// immutable strings are not copied
        static immutable char[] gmsg = "global msg";
        try throw new MirException(gmsg);
        catch(Exception e) assert(e.msg is gmsg);
    
        return __ctfe;
    }

    assert(func("runtime-time check") == 0);

    static assert(func("compile-time check") == 1);
}

/++
+/
class MirError : Error
{
    ///
    mixin MirThrowableImpl;
}

///
@system pure nothrow @nogc
unittest
{
    @system pure nothrow @nogc 
    bool func(scope const(char)[] msg)
    {
        /// scope messages are copied
        try throw new MirException(msg);
        catch(Exception e) assert(e.msg == msg);
    
        /// immutable strings are not copied
        static immutable char[] gmsg = "global msg";
        try throw new MirError(gmsg);
        catch(Error e) assert(e.msg is gmsg);
    
        return __ctfe;
    }

    assert(func("runtime-time check") == 0);

    static assert(func("compile-time check") == 1);
}

/++
+/
mixin template MirThrowableImpl()
{
    private bool _global;
    private char[maxMsgLen] _payload = void;

    /++
    Params:
        msg = message. No-scope `msg` is assumed to have the same lifetime as the throwable. scope strings are copied to internal buffer.
        file = file name, zero terminated global string
        line = line number
        nextInChain = next exception in the chain (optional)
    +/
    @nogc @safe pure nothrow this(scope const(char)[] msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super((() @trusted => cast(immutable) initilizePayload(_payload, msg))(), file, line, nextInChain);
    }

    /// ditto
    @nogc @safe pure nothrow this(scope const(char)[] msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        this(msg, file, line, nextInChain);
    }

    /// ditto
    @nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        this._global = true;
        super(msg, file, line, nextInChain);
    }

    /// ditto
    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        this._global = true;
        super(msg, file, line, nextInChain);
    }

    ///
    ~this() @trusted
    {
        import mir.internal.memory: free;
        if (!_global && msg.ptr != _payload.ptr)
            free(cast(void*)msg.ptr);
    }
}

private enum maxMsgLen = 447;

pragma(inline, false)
pure nothrow @nogc @safe
private const(char)[] initilizePayload(ref return char[maxMsgLen] payload, scope const(char)[] msg)
{
    import mir.internal.memory: malloc;
    import core.stdc.string: memcpy;
    if (msg.length > payload.length)
    {
        if (auto ret = (() @trusted
            {
                if (__ctfe)
                    return null;
                if (auto ptr = malloc(msg.length))
                {
                    memcpy(ptr, msg.ptr, msg.length);
                    return cast(const(char)[]) ptr[0 .. msg.length];
                }
                return null;
            })())
            return ret;
        msg = msg[0 .. payload.length];
        // remove tail UTF-8 symbol chunk if any
        uint c = msg[$-1];
        if (c > 0b_0111_1111)
        {
            do {
                c = msg[$-1];
                msg = msg[0 .. $ - 1];
            }
            while (msg.length && c < 0b_1100_0000);
        }
    }
    if (__ctfe)
        payload[0 .. msg.length] = msg;
    else
        (() @trusted => memcpy(payload.ptr, msg.ptr, msg.length))();
    return payload[0 .. msg.length];
}
