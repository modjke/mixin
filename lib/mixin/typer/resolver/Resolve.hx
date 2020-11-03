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

package mixin.typer.resolver;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.ComplexType;
import haxe.macro.Expr.Field;
import haxe.macro.Expr.TypePath;
import mixin.same.Same;

class Resolve 
{
	public static function typeParamsInField(field:Field, resolve:TypePath->ComplexType)
	{
		field.kind = switch (field.kind)
		{
			case FVar(t, e): 
				FVar(typeParam(t, resolve), e);				
			case FProp(get, set, t, e):
				FProp(get, set, typeParam(t, resolve), e);
			case FFun(f):			
				var localTypeParams = collectTypeParams(f);
				if (localTypeParams.length > 0)
				{
					if (f.params != null)
						for (p in f.params)
							if (p.constraints != null)
								for (i in 0...p.constraints.length)
									p.constraints[i] = typeParam(p.constraints[i], resolve);
						
					inline function isLocal(tp:TypePath):Bool {
						return localTypeParams.exists(function (itp) return Same.typePaths(tp, itp));
					}
					
					function resolveIfNotLocal(tp:TypePath):ComplexType {
						return !isLocal(tp) ? resolve(tp) : null;
					}
					
					resolve = resolveIfNotLocal;
					
				}
				
				for (a in f.args) a.type = typeParam(a.type, resolve);
				f.ret = typeParam(f.ret, resolve);
				FFun(f);
		}
	}
	
	static function typeParam(type:ComplexType, resolve:TypePath->ComplexType)
	{
		if (type == null) 
			return null;
			

		var resolved = switch (type)
		{
			case TPath( p ): 
				typeParamInTypeParams(p.params, resolve);
				
				resolve(p);
				
			case TFunction( args , ret  ):
				TFunction ( [ for (t in args) typeParam(t, resolve) ], typeParam(ret, resolve) );
				
			case TAnonymous( fields ):
				for (f in fields) typeParamsInField (f, resolve);
				
				TAnonymous ( fields );
				
			case TParent( t ):
				TParent(typeParam(t, resolve));
				
			case TExtend( p , fields  ):
				for (f in fields) typeParamsInField (f, resolve);
				for (t in p) typeParamInTypeParams(t.params, resolve);
				
				TExtend( p, fields ); 	
				
			case TOptional( t ):
				TOptional( typeParam(t, resolve) );

			case TNamed(n, t):
				TNamed(n, t);
				
			case TIntersection( tl ):
				TIntersection(tl);
				
		}
		
		return resolved != null ? resolved : type;
	}
	
	static function typeParamInTypeParams(params:Array<TypeParam>, resolve:TypePath->ComplexType)
	{
		if (params != null)		
			for (i in 0...params.length) {				
				switch (params[i])
				{
					case TPType(t): params[i] = TPType(typeParam(t, resolve));
					case _: // 
				}
			};		
		
	}

	public static function typeParamsInFieldExpr(field:Field, resolveTypeParam:TypePath->ComplexType)
	{		
		var pos:Position = field.pos;	
		var expr = switch (field.kind)
		{
			case FVar(t, e): e;
			case FProp(get, set, t, e): e;				
			case FFun(f): 
				var localTypeParams = collectTypeParams(f);
				if (localTypeParams.length > 0)
				{	
					inline function isLocal(tp:TypePath):Bool {
						return localTypeParams.exists(function (itp) return Same.typePaths(tp, itp));
					}
					
					function resolveIfNotLocal(tp:TypePath):ComplexType {
						return !isLocal(tp) ? resolveTypeParam(tp) : null;
					}
					
					resolveTypeParam = resolveIfNotLocal;
				}
				
				f.expr;				
		}
		
		if (expr != null)
		{			
			function process(e:Expr)
			{
				try {			
					if (e != null)
						switch (e.expr)
						{
							case EVars(vars):
								for (v in vars)
								{								
									v.type = typeParam(v.type, resolveTypeParam);
									
									process(v.expr);
								}

							case EFunction(name, f):
								for (a in f.args) {
									a.type = typeParam(a.type, resolveTypeParam);
									process(a.value);
								}
								
								f.ret = typeParam(f.ret, resolveTypeParam);
								process(f.expr);
							
							case ETry(e, catches):
								process(e);
								for (c in catches)
									c.type = typeParam(c.type, resolveTypeParam);
							
							case ECast( _e, t ):
								process(_e);
								e.expr = ECast(_e, typeParam(t, resolveTypeParam));
							
							case ECheckType ( _e, t ):
								process(_e);
								e.expr = ECheckType(_e, typeParam(t, resolveTypeParam));
								
							case _:
								e.iter(process);
						
						}
					
					
				} catch (exception:Dynamic)
				{				
					trace(e);
					
					Context.fatalError("Exception while resolving types: " + Std.string(exception), e.pos);
				}
				
				
			}
			
			process(expr);
			
		}
	}
	
	public static function complexTypesInField(field:Field, resolveTypePath:TypePath->TypePath)
	{		
		inline function resolve(t:ComplexType):ComplexType return complexType(t, resolveTypePath);
		
		field.kind = switch (field.kind)
		{
			case FVar(t, e): 
				FVar(resolve(t), e);				
			case FProp(get, set, t, e):
				FProp(get, set, resolve(t), e);
			case FFun(f):			
				for (a in f.args) a.type = resolve(a.type);
				if (f.params != null)
					for (p in f.params)
						if (p.constraints != null)
							for (i in 0...p.constraints.length)
								p.constraints[i] = resolve(p.constraints[i]);
								
				f.ret = resolve(f.ret);
				FFun(f);
		}		
	}
	
	// TODO: does not look robust
	public static function complexTypesInFieldExpr(field:Field, fields:Array<String>, resolveTypePath:TypePath->TypePath)
	{
		var expr:Expr = null;		
		var pos:Position = field.pos;
		
		var varStack = new VarStack();
		varStack.pushLevel(fields);
		
		switch (field.kind)
		{
			case FVar(t, e): 
				expr = e;
			case FProp(get, set, t, e):
				expr = e;
			case FFun(f):
				expr = f.expr;
				if (f.args != null)
					varStack.pushLevel(VarStack.levelFromArgs(f.args));
		}
		
		if (expr != null)
		{			
			function process(e:Expr)
			{
				try {			
					if (e != null)
						switch (e.expr)
						{
							case EBlock(es):
								varStack.pushLevel();
								for (e in es) process(e);
								varStack.popLevel();
		
							case ESwitch(e, cases, edef):
								process(e);
								for (c in cases)
								{
									varStack.pushLevel();
									for (v in c.values) process(v);
									process(c.guard);
									process(c.expr);									
									varStack.popLevel();
								}
							case ENew(t, p):		
								e.expr = ENew(resolveTypePath(t), p);
								
								for (ex in p)
									process(ex);
								
							case EField(expr, f):			
								
								var eStr = expr.toString();
					
								if (!varStack.hasVarNamed(eStr) && looksLikeClassOrClassSub(eStr))
								{
									var tp = eStr.toTypePath();
									tp = resolveTypePath(tp);
									
									var newExpr = Context.parse(tp.toString(false), e.pos);
									e.expr = EField(newExpr, f);								
								} else 
									process(expr);
								
								
							case EVars(vars):
								for (v in vars)
								{								
									v.type = complexType(v.type, resolveTypePath);
									varStack.addVar(v.name);
									
									process(v.expr);
								}
							
							case EFunction(name, f):
								for (a in f.args) {
									a.type = complexType(a.type, resolveTypePath);
									process(a.value);
								}
								
								f.ret = complexType(f.ret, resolveTypePath);
								process(f.expr);
							
							case ETry(e, catches):
								process(e);
								for (c in catches)
									c.type = complexType(c.type, resolveTypePath);
							
							case ECast( _e, t ):
								process(_e);
								e.expr = ECast(_e, complexType(t, resolveTypePath));
							
							case ECheckType ( _e, t ):
								process(_e);
								e.expr = ECheckType(_e, complexType(t, resolveTypePath));
							
								
							case EConst(CIdent(s)):
								
								if (!varStack.hasVarNamed(s) && looksLikeClassOrClassSub(s))
								{
									var tp = s.toTypePath();
									tp = resolveTypePath(tp);
									
									e.expr = Context.parse(tp.toString(false), e.pos).expr;								
								} 
							
							
							case _:
								e.iter(process);
						
						}
					
					
				} catch (exception:Dynamic)
				{				
					trace(e);
					
					Context.fatalError("Exception while resolving types: " + Std.string(exception), e.pos);
				}
				
				
			}
			
			process(expr);
			
		}
	}
	
	
	
	
	public static function complexType(type:ComplexType, map:TypePath->TypePath):ComplexType
	{
		if (type == null) 
			return null;
			
		return switch (type)
		{
			case TPath( p ):	
				complexTypeInTypeParams(p.params, map);
				TPath(map(p));
				
			case TFunction( args , ret  ):
				TFunction ( [ for (t in args) complexType(t, map) ], complexType(ret, map) );
				
			case TAnonymous( fields ):
				for (f in fields) complexTypesInField (f, map);
				
				TAnonymous ( fields );
				
			case TParent( t  ):
				TParent(complexType(t, map));
				
			case TExtend( p , fields  ):
				for (f in fields) complexTypesInField (f, map);
				for (t in p) complexTypeInTypeParams(t.params, map);
				
				TExtend( [ for (t in p) map(t) ], fields ); 	
				
			case TOptional( t ):
				TOptional( complexType(t, map) );

			case TNamed(n, t):
				TNamed(n, t);
				
			case TIntersection( tl ):
				TIntersection(tl);
		}
	}
	
	static function complexTypeInTypeParams(params:Array<TypeParam>, resolve:TypePath->TypePath)
	{
		if (params != null)		
			for (i in 0...params.length) {				
				switch (params[i])
				{
					case TPType(t): params[i] = TPType(complexType(t, resolve));
					case _: // 
				}
			};		
		
	}

	static function collectTypeParams(f:Function):Array<TypePath>
	{
		var out:Array<TypePath> = [];
		
		if (f.params != null)
			for (p in f.params) {
				out.push(p.name.toTypePath());
				
				if (p.params != null && p.params.length > 0)
					throw 'TypeParamDecl with params not supported';
			}
		
		return out;
	}
	
	
	
	// true if string looks like Class and Class.Sub
	// false if it is package.sub.Class or smth else
	static function looksLikeClassOrClassSub(s:String):Bool
	{
		
		var parts = s.split(".");
		var re = ~/^[A-Z][_,A-Z,a-z,0-9]*/;
		
		if (parts.length <= 2)
		{
			for (p in parts)
				if (!re.match(p)) 
					return false;
				
			return true;
		} else 
			return false;
	}
}