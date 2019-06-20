/**
Provides some type magic.

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
*/
module dext.typecons;

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
        alias members = __traits( allMembers, T );
        bool[members.length] flagSet;
    }
    
    static foreach( i, name; members )
        mixin( "bool %s() const pure nothrow @property { return this.flagSet[%s]; }".format( name, i ) );

    /++
    Constructs a new parameter set from the specified overrides.

    All flags not present in this constructor will default to [false].

    Authors: Tony J. Hudgins
    Copyright: Copyright © 2019, Tony J. Hudgins
    License: MIT
    +/
    this( T[] flags... )
    {
        foreach( item; flags )
        static foreach( i, name; members )
        {
            if( item == mixin( "T." ~ name ) )
                this.flagSet[i] = true;
        }
    }
}
