package mixin.typer;
import haxe.ds.StringMap;
import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;
import haxe.macro.Printer;
import mixin.same.Same;
import sys.FileSystem;

using haxe.macro.Tools;
using mixin.tools.MoreComplexTypeTools;
using mixin.tools.FieldTools;
using StringTools;

class Typer 
{	
	var module:String;
	var imports:StringMap<{
		pack: Array<String>,
		name: String,
		?sub: String
	}>;
	
	public function new(module:String, imports:Array<ImportExpr>, pos:Position)
	{
		this.module = module;			
		
		this.imports = new StringMap();		
		
		function addImport(module:String, ?alias:String)
		{
			var tp = parseTypePath(module);
			
			//trace(alias != null ? alias : name, pack.join("."), name, sub);
			this.imports.set(alias != null ? alias : tp.name, { pack: tp.pack, name: tp.name, sub: tp.sub });
		}
		
		var modulePath = Path.withExtension(module.replace(".", "/"), "hx");
		var moduleDir = Path.directory(modulePath);
		
		for (cp in Context.getClassPath())
		{
			var dir = Path.join([cp, moduleDir]);
			for (entry in FileSystem.readDirectory(dir))
				if (Path.extension(entry) == "hx")
				{
					var hxPath = Path.join([moduleDir, entry]);
					var module = Path.withoutExtension(hxPath).replace("/", ".");
					addImport(module);
				}
		}

		for (expr in imports)
		{		
			var module = expr.path.map(function (p) return p.name).join(".");
			
			switch (expr.mode)
			{
				
				case INormal:					
					addImport(module);
					
				case IAsName(alias): 
					addImport(module, alias);					
					
				case IAll: Context.fatalError('Wildcard imports are not supported in mixins', pos);				
			}			
		}
		
		/*
		trace('Imports for $module');
		for (key in this.imports.keys())
		{
			trace('$key - ${this.imports.get(key)}');
		}
		*/
	}
	
	public function resolveComplexTypesInField(field:Field)
	{
		var p = field.pos;
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
	
	public function resolve(t:ComplexType):ComplexType
	{
		var out = mapComplexType(t, resolveTypePath);
		
		//if (t != null) trace(t.toString() + ' - ' + out.toString());
		
		return out;
	}
	
	public function resolveTypePath(tp:TypePath):TypePath{
		
		var name = tp.sub != null ? tp.sub : tp.name;
		if (tp.pack.length == 0 && imports.exists(name))
		{		
			var imp = imports.get(name);				
			return {
				pack: imp.pack,
				name: imp.name,
				params: tp.params,
				sub: imp.sub
			}				
		} else 
			return tp;
	}
	
	function mapComplexType(type:ComplexType, map:TypePath->TypePath):ComplexType
	{
		if (type == null) 
			return null;
			
		return switch (type)
		{
			case TPath( p ):
				TPath(map(p));
				
			case TFunction( args , ret  ):
				TFunction ( [ for (t in args) mapComplexType(t, map) ], mapComplexType(ret, map) );
				
			case TAnonymous( fields ):
				for (f in fields) mapComplexTypesInFeild (f, map);
				
				TAnonymous ( fields );
				
			case TParent( t  ):
				TParent(mapComplexType(t, map));
				
			case TExtend( p , fields  ):
				for (f in fields) mapComplexTypesInFeild (f, map);
				
				TExtend( [ for (t in p) map(t) ], fields ); 	
				
			case TOptional( t ):
				TOptional( mapComplexType(t, map) );
		}
	}
	
	function mapComplexTypesInFeild(f:Field, map:TypePath->TypePath)
	{
		switch (f.kind)
		{
			case FVar(t, e):
				if (t != null) f.kind = FVar(mapComplexType(t, map ), e);
			case FProp(get, set, t, e):
				if (t != null) f.kind = FProp(get, set, mapComplexType(t, map), e);
			case FFun(func):
				for (arg in func.args)
					arg.type = mapComplexType(arg.type, map);				
				func.ret = mapComplexType(func.ret, map);			
		}

	}
	
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
	public function resolveComplexTypesInFieldExpr(field:Field, otherFields:Array<Field>)
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
			function process(e:Expr)
			{
				try {
					var block:Bool = false;
					
					switch (e.expr)
					{
						case EBlock(_):
							block = true;
							
						case ENew(t, p):					
														
							e.expr = ENew(resolveTypePath(t), p);
							
							for (e in p)
								process(e);
							
						case EField(expr, f):			
							
							var eStr = expr.toString();
							
							if (!typeStack.hasIdentifier(eStr) && looksLikeClassOrClassSub(eStr))
							{
								var tp = parseTypePath(eStr);
								tp = resolveTypePath(tp);
								
								var newExpr = Context.parse(typePathToString(tp, false), e.pos);
								e.expr = EField(newExpr, f);								
							}
							
							
						case EVars(vars):
							for (v in vars)
							{								
								v.type = resolve(v.type);
								typeStack.addVar(v.name, v.type);
								
								process(v.expr);
							}
							
							
						case EConst(CIdent(s)):
							if (!typeStack.hasIdentifier(s) && looksLikeClassOrClassSub(s))
							{
								var tp = parseTypePath(s);
								tp = resolveTypePath(tp);
								
								e.expr = Context.parse(typePathToString(tp, false), e.pos).expr;								
							}
						case _:
							
						if (block) typeStack.pushLevel();
						e.iter(process);
						if (block) typeStack.popLevel();		
					}
					
					
				} catch (exception:Dynamic)
				{				
				
					trace('Exception while parsing expression: ' + expr.toString());
					
					Context.fatalError("Exception while resolving types: " + Std.string(exception), e.pos);
				}
				
				
			}
			
			process(expr);
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

					Same.functionArgs(af.args, bf.args) &&
					Same.complexTypes(af.ret, bf.ret) &&
					Same.typeParamDecls(af.params, bf.params);												
					
				case [FProp(ag, as, at, ae), FProp(bg, bs, bt, be)]:
					
					ag == bg &&
					as == bs &&
					Same.complexTypes(at, bt);
						
				case [FVar(at, ae), FVar(bt, be)]:
				
					Same.complexTypes(at, bt);
					
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
	
	
	static function isValidClassName(s:String):Bool
	{
		return ~/\b[A-Z][_,A-Z,a-z,0-9]*/.match(s);
	}
	

	static function parseTypePath(s:String):TypePath
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
	
	static function typePathToString(tp:TypePath, includeTypeParams:Bool)
	{
		var str = tp.pack.join(".") + "." + tp.name;
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