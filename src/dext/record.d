/**
Provides functionality for easily creating immutable record types.

Authors: Tony J. Hudgins
Copyright: Copyright © 2017-2019, Tony J. Hudgins
License: MIT
*/
module dext.record;

import dext.typecons : Params;

/++
A set of configuration values for changing the behaviour of the Record mixin.

Authors: Tony J. Hudgins
Copyright: Copyright © 2017-2019, Tony J. Hudgins
License: MIT
+/
enum RecordConfig : string
{
    /// Suppress automatic constructor generation.
    suppressCtor = "Suppress automatic constructor generation.",

    /// Automatically generate a [deconstruct] method for use with the [let] module.
    enableLet = "Automatically generate a deconstruct method for use with the 'let' module.",

    /// Automatically generate [with<FieldName>] methods to create copies with new values.
    enableMutation = "Automatically generate 'with<fieldName>' methods.",

    /// Automatically generate setters for all fields, making the records mutable.
    enableSetters = "Automatically generate setters for all fields, making the record mutable.",
}

alias RecordParams = Params!RecordConfig;

/++
A mixin template for turning a struct into an immutable value type
that automatically implements equality (==, !=), hashcode computation (toHash),
stringification (toString), and mutation methods that create new copies with new values.

The purpose of this struct is act similarly to record types in functional
programming languages like OCaml and Haskell.

Accepts an optional, boolean template parameter. When true, the mixin will generate
a deconstruction method for use with <a href="/dext/dext/let">let</a>. Default is false.

All fields on the struct must start with an underscore and be non-public. Both are enforced with static asserts.

Authors: Tony J. Hudgins
Copyright: Copyright © 2017-2019, Tony J. Hudgins
License: MIT

Examples:
---------
// define a point int 2D space
struct Point
{
    mixin Record!true;
    private int _x, _y;
}

auto a = Point( 3, 7 );
auto b = a.withX( 10 ); // creates a new copy of 'a' with a new 'x' value of 10 and the same 'y' value such that b == Point( 10, 7 )

// Euclidean distance
auto distance( in Point a, in Point b )
{
    import std.math : sqrt;

    return sqrt( ( a.x - b.x ) ^^ 2f + ( a.y - b.y ) ^^ 2f );
}

auto dist = distance( a, b );
---------
+/
mixin template Record( RecordParams params = RecordParams.init )
{
    import std.traits : FieldTypeTuple, FieldNameTuple, staticMap;
    import std.format : format;

    static assert(
        is( typeof( this ) ) && ( is( typeof( this ) == class ) || is( typeof( this ) == struct ) ),
        "Record mixin template may only be used from within a struct or class"
    );

    invariant
    {
        static foreach( name; FieldNameTuple!( typeof( this ) ) )
        {
            static assert(
                name[0] == '_',
                "field '%s' must start with an underscore".format( name )
            );

            static assert(
                name.length >= 2,
                "field '%s' must have at least one other character after the underscore".format( name )
            );

            static assert(
                __traits( getProtection, __traits( getMember, this, name ) ) != "public",
                "field '%s' cannot be public".format( name )
            );
        }
    }

    static if( !params.suppressCtor )
    this( FieldTypeTuple!( typeof( this ) ) args ) @trusted
    {
        static foreach( i, name; FieldNameTuple!( typeof( this ) ) )
            __traits( getMember, this, name ) = args[i];
    }

    // generate getters and mutation methods
    static foreach( name; FieldNameTuple!( typeof( this ) ) )
    {
        // read-only getter method
        mixin( "auto %s() const pure nothrow @property { return this.%s; }".format( name[1 .. $], name ) );

        static if( params.enableSetters )
        mixin(
            "void %01$s( typeof( this.%02$s ) x ) nothrow @property { this.%02$s = x; }"
            .format( name[1 .. $], name )
        );

        static if( params.enableMutation )
        // mutation method
        mixin( {
            import std.array  : appender, join;
            import std.uni    : toUpper;

            enum trimmed = name[1 .. $];
            enum upperName =
                name.length == 1 ?
                trimmed.toUpper() :
                "%s%s".format( trimmed[0].toUpper(), trimmed[1 .. $] );

            auto code = appender!string;
            code.put(
                "typeof( this ) with%01$s( typeof( this.%02$s ) new%01$s ) @trusted {"
                .format( upperName, name )
            );

            string[] args;
            foreach( other; FieldNameTuple!( typeof( this ) ) )
                args ~= name == other ? "new%s".format( upperName ) : "this.%s".format( other );

            static if( is( typeof( this ) == class ) )
                code.put( "return new typeof( this )( %s ); }".format( args.join( ", " ) ) );
            else
                code.put( "return typeof( this )( %s ); }".format( args.join( ", " ) ) );

            return code.data;
        }() );
    }

    static if( params.enableLet )
    {
        import dext.traits : asPointer;
        void deconstruct( staticMap!( asPointer, FieldTypeTuple!( typeof( this ) ) ) ptrs ) nothrow @trusted
        {
            static foreach( i, name; FieldNameTuple!( typeof( this ) ) )
                *ptrs[i] = __traits( getMember, this, name );
        }
    }

    bool opEquals()( auto ref const typeof( this ) other ) const nothrow @trusted
    {
        auto eq = true;

        static foreach( name; FieldNameTuple!( typeof( this ) ) )
            eq = eq && ( __traits( getMember, this, name ) == __traits( getMember, other, name ) );

        return eq;
    }

    static if( is( typeof( this ) == class ) )
        override string toString() const { return this.toStringImpl(); }
    else
        string toString() const { return this.toStringImpl(); }

    static if( is( typeof( this ) == class ) )
        override size_t toHash() const nothrow @trusted { return this.toHashImpl(); }
    else
        size_t toHash() const nothrow @trusted { return this.toHashImpl(); }

    private string toStringImpl() const
    {
        import std.traits : Unqual, isSomeString, isSomeChar;
        import std.array  : appender, join, replace;
        import std.conv   : to;

        auto str = appender!string;
        str.put( Unqual!( typeof( this ) ).stringof );
        str.put( "(" );

        string[] values;

        foreach( name; FieldNameTuple!( typeof( this ) ) )
        {
            alias T = typeof( __traits( getMember, this, name ) );
            const value = __traits( getMember, this, name );

            static if( isSomeString!T )
                values ~= `"%s"`.format( value.replace( "\"", "\\\"" ) );
            else static if( isSomeChar!T )
                values ~= value == '\'' || value == '\\' ? "'\\%s'".format( value ) : "'%s'".format( value );
            else
                values ~= "%s".format( value );
        }

        str.put( values.join( ", " ) );
        str.put( ")" );

        return str.data;
    }

    private size_t toHashImpl() const nothrow @trusted
    {
        import std.traits : fullyQualifiedName;

        size_t hash = 486_187_739;

        foreach( name; FieldNameTuple!( typeof( this ) ) )
        {
            const typeName = fullyQualifiedName!( typeof( this ) );
            const value = __traits( getMember, this, name );

            // create a local variable so we can take the address
            const nameTemp = name;

            // hash the names to try and avoid collisions with identical structs.
            const typeHash  = typeid( string ).getHash( &typeName );
            const nameHash  = typeid( string ).getHash( &nameTemp );
            const valueHash = typeid( typeof( value ) ).getHash( &value );

            hash = ( hash * 15_485_863 ) ^ typeHash ^ nameHash ^ valueHash;
        }

        return hash;
    }
}

@system unittest
{
    import std.typecons : Tuple, tuple;
    import dext.let : let;

    struct Mutable
    {
        mixin Record!( RecordParams.ofEnableSetters );
        private int _x;
    }

    auto mut = Mutable( 5 );
    assert( mut.x == 5 );
    mut.x = 10;
    assert( mut.x == 10 );

    final class RecordClass
    {
        mixin Record;
        private int _x;
    }

    auto klass = new RecordClass( 5 );
    assert( klass.x == 5 );

    struct Point
    {
        mixin Record!( RecordParams.ofEnableLet );
        private int _x, _y;
    }

    struct Size
    {
        mixin Record;
        private int _width, _height;
    }

    struct Rectangle
    {
        mixin Record;
        private Point _location;
        private Size _size;
    }

    struct Person
    {
        mixin Record!( RecordParams.ofEnableLet );

        private {
            string _firstName;
            string[] _middleNames;
            string _lastName;
            ubyte _age;
        }
    }

    // to ensure non-primitive types defined in other modules/packages work properly
    struct External
    {
        mixin Record;
        private Tuple!( int, int ) _tup;
    }

    auto ext = External( tuple( 50, 100 ) );

    int e1, e2;
    let( e1, e2 ) = ext.tup;

    assert( e1 == 50 );
    assert( e2 == 100 );

    // test to ensure arrays work
    auto richardPryor = Person(
        "Richard",
        [ "Franklin", "Lennox", "Thomas" ],
        "Pryor",
        65
    );

    string[] middleNames;
    string _, n1, n2, n3;
    ubyte __;

    assert( richardPryor.middleNames == [ "Franklin", "Lennox", "Thomas" ] );

    let( _, middleNames, _, __ ) = richardPryor;
    let( n1, n2, n3 ) = middleNames;

    assert( n1 == "Franklin" );
    assert( n2 == "Lennox" );
    assert( n3 == "Thomas" );

    auto a = Point( 1, 2 );
    auto b = Point( 3, 4 );

    int x, y;
    let( x, y ) = a;

    assert( x == 1 );
    assert( y == 2 );

    assert( a != b && b != a );
    assert( a.toHash() != b.toHash() );

    auto c = Size( 50, 100 );
    auto d = Rectangle( a, c );

    assert( d.location == a );
    assert( d.size == c );
}
