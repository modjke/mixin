package mixin.tools;
import haxe.macro.Expr.TypeParam;

class TypeParamTools 
{

	public static function toString(tp:TypeParam):String
	{
		if (tp == null) return null;
		
		return switch(tp) {
			case TPType(ct): ct.toString();
			case TPExpr(e): e.toString();
		}
	}
	
}