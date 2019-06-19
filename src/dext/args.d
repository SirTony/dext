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

struct Help   { mixin SingletonUDA!string; }
struct Banner { mixin SingletonUDA!string; }

struct Required             { }
struct CaseSensitive        { }
struct CaseInsensitive      { }
struct AllowBundling        { }
struct NoBundling           { }
struct PassThrough          { }
struct NoPassThrough        { }
struct StopOnFirstNonOption { }
struct KeepEndOfOptions     { }

alias OptionFormatter = string delegate( string, Option[] );

T parseArgs( T )( ref string[] args, lazy OptionFormatter formatter = null )
    if( is( T == class ) || is( T == struct ) )
{
    auto x = ctor!T;
    parseArgs( args, x, formatter );
    return x;
}

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