package mixin.tools;
import haxe.macro.Expr;

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
	
}