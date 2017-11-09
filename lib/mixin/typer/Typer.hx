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

package mixin.typer;
import haxe.ds.StringMap;
import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;
import haxe.macro.Printer;
import haxe.macro.Type.ClassType;
import mixin.io.CachedFS;
import mixin.same.Same;
import mixin.typer.resolver.Resolve;

class Typer 
{	
	inline static var DEBUG = false;
	
	var module:String;
	var lc:ClassType;
	var imports:StringMap<TypePath>;
	
	public function new(lc:ClassType, module:String, imports:Array<ImportExpr>)
	{
		if (DEBUG) {
			trace('--');
			trace('Typer for $module:');
		}
		
		this.module = module;			
		this.lc = lc;
		this.imports = new StringMap();		
		
		function addImport(subModule:String, ?alias:String)
		{
			var tp = subModule.toTypePath();
			alias = alias != null ? alias : (tp.sub != null ? tp.sub : tp.name);
			
			if (DEBUG) 
				trace('$alias => ${tp.toString(false)}');
			
			var existed = this.imports.get(alias);
			if (existed != null && !Same.typePaths(existed, tp))					
				throw 'Typer has already mapped ${alias} to ${tp.toString(false)}'; //that should not happen, but im cautious 
						
			this.imports.set(alias, { pack: tp.pack, name: tp.name, sub: tp.sub });
		}
		
		var modulePath = Path.withExtension(module.replace(".", "/"), "hx");
		var moduleDir = Path.directory(modulePath);
		
		for (cp in Context.getClassPath())
		{
			var dir = Path.join([cp, moduleDir]);

			if (CachedFS.exists(dir) && CachedFS.isDirectory(dir))
				for (entry in CachedFS.readDirectory(dir))
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
	
		Resolve.complexTypesInField(field, resolveTypePath);
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
					sub: tp.sub != null ? tp.sub : imp.sub
				}	
			} else 
			if (tp.name != null) {	
				
				/*
				 * do not resolve void, causes 
				 * Void -> A.T should be (Void) -> A.T
				 * in case of 
				 * public function hey():StdTypes.Void->T {
				 * 		return function () { return v; }
				 * }	
				 */
				
				if (!hasTypeParamNamed(tp.name) && tp.name != "Void")	
					try {
						//resolves StdTypes
						return Context.getType(tp.toString(true))
							.toComplexType()
							.extractTypePath();					
							
					} catch (any:Any) {}
			}
		} 

		return tp;
	}
	
	function hasTypeParamNamed(name:String):Bool {
		return lc.params.exists(function (tp) return tp.name == name);
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
	
	
	public function resolveComplexTypesInFieldExpr(field:Field, fields:Array<String>)
	{
		Resolve.complexTypesInFieldExpr(field, fields, resolveTypePath);
	}
	
	public function resolve(t:ComplexType):ComplexType
	{
		return Resolve.complexType(t, resolveTypePath);
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
		
		if (interf.name == field.name)			
		{
			var ikind = switch (interf.kind) {
				case FVar(t, e): FProp("default", "default", t, e);
				case _: interf.kind;
			}
			
			var fkind = switch (field.kind) {
				case FVar(t, e): FProp("default", "default", t, e);
				case _: field.kind;
			}
			
			return switch ([ikind, fkind ])
			{
				case [FFun(af), FFun(bf)]:
					
					//trace("Same function args: " + Same.functionArgs(af.args, bf.args, this));
					//trace("Same return type: " + Same.complexTypes(af.ret, bf.ret, this));
					//trace("Same type param decl: " + Same.typeParamDecls(af.params, bf.params));
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
}