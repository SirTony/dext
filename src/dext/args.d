/**
Provides some convenience functionality for parsing command-line arguments
by piggy-backing off std.getopt.

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
*/
module dext.args;

import std.traits   : hasUDA, getUDAs, fullyQualifiedName;
import std.getopt   : GetOptException, Option;
import std.format   : format;

private {
    T ctor( T, U... )( U args ) if( is( T == class ) || is( T == struct ) )
    {
        static if( is( T == class ) )
            return new T( args );
        else
            return T( args );
    }

    template getSingleUDA( alias where, alias what, alias orElse )
    {
        static if( !hasUDA!( where, what ) )
            enum getSingleUDA = orElse;
        else
        {
            alias udas = getUDAs!( where, what );
            static assert(
                udas.length == 1,
                "%s cannot have more than one %s attribute".format(
                    __traits( identifier, where ),
                    fullyQualifiedName!what
                )
            );

            enum getSingleUDA = udas[0];
        }
    }

    enum help(   alias field ) = getSingleUDA!( field, Help,      cast(string)null );
    enum banner( alias type  ) = getSingleUDA!( type,  Banner,    cast(string)null );

    template flag( alias field )
    {
        enum ident = __traits( identifier, field );

        static if( hasUDA!( field, ShortName ) )
            enum flag = "%s|%s".format( cast(char)getSingleUDA!( field, ShortName, char.init ), ident );
        else
            enum flag = ident;
    }

    string escape( string s )
    {
        import std.string : replace;
        return `"%s"`.format( s.replace( "\"", "\\\"" ) );
    }

    string defaultFormatter( string banner, Option[] options )
    {
        import std.array  : appender;
        import std.getopt : defaultGetoptFormatter;

        auto formatted = appender!string;
        defaultGetoptFormatter( formatted, banner, options );

        return formatted.data;
    }

    mixin template SingletonUDA( T )
    {
        private T _value;
        alias _value this;

        this() @disable;
        this( T value ) { this._value = value; }
    }
}

/++
A single printable character representing a short flag for a command line argument.
e.x. '-v'

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
struct ShortName
{
    mixin SingletonUDA!char;

    invariant
    {
        import std.uni : isControl;
        if( this._value.isControl )
            throw new GetOptException( "short name must be a printable character" );
    }
}

/++
Help string for an option that will be displayed on the usage screen.

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
struct Help   { mixin SingletonUDA!string; }

/++
A banner that will be printed to the usage screen before the options.

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
struct Banner { mixin SingletonUDA!string; }

/++
Indicates that an option is required.

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
struct Required             { }

/++
Indicates that that argument parsing is case-sensitive. Incompatible with [CaseInsensitive].

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
struct CaseSensitive        { }

/++
Indicates that argument parsing is case-insensitive. Incompatible with [CaseSensitive].

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
struct CaseInsensitive      { }

/++
Allow short options to be bundled e.g. '-xvf'. Incompatible with [NoBundling].

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
struct AllowBundling        { }

/++
Disallow short options to be bundled. Incompatible with [AllowBundling].

See_Also: AllowBundling
Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
struct NoBundling           { }

/++
Pass unrecognized options through silently. Incompatible with [NoPassThrough].

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
struct PassThrough          { }

/++
Don't pass unrecognized options through silently. Incompatible with [PassThrough].

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
struct NoPassThrough        { }

/++
Stops processing on the first string that doesn't look like an option.

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
struct StopOnFirstNonOption { }

/++
Keep the end-of-options marker string.

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
struct KeepEndOfOptions     { }

alias OptionFormatter = string delegate( string, Option[] );

/++
Use std.getopt.getopt to parse command-line arguments into a class or struct.

This function automatically invokes the constructor for the class or struct and requires a public, parameterless constructor to work.
Does not take opCall() into account for classes.

The caller can optionally provide an [OptionFormatter] delegate to format options into a prett-printed string to display on the help screen.
If no delegate is provided the default std.getopt.defaultGetoptFormatter function will be used as a fallback.

Automatically prints the help text and exits the process when help is requested.

Params:
    args = The array of arguments provided in main().
    formatter = Optional option formatter.

Throws: std.getopt.GetoptException if parsing fails.

Examples:
--------------------
struct MyOptions
{
    @ShortName( 'v' )
    bool verbose;
}

void main( string[] args )
{
    import std.stdio;

    auto parsed = args.parseArgs!MyOptions;
    writelfn( "is verbose? %s", parsed.verbose ? "yes" : "no" );
}
--------------------

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
T parseArgs( T )( ref string[] args, lazy OptionFormatter formatter = null )
    if( is( T == class ) || is( T == struct ) )
{
    auto x = ctor!T;
    parseArgs( args, x, formatter );
    return x;
}

/++
Use std.getopt.getopt to parse command-line arguments into a class or struct.

This function takes a reference to an already existing instance of the destination class or struct if manual construction
is needed prior to parsing.

The caller can optionally provide an [OptionFormatter] delegate to format options into a prett-printed string to display on the help screen.
If no delegate is provided the default std.getopt.defaultGetoptFormatter function will be used as a fallback.

Automatically prints the help text and exits the process when help is requested.

Params:
    args = The array of arguments provided in main().
    instance = The instance that will contain parsed values.
    formatter = Optional option formatter.

Throws: std.getopt.GetoptException if parsing fails.

Examples:
--------------------
struct MyOptions
{
    @ShortName( 'v' )
    bool verbose;

    string optional;

    this( string optional )
    {
        this.optional = optional;
    }
}

void main( string[] args )
{
    import std.stdio;

    auto parsed = MyOptions( "some default value" );
    args.parseArgs( parsed );
    writelfn( "optional value: %s", parsed.optional );
}
--------------------

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
void parseArgs( T )( ref string[] args, ref T instance, lazy OptionFormatter formatter = null )
    if( is( T == class ) || is( T == struct ) )
{
    import std.getopt : config, getopt, defaultGetoptFormatter, Option;
    import std.string : join;

    enum string[] getoptArgs = {
        import std.traits : FieldNameTuple;
        import std.conv   : to;

        string[] mixArgs;

        static if( hasUDA!( T, CaseSensitive ) && hasUDA!( T, CaseInsensitive ) )
            static assert( false, "@CaseSensitive and @CaseInsensitive are mutually exclusive" );
        
        static if( hasUDA!( T, AllowBundling ) && hasUDA!( T, NoBundling ) )
            static assert( false, "@AllowBundling and @NoBundling are mutually exclusive" );
        
        static if( hasUDA!( T, PassThrough ) && hasUDA!( T, NoPassThrough ) )
            static assert( false, "@PassThrough and @NoPassThrough are mutually exclusive" );
        
        static if( hasUDA!( T, CaseSensitive ) )
            mixArgs ~= "config.caseSensitive";
        
        static if( hasUDA!( T, CaseInsensitive ) )
            mixArgs ~= "config.caseInsensitive";
        
        static if( hasUDA!( T, AllowBundling ) )
            mixArgs ~= "config.allowBundling";
        
        static if( hasUDA!( T, NoBundling ) )
            mixArgs ~= "config.noBundling";
        
        static if( hasUDA!( T, PassThrough ) )
            mixArgs ~= "config.passThrough";
        
        static if( hasUDA!( T, NoPassThrough ) )
            mixArgs ~= "config.noPassThrough";
        
        static if( hasUDA!( T, StopOnFirstNonOption ) )
            mixArgs ~= "config.stopOnFirstNonOption";
        
        static if( hasUDA!( T, KeepEndOfOptions ) )
            mixArgs ~= "config.keepEndOfOptions";
        
        static foreach( i, name; FieldNameTuple!T )
        {
            static if( hasUDA!( __traits( getMember, instance, name ), Required ) )
                mixArgs ~= "config.required";
            
            mixArgs ~= flag!( __traits( getMember, instance, name ) ).escape();
            
            static if( hasUDA!( __traits( getMember, instance, name ), Help ) )
                mixArgs ~= help!( __traits( getMember, instance, name ) ).escape();
            
            mixArgs ~= "&instance.%s".format( name );
        }
        
        return mixArgs;
    }();

    mixin( "auto result = getopt( args, %s );".format( getoptArgs.join( "," ) ) );
    
    if( result.helpWanted )
    {
        import std.functional   : toDelegate;
        import std.stdio        : stderr;
        import core.stdc.stdlib : exit;

        auto fn = formatter is null ? toDelegate( &defaultFormatter ) : formatter;
        auto formatted = fn( cast(string) banner!T, result.options );
        stderr.writeln( formatted );
        stderr.flush();

        exit( -1 );
    }
}

version( unittest )
{
    enum Color { red, green, blue }

    @Banner( "My Super Cool App" )
    @CaseSensitive
    struct MyOptions
    {
        @Help( "be noisy" )
        @ShortName( 'v' )
        @Required
        bool verbose;

        @Required
        @Help( "what color" )
        @ShortName( 'c' )
        Color color;
    }
}

@system unittest
{
    auto args = [ "test.exe", "-v", "--color=green" ];
    auto parsed = args.parseArgs!MyOptions;

    assert( parsed.verbose );
    assert( parsed.color == Color.green );
}