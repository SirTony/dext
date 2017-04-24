module dext.record;

private {
    import std.traits : isSomeString;

    // This catches types and is needed so Filter!( isIdentifier, T )
    // works correctly
    enum isIdentifier( T ) = false;

    template isIdentifier( T... ) if( T.length == 1 )
    {
        static if( isType!( T[0] ) )
            enum isIdentifier = false;
        else
            enum isIdentifier = stringIsIdentifier!( T[0] );
    }

    template stringIsIdentifier( alias S ) if( isSomeString!( typeof( S ) ) )
    {
        import std.algorithm.searching : all;
        import std.uni : isAlpha, isAlphaNum;

        static if( S.length == 0 )
            enum stringIsIdentifier = false;
        static if( S.length == 1 )
            enum stringIsIdentifier = S[0] == '_' || S[0].isAlpha;
        else
            enum stringIsIdentifier = ( S[0] == '_' || S[0].isAlpha )
                                   && S[1 .. $].all!( c => c == '_' || c.isAlphaNum );
    }

    template isType( T... ) if( T.length == 1 )
    {
        enum isType = is( T[0] );
    }

    template areTypeNamePairs( T... ) if( T.length % 2 == 0 )
    {
        static if( T.length == 2 )
            enum areTypeNamePairs = is( T[0] ) &&
                                    isIdentifier!( T[1] );
        else
            enum areTypeNamePairs = is( T[0] ) &&
                                    isIdentifier!( T[1] ) &&
                                    areTypeNamePairs!( T[2 .. $] );
    }

    string generateFields( string[] fieldNames, string[] typeNames )()
        if( fieldNames.length == typeNames.length )
    {
        import std.array  : appender;
        import std.range  : zip;

        auto code = appender!string;
        foreach( pair; typeNames.zip( fieldNames ) )
        {
            // Private backing field
            code.put( "private const " );
            code.put( pair[0] ); // type name
            code.put( " _" ); // field names are prefixed with an underscore
            code.put( pair[1] ); // field name;
            code.put( ";" );

            // Public getter-only property
            code.put( pair[0] ); // type name
            code.put( " " );
            code.put( pair[1] ); // field name
            code.put( "() const @property" );
            code.put( "{ return this._" );
            code.put( pair[1] ); // field name
            code.put( "; }" );
        }

        return code.data;
    }
}

/++
Immutable value type that automatically implements equality (==, !=),
hashcode computation (toHash), and stringification (toString).
The purpose of this struct is act similarly to record types in functional
programming languages like OCaml and Haskell.

Authors: Tony J. Hudgins

Examples:
---------
// define a point int 2D space
alias Point = Record!(
    int, "x",
    int, "y"
);

auto a = Point( 3, 7 );
auto b = Point( 9, 6 );

// Euclidean distance
auto distance( in Point a, in Point b )
{
    import std.math : sqrt;

    return sqrt( ( a.x - b.x ) ^^ 2f + ( a.y - b.y ) ^^ 2f );
}

auto dist = distance( a, b ); // 6.08276
---------
+/
struct Record( T... ) if( T.length % 2 == 0 && areTypeNamePairs!T )
{
    import std.meta : Filter, staticMap;
    import std.traits : fullyQualifiedName;

    private {
        alias Self = typeof( this );
        alias Types = Filter!( isType, T );

        static immutable _typeNames = [ staticMap!( fullyQualifiedName, Types ) ];
        static immutable _fieldNames = [ Filter!( isIdentifier, T ) ];
    }

    // private backing fields and getter-only properties
    mixin( generateFields!( _fieldNames, _typeNames ) );

    /++
    Accepts parameters matching the types of the fields declared in the template arguments
    and automatically assigns values to the backing fields.
    +/
    this( Types values )
    {
        import std.string : format;
        foreach( i, _; Types )
            mixin( "this._%s = values[%u];".format( _fieldNames[i], i ) );
    }

    bool opEquals()( auto ref const Self other ) const nothrow @trusted
    {
        auto eq = true;
        foreach( i, _; Types )
        {
            auto thisPtr = this.pointerTo!( _fieldNames[i] );
            auto otherPtr = other.pointerTo!( _fieldNames[i] );

            eq = eq && *thisPtr == *otherPtr;
        }

        return eq;
    }

    size_t toHash() const nothrow @trusted
    {
        size_t hash = 486_187_739;
        foreach( i, T; Types )
        {
            auto ptr = this.pointerTo!( _fieldNames[i] );
            auto fieldHash = typeid( T ).getHash( cast(const(void)*)ptr );
            hash = ( hash * 15_485_863 ) ^ fieldHash;
        }

        return hash;
    }

    string toString() const
    {
        import std.array : appender;
        import std.conv  : to;

        auto str = appender!string;
        str.put( "{ " );

        enum len = Types.length;
        foreach( i, _; Types )
        {
            auto ptr = this.pointerTo!( _fieldNames[i] );
            str.put( _fieldNames[i] );
            str.put( " = " );
            str.put( (*ptr).to!string );

            if( i < len - 1 )
                str.put( ", " );
        }

        str.put( " }" );
        return str.data;
    }

    private auto pointerTo( string name )() const nothrow @trusted
    {
        mixin( "return &this._" ~ name ~ ";" );
    }
}

@safe unittest
{
    alias Point = Record!(
        int, "x",
        int, "y"
    );

    alias Size = Record!(
        int, "width",
        int, "height"
    );

    alias Rectangle = Record!(
        Point, "location",
        Size, "size"
    );

    const a = Point( 1, 2 );
    const b = Point( 3, 4 );

    assert( a != b && b != a );
    assert( a.toHash() != b.toHash() );

    const c = Size( 50, 100 );
    const d = Rectangle( a, c );

    assert( d.location == a );
    assert( d.size == c );
}