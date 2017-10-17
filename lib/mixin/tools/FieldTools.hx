package mixin.tools;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;

class FieldTools 
{

	public static function isMethod(f:Field):Bool
	{
		return switch (f.kind)
		{
			case FVar(_, _): true;
			case _: false;
		}
	}
	
	public static function isPublic(f:Field):Bool
	{
		return f.access.indexOf(APublic) > -1;
	}
	
	public static function isPrivate(f:Field):Bool{
		return !isPublic(f);
	}
	
	public static function isConstructor(f:Field):Bool
	{
		// is that enough?
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
	
	
	/**
	 * Removes access, initial values, FFun exprs and 
	 * returns new valid interface field
	 * 
	 * @param	f
	 * @return
	 */
	public static function makeInterfaceField(f:Field):Field
	{
		
		var out:Field = {
			name: f.name,
			access: [],
			kind: switch (f.kind)
			{
				case FVar(t, e): FVar(t, null);
				case FFun(f): 
					FFun({
						args: f.args,
						ret: f.ret,
						params: f.params,
						expr: null
					});
				case FProp(get, set, t, e): FProp(get, set, t, null);
			},
			doc: f.doc,
			meta: f.meta,
			pos: f.pos			
		};
		
		return out;
	}
	
}