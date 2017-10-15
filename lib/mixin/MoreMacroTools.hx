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
	
	
	static function isFirstLetterUppercase(s:String):Bool
	{
		var c = s.charAt(s.length - 1);
		return c.toUpperCase() == c;
	}
	
	public static function resolve(t:ComplexType, p:Position):ComplexType
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