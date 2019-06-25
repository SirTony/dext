/**
Provides value conversion functionality, supplemental to [std.conv].

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
*/
module dext.conv;

import std.traits : isIntegral, isStaticArray, isDynamicArray;
import std.range  : ElementType;

version( unittest ) import std.system : Endian, endian;

private template isByteArray( N, A )
{
    static if( isStaticArray!A )
        enum isByteArray = A.length == N.sizeof && is( ElementType!A : ubyte );
    else static if( isDynamicArray!A )
        enum isByteArray = is( ElementType!A : ubyte );
    else
        enum isByteArray = false;
}

/++
Converts an integral number to a static or dynamic array of [ubyte].

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT

Examples:
---------
int num = 10;
ubyte[4] bytes = num.to!( ubyte[4] );
---------
+/
A to( A, N )( N x ) if( isByteArray!( N, A ) && isIntegral!N )
{
    static union Numeric
    {
        N num;
        ubyte[N.sizeof] bytes;
    }

    static if( isDynamicArray!A )
        return Numeric( x ).bytes.dup;
    else static if( isStaticArray!A )
    {
        auto num = Numeric( x );
        A copy;
        copy[] = num.bytes[];

        return copy;
    } else static assert( false );
}

@system unittest
{
    // dynamic array
    enum int five = 5;

    static if( endian == Endian.littleEndian )
    {
        enum ubyte[] expectedDynamic = [ 5, 0, 0, 0 ];
        enum ubyte[int.sizeof] expectedStatic = [ 5, 0, 0, 0 ];
    }
    else static if( endian == Endian.bigEndian )
    {
        enum ubyte[] expectedDynamic = [ 0, 0, 0, 5 ];
        enum ubyte[int.sizeof] expectedStatic = [ 0, 0, 0, 5 ];
    }

    auto x = five.to!( ubyte[] );
    assert( x == expectedDynamic, "num -> ubyte[]" );

    auto y = five.to!( ubyte[4] );
    assert( x == expectedStatic, "num -> ubyte[4]" );
}

/++
Converts an array (either static or dynamic, but not associative) of [ubyte] to an integral number.

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT

Examples:
---------
import std.system : Endian, endian;

static if( endian == Endian.littleEndian )
    auto bytes = [ 10, 0, 0, 0 ];
else
    auto bytes = [ 0, 0, 0, 10 ];

int num = bytes.to!int; // 10
---------
+/
N to( N, A )( A arr ) if( isByteArray!( N, A ) && isIntegral!N )
{
    static union Numeric
    {
        ubyte[N.sizeof] bytes;
        N num;
    }

    static if( isStaticArray!A )
        return Numeric( arr ).num;
    else
    {
        if( arr.length != N.sizeof )
        {
            import std.format : format;
            import std.conv   : ConvException;

            throw new ConvException(
                "byte array must be equal to %s.sizeof (%s). actual length: %s"
                .format(
                    N.stringof,
                    N.sizeof,
                    arr.length
                )
            );
        }

        Numeric num;
        num.bytes[] = arr[];

        return num.num;
    }
}

@system unittest
{
    static if( endian == Endian.littleEndian )
    {
        enum ubyte[] dynamicArray = [ 5, 0, 0, 0 ];
        enum ubyte[int.sizeof] staticArray = [ 5, 0, 0, 0 ];
    }
    else static if( endian == Endian.bigEndian )
    {
        enum ubyte[] dynamicArray = [ 0, 0, 0, 5 ];
        enum ubyte[int.sizeof] staticArray = [ 0, 0, 0, 5 ];
    }

    enum int expected = 5;

    auto x = dynamicArray.to!int;
    assert( x == expected, "ubyte[] -> int" );

    auto y = staticArray.to!int;
    assert( x == expected, "ubyte[4] -> int" );
}
