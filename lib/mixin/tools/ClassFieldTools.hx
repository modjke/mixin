/*
Copyright (c) 2017 Ignatiev Mikhail (https://github.com/modjke) <ignatiev.work@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
package mixin.tools;

import haxe.macro.Context;
import haxe.macro.Expr.Field;
import haxe.macro.Expr.Function;
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
						
						var typedExpr = cf.expr();
						var expr = typedExpr != null ? Context.getTypedExpr(typedExpr) : null;
						FProp(get, set, toComplexType(ret), expr);
							
					case [ FMethod(_), TFun(args, ret) ]:
						
						// extract Expr.Function
						var f = switch (Context.getTypedExpr(cf.expr()).expr)
						{
							case EFunction(_, f): f;
							case _: throw "Invalid function expression";
						}
						
						FFun({
							args: f.args,
							ret: f.ret,
							expr: f.expr,
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
	
	
	static function varAccessToString(va : VarAccess, getOrSet : String) : String 
		return {
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