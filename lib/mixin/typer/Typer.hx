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
using mixin.tools.MetadataTools;
using StringTools;

class Typer 
{	
	inline static var DEBUG = false;
	
	var module:String;
	var imports:StringMap<TypePath>;
	
	public function new(module:String, imports:Array<ImportExpr>)
	{
		if (DEBUG) {
			trace('--');
			trace('Typer for $module:');
		}
		
		this.module = module;			
		
		this.imports = new StringMap();		
		
		function addImport(subModule:String, ?alias:String)
		{
			var tp = parseTypePath(subModule);			
			alias = alias != null ? alias : (tp.sub != null ? tp.sub : tp.name);
			
			if (DEBUG) 
				trace('adding ${typePathToString(tp, false)} as $alias');
			
			var existed = this.imports.get(alias);
			if (existed != null && !Same.typePaths(existed, tp))					
				throw 'Typer has already mapped ${alias} to ${typePathToString(tp, false)}'; //that should not happen, but im cautious 
						
			this.imports.set(alias, { pack: tp.pack, name: tp.name, sub: tp.sub });
		}
		
		var modulePath = Path.withExtension(module.replace(".", "/"), "hx");
		var moduleDir = Path.directory(modulePath);
		
		for (cp in Context.getClassPath())
		{
			var dir = Path.join([cp, moduleDir]);

			if (FileSystem.exists(dir) && FileSystem.isDirectory(dir))
				for (entry in FileSystem.readDirectory(dir))
					if (Path.extension(entry) == "hx")
					{
						var hxPath = Path.join([moduleDir, entry]);
						var subModule = Path.withoutExtension(hxPath).replace("/", ".");
						
						addImport(subModule);
					}
		}

		for (expr in imports)
		{		
			var subModule = expr.path.map(function (p) return p.name).join(".");
			
			switch (expr.mode)
			{
				
				case INormal:					
					addImport(subModule);
					
				case IAsName(alias): 
					addImport(subModule, alias);					
					
				case IAll: throw 'Wildcard imports are not supported in mixins';
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
		makeFieldTypeDeterminable(field);
		
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
				
		//if pack has something in it then we probably do not need to resolve anything at all
		if (tp.pack.length == 0)
		{		
			//if typepath supplied as Module.Sub and Sub was directly imported
			if (tp.sub != null && imports.exists(tp.sub))
			{
				var imp = imports.get(tp.sub);
				return {
					pack: imp.pack,
					name: imp.name,
					params: tp.params,
					sub: imp.sub
				}	
			} else 
			//if typepath supplied as Module or Module.Sub and Sub was not directly imported
			if (tp.name != null && imports.exists(tp.name))
			{
				var imp = imports.get(tp.name);
				return {
					pack: imp.pack,
					name: imp.name,
					params: tp.params,
					sub: tp.sub
				}	
			} 					
		} 
		
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
	
	static function makeFieldTypeDeterminable(f:Field)
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
	
	

	
	// SOME HACKERY LEVEL SHIT RIGHT HERE
	public function resolveComplexTypesInFieldExpr(field:Field, allFields:Array<Field>)
	{
		var expr:Expr = null;		
		var pos:Position = field.pos;
		
		var typeStack = new VarStack();
		typeStack.pushLevel(VarStack.levelFromFields(allFields));
		
		switch (field.kind)
		{
			case FVar(t, e): 
				expr = e;
			case FProp(get, set, t, e):
				expr = e;
			case FFun(f):
				expr = f.expr;
				if (f.args != null)
					typeStack.pushLevel(VarStack.levelFromArgs(f.args));
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
								typeStack.pushLevel();
								for (e in es) process(e);
								typeStack.popLevel();
								
								
							case ENew(t, p):		
								e.expr = ENew(resolveTypePath(t), p);
								
								for (ex in p)
									process(ex);
								
							case EField(expr, f):			
								
								var eStr = expr.toString();
					
								if (!typeStack.hasIdentifier(eStr) && looksLikeClassOrClassSub(eStr))
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
	
	/**
	 * Checks if field satisfies interface/mixin (interf) field
	 * @param	interf mixin field
	 * @param	field to check
	 * @return 	true if satisfies
	 */
	public function satisfiesInterface(interf:Field, field:Field):Bool
	{		
		if (interf == null) throw 'Interface field should not be null';
		if (field == null) throw 'Class field should not be null';
		
		if (interf.name == field.name && 
			Same.access(interf.access, field.access, [AOverride, AInline]))
		{
			var ap = interf.pos;
			var bp = field.pos;
			Context.
			return switch ([interf.kind,field.kind])
			{
				case [FFun(af), FFun(bf)]:

			
					Same.functionArgs(af.args, bf.args, this) &&
					Same.complexTypes(af.ret, bf.ret, this) &&
					Same.typeParamDecls(af.params, bf.params);												
					
				case [FProp(ag, as, at, ae), FProp(bg, bs, bt, be)]:
					
					ag == bg &&
					as == bs &&
					Same.complexTypes(at, bt, this);
						
				case [FVar(at, ae), FVar(bt, be)]:
				
					Same.complexTypes(at, bt, this);
					
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