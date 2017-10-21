package mixin.tools;
import haxe.macro.Expr;

using haxe.macro.Tools;

class MoreExprTools 
{

	/**
	 * Prepends e to dst
	 */
	public static function prepend(dst:Expr, e:Expr)
	{
		dst.expr = switch (dst.expr)
		{
			case EBlock(exprs):
				exprs.unshift(e);
				EBlock(exprs);
			case _:
				(macro $b{[e, dst]}).expr;
		}
	}
	
	public static function getBoolValue(e:Expr):Null<Bool>
	{
		try {
			var value = e.getValue();
			if (Std.is(value, Bool)) 
				return value;
				
		} catch (ignore:Dynamic) {}
		
		return null;
	}
}