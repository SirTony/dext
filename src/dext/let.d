module dext.let;

/++
Unpacks forward ranges, input ranges, static arrays,
dynamic arrays, tuples, and user-defined types (via deconstructor methods)
into the specified variables.

Authors: Tony J. Hudgins

Examples:
---------
// unpack an array
auto nums = [ 1, 2, 3 ];

int a, b, c;
let( a, b, c ) = nums; // access the array indices and assign them to the a, b, and c variables

// unpack a struct with a built-in deconstructor
struct Point
{
    immutable int x;
    immutable int y;

    void deconstruct( int* x, int* y )
    {
        *x = this.x;
        *y = this.y;
    }
}

auto pt = Point( 5, 6 );
int x, y;
let( x, y ) = pt; // call Point.deconstruct() with pointers to the x and y variables
---------
+/
auto let( Ts... )( ref Ts params )
{
    import core.exception : RangeError;
    import std.meta : allSatisfy, staticMap;
    import std.range.primitives : ElementType, isForwardRange, isInputRange;
    import std.string : format;
    import std.traits : CommonType, fullyQualifiedName, isArray, isCallable,
                        isFunctionPointer, isPointer, isStaticArray, Parameters,
                        ReturnType, Unqual;
    import std.typecons : Tuple;
    
    alias toPointer( T ) = T*;
    alias TPointers = staticMap!( toPointer, Ts );
    alias TCommon = CommonType!Ts;

    enum hasDeconstructorMethod( T ) = is( typeof( {
        static assert( __traits( hasMember, T, "deconstruct" ) );
        
        enum method = &__traits( getMember, T, "deconstruct" );
        static assert( isCallable!method );
        static assert( is( ReturnType!method == void ) );
        
        alias params = Parameters!method;
        static assert( params.length == Ts.length );
        static assert( allSatisfy!( isPointer, params ) );
        static assert( is( params == TPointers ) );
    } ) );
    
    static struct LetAssigner
    {
        private {
            TPointers pointers;
        }
        
        this( Ts... )( ref Ts params )
        {
            foreach( i, ref x; params )
                this.pointers[i] = &x;
        }
        
        void opAssign( Tuple!Ts tup )
        {
            foreach( i, _; Ts )
                *this.pointers[i] = tup[i];
        }
        
        static if( !is( TCommon == void ) )
        {
            void opAssign( TCommon[] arr )
            {
                if( arr.length < Ts.length )
                    throw new RangeError(
                        "Array has too few items to unpack (expecting at least %u)".format( Ts.length )
                    );
                
                foreach( i, t; Ts )
                    *this.pointers[i] = cast(t)arr[i];
            }
        }
        
        void opAssign( R )( R r )
            if( !isArray!R && isInputRange!R &&
                !isForwardRange!R && !is( TCommon == void ) &&
                is( ElementType!R : TCommon )
            )
        {
            this.rangeImpl( r );
        }
        
        void opAssign( R )( R r )
            if( !isArray!R && isForwardRange!R &&
                !is( TCommon == void ) && is( ElementType!R : TCommon )
            )
        {
            this.rangeImpl( r.save() );
        }
        
        private void rangeImpl( R )( R r )
        {
            foreach( i, t; Ts )
            {
                if( r.empty )
                    throw new RangeError(
                        "Range has too few items to unpack (expecting at least %u)".format( Ts.length )
                    );
                
                *this.pointers[i] = cast(t)r.front;
                r.popFront();
            }
        }
        
        void opAssign( T )( T value ) if( hasDeconstructorMethod!T )
        {
            value.deconstruct( this.pointers );
        }
    }
    
    return LetAssigner( params );
}

@system unittest
{
    import std.range : iota;

    struct Point
    {
        int x, y;

        void deconstruct( int* x, int* y )
        {
            *x = this.x;
            *y = this.y;
        }
    }

    int[] dynamic = [ 1, 2 ];
    float[2] static_ = [ 3f, 4f ];
    auto nums = iota( 0, 500 );
    auto pt = Point( 10, 15 );

    // test dynamic arrays
    int a, b;
    let( a, b ) = dynamic;

    assert( a == dynamic[0] );
    assert( b == dynamic[1] );

    // test static arrays
    float c, d;
    let( c, d ) = static_;

    assert( c == static_[0] );
    assert( d == static_[1] );

    // test ranges
    int i, j, k;
    let( i, j, k ) = nums;

    assert( i == 0 );
    assert( j == 1 );
    assert( k == 2 );

    // test deconstructor
    int x, y;
    let( x, y ) = pt;

    assert( x == pt.x );
    assert( y == pt.y );
}
