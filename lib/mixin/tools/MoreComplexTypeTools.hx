package mixin.tools;
import haxe.macro.Context;
import haxe.macro.Expr.ComplexType;
import haxe.macro.Expr.Position;
import haxe.macro.Expr.TypePath;

using haxe.macro.Tools;

class MoreComplexTypeTools 
{
	public static function resolve(t:ComplexType, p:Position):ComplexType
	{
		if (t == null) return null;
		
		var out = Context.resolveType(t, p).toComplexType();
		//trace(safeToString(t) + " =>> " + safeToString(t));
		return out;
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
	
	public static function safeToString(?t:ComplexType)
	{
		return t != null ? t.toString() : "null";
	}
}