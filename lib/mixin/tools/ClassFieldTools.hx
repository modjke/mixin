package mixin.tools;
import haxe.macro.Context;
import haxe.macro.Expr.Field;
import haxe.macro.Expr.TypeParamDecl;
import haxe.macro.Type;
import haxe.macro.Type.ClassField;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.MethodKind;
import haxe.macro.Type.TypeParameter;
import haxe.macro.Type.VarAccess;
import haxe.macro.Expr.Access;
import haxe.macro.Expr.FieldType;
import haxe.macro.TypedExprTools;

import haxe.macro.TypeTools.toComplexType;

class ClassFieldTools 
{

	public static function toField(cf:ClassField):Field
	{
		function varAccessToString(va : VarAccess, getOrSet : String) : String return {
			switch (va) {
				case AccNormal: "default";
				case AccNo: "null";
				case AccNever: "never";
				case AccResolve: throw "Invalid TAnonymous";
				case AccCall: getOrSet;
				case AccInline: "default";
				case AccRequire(_, _): "default";
				default: throw 'Not implemented for $va ($getOrSet)';
			}
		}
		
		var type = switch (cf.type)
		{
			case TLazy(f): f();
			case _: cf.type;
		}
		
		var meta = cf.meta.get();
		if (meta == null) meta = [];
		
		return {
				name: cf.name,
				doc: cf.doc,
				access: cf.isPublic ? [ APublic ] : [ APrivate ],
				kind: switch([ cf.kind, type ]) {
					case [ FVar(read, write), ret ]:
						var get = varAccessToString(read, "get");
						var set = varAccessToString(write, "set");
						
						
						FProp(get, set, toComplexType(ret), null);
							
					case [ FMethod(_), TFun(args, ret) ]:
						FFun({
							args: [
								for (a in args) {
									name: a.name,
									opt: a.opt,
									type: toComplexType(a.t),
									meta: []
								}
							],
							ret: toComplexType(ret),
							expr: null,
							params: cf.params.map(typeParameterToTypeParamDecl)
						});
						
					default:						
						trace(cf.name, cf.kind, cf.type);
						
						Context.fatalError("STAHP!", cf.pos);
						
						null;
				},
				pos: cf.pos,
				meta: meta,
		} 
	}
	
	
	static function typeParameterToTypeParamDecl(tp:TypeParameter):TypeParamDecl
	{
		var classType:ClassType;
		var params:Array<Type>;
		var contraints:Array<Type>;
		switch (tp.t)
		{
			case TInst(t, p):
				classType = t.get();
				
				switch (classType.kind)
				{
					case KTypeParameter(c):
						contraints = c;
					case _:
						throw "Invalid ClassParam kind";
				}
				params = p;
			case _: throw "Invalid TypeParameter";
		}
		
		return {
			name: tp.name,
			constraints: contraints.map(toComplexType),
			meta: [],
			params: []
		}
	}
}