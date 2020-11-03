/*
Copyright (c) 2020 Ignatiev Mikhail (https://github.com/modjke) <ignatiev.work@gmail.com>

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

package mixin.copy;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;
import haxe.macro.Expr.FieldType;
import haxe.macro.Expr.Metadata;
import haxe.macro.Expr.MetadataEntry;
import haxe.macro.Expr.Position;
import haxe.macro.ExprTools.ExprArrayTools;
import haxe.macro.Type.FieldKind;

class Copy 
{

	public static function field(f:Field):Field
	{
		if (f == null) return null;
		
		return {
			name: f.name,
			doc: f.doc,
			access: f.access.copy(),
			kind: Copy.fieldKind(f.kind),
			pos: f.pos,
			meta: Copy.metadata(f.meta)
		};
	}
	
	public static function fieldKind(k:FieldType):FieldType
	{
		if (k == null) return null;
		
		return switch (k)
		{
			case FVar(t, e): 
				FVar(Copy.complexType(t), Copy.expr(e));				
			case FProp(get, set, t, e):
				FProp(get, set, Copy.complexType(t), Copy.expr(e));				
			case FFun(f):
				FFun(Copy.func(f));
		}
	}
	
	public static function complexType(t:ComplexType):ComplexType
	{
		if (t == null) return null;
		
		return switch (t)
		{
			case TPath( p ): 
				TPath(Copy.typePath(p));
			case TFunction( args, ret ): 
				TFunction(Copy.arrayOfComplexType(args), Copy.complexType(ret));
			case TAnonymous( fields ): 
				TAnonymous(Copy.arrayOfField(fields));
			case TParent (t): 
				TParent(Copy.complexType(t));
			case TExtend (p, fields): 
				TExtend(Copy.arrayOfTypePath(p), Copy.arrayOfField(fields));
			case TOptional (t): 
				TOptional(Copy.complexType(t));
			case TNamed(n, t):
				TNamed(n, Copy.complexType(t));	
			case TIntersection( tl ):
				TIntersection(Copy.arrayOfComplexType(tl));
		}
	}
	
	public static function metadata(m:Metadata):Metadata
	{
		if (m == null) return null;
		
		return m.map(Copy.metadataEntry);
	}
	
	public static function metadataEntry(m:MetadataEntry):MetadataEntry
	{
		if (m == null) return null;
		
		return {
			name: m.name,
			params: Copy.arrayOfExpr(m.params),
			pos: m.pos
		}
	}
	
	public static function arrayOfExpr(exprs:Array<Expr>):Array<Expr>
	{
		if (exprs == null) return null;
		
		return exprs.map(Copy.expr);
	}
	
	public static function expr(e:Expr):Expr
	{
		if (e == null) return null;
			
		return { pos: e.pos, expr: switch(e.expr)
			{
				case ENew(tp, params): 
					ENew(Copy.typePath(tp), Copy.arrayOfExpr(params));
				case EVars(vars):
					EVars(Copy.arrayOfVar(vars));
				case EFunction(n, fun):
					EFunction(n, Copy.func(fun));
				case ESwitch(e, cases, edef):
					ESwitch(Copy.expr(e), Copy.arrayOfCase(cases), Copy.expr(edef));
				case ETry( e, catches):
					ETry(Copy.expr(e), Copy.arrayOfCatch(catches));
				case ECast( e, t ):
					ECast(Copy.expr(e), Copy.complexType(t));
				case EDisplayNew(t):
					EDisplayNew(Copy.typePath(t));
				case ECheckType( e,t ):
					ECheckType(Copy.expr(e), Copy.complexType(t));
				case EMeta( s, e ):
					EMeta(Copy.metadataEntry(s), Copy.expr(e));
				case _: 
					var e = e.map(expr);
					e != null ? e.expr : null;
			}
		}
	}
	
	public static function typePath(e:TypePath):TypePath
	{
		if (e == null) return null;
		return {
			name: e.name,
			sub: e.sub,
			params: Copy.arrayOfTypeParam(e.params),
			pack: Copy.arrayOfString(e.pack)
		}
	}
	
	public static function arrayOfTypeParam(p:Array<TypeParam>):Array<TypeParam>
	{
		return array(p, Copy.typeParam);
	}
	
	public static function arrayOfString(a:Array<String>):Array<String>
	{
		if (a == null) return null;
		return a.copy();
	}
	
	public static function arrayOfComplexType(a:Array<ComplexType>):Array<ComplexType>
	{		
		return array(a, Copy.complexType);
	}
	
	public static function arrayOfField(a:Array<Field>):Array<Field>
	{		
		return array(a, Copy.field);
	}
	
	public static function arrayOfVar(a:Array<Var>):Array<Var>
	{
		return array(a, var_);
	}
	
	public static function arrayOfFunctionArg(a:Array<FunctionArg>):Array<FunctionArg>
	{
		return array(a, Copy.functionArg);
	}
	public static function arrayOfTypePath(a:Array<TypePath>):Array<TypePath>
	{
		return array(a, Copy.typePath);
	}
	
	public static function arrayOfCatch(a:Array<Catch>):Array<Catch>
	{
		return array(a, Copy.catch_);
	}
	
	public static function catch_(c:Catch):Catch
	{
		if (c == null) return null;
		return {
			expr: Copy.expr(c.expr),
			name: c.name,
			type: Copy.complexType(c.type)
		}
	}
	
	
	public static function arrayOfCase(a:Array<Case>):Array<Case>
	{
		return array(a, Copy.case_);
	}
	
	public static function case_(c:Case):Case
	{
		if (c == null) return null;
		
		return {
			expr: Copy.expr(c.expr),
			guard: Copy.expr(c.guard),
			values: Copy.arrayOfExpr(c.values)
		}
	}
	
	public static function func(f:Function):Function
	{
		if (f == null) return null;
		
		return {
			args: Copy.arrayOfFunctionArg(f.args),
			ret: Copy.complexType(f.ret),
			expr: Copy.expr(f.expr),
			params: Copy.arrayOfTypeParamDecl(f.params)
		}
	}
	
	public static function arrayOfTypeParamDecl(a:Array<TypeParamDecl>):Array<TypeParamDecl>
	{
		return array(a, Copy.typeParamDecl);
	}
	
	public static function typeParamDecl(t:TypeParamDecl):TypeParamDecl
	{
		if (t == null) return null;
		return {
			constraints: Copy.arrayOfComplexType(t.constraints),
			meta: Copy.metadata(t.meta),
			name: t.name,
			params: Copy.arrayOfTypeParamDecl(t.params)
		}
	}
	
	public static function functionArg(a:FunctionArg):FunctionArg
	{
		if (a == null) return null;
		
		return {
			meta: Copy.metadata(a.meta),
			name: a.name,
			opt: a.opt,
			type: Copy.complexType(a.type),
			value: Copy.expr(a.value)
		}
	}
	
	public static function var_(v:Var):Var
	{
		return {
			name: v.name,
			expr: Copy.expr(v.expr),
			type: Copy.complexType(v.type)
		}
	}
	
	static function array<T>(a:Array<T>, mapper:T->T):Array<T>
	{
		if (a == null) return null;
		return a.map(mapper);
	}
	
	public static function typeParam(p:TypeParam):TypeParam
	{
		if (p == null) return null;
		return switch (p)
		{
			case TPType(t): TPType(Copy.complexType(t));
			case TPExpr(e): TPExpr(Copy.expr(e));
		}
	}
}