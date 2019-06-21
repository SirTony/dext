/**
Provides some type magic.

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
*/
module dext.typecons;

import std.traits : isSomeString;

private string ucfirst( S )( S s ) if( isSomeString!S )
{
    if( !s.length ) return s;

    import std.string : capitalize;
    return s[0 .. 1].capitalize() ~ s[1 .. $];
}

@system unittest
{
    auto none = "";
    assert( none.ucfirst() == "", "none.ucfirst()" );

    auto single = "a";

    assert( single.ucfirst() == "A", "single.ucfirst()" );

    auto multi = "abc";
    assert( multi.ucfirst() == "Abc", "multi.ucfirst()" );
}

/++
Represents a set of flags built from an enum intended to be used at compile-time for configuring the behaviour
of templates, mixins, or other compile-time features.

Credit to Ethan Watson and his wonderful DConf 2019 talk for this idea.

Examples:
-----------------
enum MyConfig : string
{
    someOption = "do something cool, like a barrel roll",
    lazyProcessing = "be as lazy as possible"
}

alias MyParams = Params!MyConfig;

struct SomeStruct( MyParams params = MyParams.init )
{
    static if( params.someOption )
    {
        // do something cool...
    }

    static if( params.lazyProcessing )
    {
        // ...
    }
}
-----------------

See_Also: https://dconf.org/2019/talks/watson.html
Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
struct Params( T ) if( is( T == enum ) )
{
    import std.format : format;

    private {
        alias Self = typeof( this );
        alias members = __traits( allMembers, T );

        bool[members.length] flagSet;

        enum size_t[size_t] hashToIndex = {
            import std.traits : EnumMembers;

            size_t[size_t] map;

            static foreach( i, value; EnumMembers!T )
                map[value.hashOf()] = i;

            return map;
        }();
    }

    static foreach( i, name; members )
    {
        mixin( "bool %s() const pure nothrow @property { return this.flagSet[%s]; }".format( name, i ) );
        mixin( "static Self of%s() pure nothrow @property { return Self( T.%s ); }".format( name.ucfirst(), name ) );
    }

    /++
    Constructs a new parameter set from the specified overrides.

    All flags not present in this constructor will default to [false].

    Params:
        flags = A variadic list of flags to override.

    Authors: Tony J. Hudgins
    Copyright: Copyright © 2019, Tony J. Hudgins
    License: MIT
    +/
    this( T[] flags... )
    {
        foreach( item; flags )
        {
            auto idx = Self.hashToIndex[item.hashOf()];
            this.flagSet[idx] = true;
        }
    }
}
