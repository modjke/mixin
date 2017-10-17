package mixin.typer;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;
import mixin.same.Same;

using haxe.macro.Tools;
using mixin.tools.MoreComplexTypeTools;
using mixin.tools.FieldTools;
using mixin.tools.MoreMacroTools;

class Typer 
{

	public static function makeFieldTypeDeterminable(f:Field)
	{
		switch (f.kind)
		{
			case FVar(t, e):
				if (t == null) {
					t = simpleTypeOf(e);						
					
					if (t != null)
						f.kind = FVar(t, e);
					else
						Context.fatalError('Mixin requires vars to be explicitly typed', f.pos);						
				}
			case FProp(get, set, t, e):
				if (t == null) {
					t = simpleTypeOf(e);						
					
					if (t != null)
						f.kind = FProp(get, set, t, e);
					else 
						Context.fatalError('Mixin requires properties to be explicitly typed', f.pos);						
				}
			case FFun(func):
				if (func.ret == null && !f.isConstructor())
				{
					Context.fatalError('Mixin requires methods to be explicitly typed', f.pos);
				}
		}
	}
	
	
	public static function resolveComplexTypesInField(field:Field)
	{
		
		var p = field.pos;
		field.kind = switch (field.kind)
		{
			case FVar(t, e): 
				FVar(t.resolve(p), e);				
			case FProp(get, set, t, e):
				FProp(get, set, t.resolve(p), e);
			case FFun(f):			
				for (a in f.args) a.type = a.type.resolve(p);
				f.ret = f.ret.resolve(p);
				FFun(f);
		}
		
	}
	
	
	public static function prepareForDisplay(f:Field)
	{		
		f.kind = switch (f.kind)
		{
			case FVar(t, _): FVar(t, null);
			case FProp(get, set, t, _): FProp(get, set, t, null);
			case FFun(f): 
				FFun({
					args: f.args,
					ret: f.ret,
					params: f.params,
					expr: macro {}
				});			
		};
	}
	
	// SOME HACKERY LEVEL SHIT RIGHT HERE
	public static function resolveComplexTypesInFieldExpr(field:Field, otherFields:Array<Field>)
	{
		var expr:Expr = null;		
		var pos:Position = field.pos;
		
		var typeStack = new TypeStack();
		typeStack.pushLevel(TypeStack.levelFromFields(otherFields));
		
		switch (field.kind)
		{
			case FVar(t, e): 
				expr = e;
			case FProp(get, set, t, e):
				expr = e;
			case FFun(f):
				expr = f.expr;
				if (f.args != null)
					typeStack.pushLevel(TypeStack.levelFromArgs(f.args));
		}
		
		if (expr != null)
		{
			function iterate(e:Expr)
			{
				try {
					var block:Bool = false;
					
					switch (e.expr)
					{
						case EBlock(_):
							block = true;
							
						case ENew(t, p):					
							
							var ct = Context.typeof(typeStack.wrap(e)).toComplexType();											
							e.expr = ENew(ct.extractTypePath(), p);
							
						case EField(e, f) if (f == "new"):							
							e.expr = Context.parse(e.resolveClassName(), pos).expr;
							// skip
							return;
							
						case EVars(vars):
							for (v in vars)
							{								
								v.type = v.type.resolve(pos);
								typeStack.addVar(v.name, v.type);
							}
							
							
						case EConst(CIdent(s)):
							if (s.isValidClassName() && !typeStack.hasIdentifier(s))
							{							
								e.expr = Context.parse(e.resolveClassName(), e.pos).expr;
							}
						case _:
							
							
					}
					
					if (block) typeStack.pushLevel();
					e.iter(iterate);
					if (block) typeStack.popLevel();
				} catch (exception:Dynamic)
				{				
					//trace(e.expr);
					//trace(expr.toString());
					Context.fatalError(Std.string(exception), e.pos);
				}
				
				
			}
			
			iterate(expr);
		}
	}
	
	/**
	 * Checks if field satisfies interface/mixin (interf) field
	 * @param	interf mixin field
	 * @param	field to check
	 * @return 	true if satisfies
	 */
	public static function satisfiesInterface(interf:Field, field:Field):Bool
	{		
		if (interf == null) throw 'Interface field should not be null';
		if (field == null) throw 'Class field should not be null';
		
		if (interf.name == field.name && 
			Same.access(interf.access, field.access, [AOverride]))
		{
			var ap = interf.pos;
			var bp = field.pos;
			return switch ([interf.kind,field.kind])
			{
				case [FFun(af), FFun(bf)]:

					Same.functionArgs(af.args, bf.args, ap, bp) &&
					Same.complexTypes(af.ret, bf.ret, ap, bp) &&
					Same.typeParamDecls(af.params, bf.params);												
					
				case [FProp(ag, as, at, ae), FProp(bg, bs, bt, be)]:
					
					ag == bg &&
					as == bs &&
					Same.complexTypes(at, bt, ap, bp);
						
				case [FVar(at, ae), FVar(bt, be)]:
				
					Same.complexTypes(at, bt, ap, bp);
					
				case _:		
					
					false;
			}			
		}
		
		return false;
	}
	
	/**
	 * This typeof is only aware of module-level imports
	 * @param	expr
	 * @return
	 */
	static function simpleTypeOf(expr:Expr):Null<ComplexType>
	{
		try {			
			return Context.typeof(expr).toComplexType();
		} catch (ignore:Dynamic) {
			return null;
		}
	}
	
	

	
}