package mixin.tools;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;

using Lambda;

class FieldTools 
{

	public static function isMethod(f:Field):Bool
	{
		return switch (f.kind)
		{
			case FFun(_): true;
			case _: false;
		}
	}
	
	public static function isConstructor(f:Field):Bool
	{
		return f.name == "new";
	}
	
	public static function extractFFunFunction(f:Field):Function
	{
		return switch (f.kind)
		{
			case FFun(f): f;
			case _: throw 'Not a FFun field';			
		}
	}
	
	public static function replaceFFunFunction(f:Field, func:Function)
	{
		f.kind = switch (f.kind)
		{
			case FFun(_): FFun(func);
			case _: throw 'Not a FFun field';			
		}
	}
	
	public static function setExpr(f:Field, e:Expr)
	{
		f.kind = switch (f.kind)
		{
			case FVar(t, _): FVar(t, e);
			case FProp(get, set, t, _): FProp(get, set, t, e);
			case FFun(f): 
				FFun({
					args: f.args,
					ret: f.ret,
					params: f.params,
					expr: e
				});			
		};
	}
	
	public static function makeInline(f:Field)
	{
		if (f.access == null)
			f.access = [AInline]
		else if (!f.access.has(AInline))
			f.access.push(AInline);
	}
	
	
	
}