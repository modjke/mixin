package mixin.typer.resolver;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.ComplexType;
import haxe.macro.Expr.Field;
import haxe.macro.Expr.TypePath;

using haxe.macro.Tools;


class Resolve 
{

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
				f.ret = resolve(f.ret);
				FFun(f);
		}		
	}
	
	// SOME HACKERY LEVEL SHIT RIGHT HERE
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
									var tp = parseTypePath(eStr);
									tp = resolveTypePath(tp);
									
									var newExpr = Context.parse(typePathToString(tp, false), e.pos);
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
								
								
							case EConst(CIdent(s)):
								
								if (!varStack.hasVarNamed(s) && looksLikeClassOrClassSub(s))
								{
									var tp = parseTypePath(s);
									tp = resolveTypePath(tp);
									
									e.expr = Context.parse(typePathToString(tp, false), e.pos).expr;								
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
				
				TExtend( [ for (t in p) map(t) ], fields ); 	
				
			case TOptional( t ):
				TOptional( complexType(t, map) );
		}
	}
	

	
	public static function parseTypePath(s:String):TypePath
	{
		var pack = s.split(".");
		var hasSub = pack.length > 1 && ~/\b[A-Z]/.match(pack[pack.length - 2]);
		var sub = hasSub ? pack.pop() : null;
		var name = pack.pop();
		if (name.indexOf("<") != -1) throw "Parsing type path with type parameters is not implemented";
		
		return {
			pack: pack,
			sub: sub,
			name: name
		}
	}
	
	public static function typePathToString(tp:TypePath, includeTypeParams:Bool)
	{
		var str = tp.pack.join(".") + (tp.pack.length > 0 ? "." + tp.name : tp.name);
		if (tp.sub != null) str += "." + tp.sub;
		if (includeTypeParams && tp.params != null && tp.params.length > 0)
		{
			str += "<" + tp.params.map(typeParamToString).join(",") + ">";
		}
		
		return str;
	}	
	
	static function typeParamToString(tp:TypeParam)
	{
		return switch(tp) {
			case TPType(ct): ct.toString();
			case TPExpr(e): e.toString();
		}
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