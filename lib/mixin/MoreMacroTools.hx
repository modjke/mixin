package mixin;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.ComplexType;
import haxe.macro.Expr.Position;
import haxe.macro.Expr.TypePath;

using haxe.macro.Tools;


class MoreMacroTools 
{

	public static function exprToComplexType(e:Expr, p:Position):ComplexType
	{
		var tp = parseTypePath(e.toString(), p);
		return ComplexType.TPath(tp);
	}
	
	static function parseTypePath(s:String, p:Position):TypePath
	{
		return switch (Context.parse('new $s()', p).expr)
		{
			case ENew(t, p): t;
			case _: throw 'Failed to parse $s';
		}		
	}
	
	
	public static function resolveClassName(e:Expr):String
	{
		var cls = Context.typeof(e).toComplexType().toString();
		// in case of Class<...>
		var re = ~/Class<(\S+)>/;
		if (re.match(cls))
			cls = re.matched(1);
			
		return cls;
	}
	
	
	public static function isValidClassName(s:String):Bool
	{
		return ~/\b[A-Z][_,A-Z,a-z,0-9]*/.match(s);
	}
	
	public static function resolveComplextType(t:ComplexType, p:Position):ComplexType
	{
		if (t == null) return null;
		
		var out = Context.resolveType(t, p).toComplexType();
		//trace(safeToString(t) + " =>> " + safeToString(t));
		return out;
	}	
	
	public static function safeToString(?t:ComplexType)
	{
		return t != null ? t.toString() : "null";
	}
	
	public static function extractTypePath(t:ComplexType):TypePath
	{
		return switch (t)
		{
			case TPath(tp): tp;
			case _: 
				throw 'Failed to extract TypePath from ${safeToString(t)}';
		}
	}
}