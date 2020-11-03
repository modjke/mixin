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

package mixin;
import haxe.ds.StringMap;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.Access;
import haxe.macro.Expr.Field;
import haxe.macro.Expr.Position;
import mixin.MixinMeta.FieldMixinType;
import mixin.MixinMeta.MixinFieldMeta;
import mixin.copy.Copy;
import mixin.typer.Typer;
import haxe.macro.Type;
import mixin.typer.resolver.Resolve;

class MixinField 
{
	var field:Field;
	public var meta(default, null):MixinFieldMeta;
	
	public var type(get, null):FieldMixinType;
	function get_type() return meta.type;
	
	public var pos(get, null):Position;
	inline function get_pos() return field.pos;
	
	public var isMethod(get, null):Bool;
	inline function get_isMethod() 
		return switch (field.kind)
		{
			case FFun(_): true;
			case _: false;
		};
	
	public var isPublic(get, null):Bool;
	inline function get_isPublic() return hasAccess(APublic);
	
	public var isConstructor(get, null):Bool;
	inline function get_isConstructor() return field.name == "new";
	
	public var name(get, null):String;
	inline function get_name() return field.name;	
		
	//only methods and constructors has implementation
	public var implementation(get, null):Null<Expr>;
	inline function get_implementation()
		return switch (field.kind)
		{
			case FFun(f): f.expr;
			case _: null;
		}
	
	public var baseFieldName(default, null):Null<String>;
		
	public var mixin(default, null):Mixin;
	
	public function new(mixin:Mixin, field:Field) 
	{
		if (mixin == null || field == null) throw "Invalid arguments";
		
		this.mixin = mixin;
		this.field = field;		
		this.meta = MixinMeta.consumeMixinFieldMeta(field);		

		this.baseFieldName = switch (type) {
			case OVERWRITE: '_' + mixin.fql.replace(".", "_").toLowerCase() + '_${field.name}';
			case BASE: field.name;
			case MIXIN: null;
		};
		
		if (hasAccess(AStatic))   Context.fatalError('Mixin: static fields are not supported', pos);
		if (hasAccess(AOverride)) Context.fatalError('Mixin: override fields are not supported', pos);
		if (hasAccess(AMacro)) 	  Context.fatalError('Mixin: macro fields are not supported', pos);	
		
	}
	
	/**
	 * Creates field for including into base class
	 * @param	params
	 * @return
	 */
	public function create(params:Array<Type>, forDisplay:Bool):Field
	{
		var copy = Copy.field(field);
		
		if (params.length > 0) {
			if (params.length != mixin.typeParams.length)
				throw "Known typeParams length is different from supplied";
					
			var typeMap:StringMap<ComplexType> = new StringMap();
			for (i in 0...params.length) {

				var complex = Context.toComplexType(params[i]);
				typeMap.set(mixin.typeParams[i], complex);
			}
			
			//for (k in typeMap.keys()) trace(k + ' -> ' + typeMap.get(k).safeToString());
				
			function resolve(tp:TypePath):ComplexType
			{				
				var type = tp.toString(true);
				var mapped = typeMap.get(type);
				return mapped;
			}
			
			Resolve.typeParamsInField(copy, resolve);						
			if (!forDisplay) 
			{
				var names = mixin.fields.map(function (f) return f.name);
				Resolve.typeParamsInFieldExpr(copy, resolve);
			}
		}
		return copy;
	}
	
	public function convertForDisplay()
	{
		field.kind = switch (field.kind)
		{
			case FVar(t, _): 
				FVar(t, null);
			case FProp(get, set, t, _): 
				FProp(get, set, t, null);
			case FFun(f): 
				FFun({
					args: f.args,
					ret: f.ret,
					params: f.params,
					expr: macro {}
				});			
		};	
	}
	
	
	
	public function validateMixinType()
	{
		switch (type)
		{	
			case MIXIN: makeSureFieldCanBeMixin();
			case BASE: makeSureFieldCanBeBase();	
			case OVERWRITE:	makeSureFieldCanBeOverwrite();			
		}
	}
	
	public function createInterface():Field
	{
		return {
			name: field.name,
			access: [],
			kind: switch (field.kind)
			{
				case FVar(t, e): 
					FVar(Copy.complexType(t), null);
				case FFun(f): 
					FFun({
						args: Copy.arrayOfFunctionArg(f.args),
						ret: Copy.complexType(f.ret),
						params: Copy.arrayOfTypeParamDecl(f.params),
						expr: null
					});
				case FProp(get, set, t, e):
					FProp(get, set, Copy.complexType(t), null);
			},
			doc: field.doc,
			meta: Copy.metadata(field.meta),
			pos: field.pos			
		};
	}
	
	public function createEmptyBaseMethod(generateSuperCall:Bool):Field
	{
		
		var expr:Expr = {
			expr: generateSuperCall ? ECall((macro super.$name).setPos(pos), [for (arg in getArgs()) (macro $i{arg.name}).setPos(pos)]) : EConst(CIdent("null")),
			pos: pos
		};

		var returnExpr = {
			expr: EReturn(isVoidMethod() ? null : expr),
			pos: pos
		}
			
		return {
			name: baseFieldName,
			access: field.access.copy(),
			kind: switch (field.kind)
			{
				case FFun(f): 
					FFun({
						args: Copy.arrayOfFunctionArg(f.args),
						ret: Copy.complexType(f.ret),
						params: Copy.arrayOfTypeParamDecl(f.params),
						expr: returnExpr
					});
				case _: throw "Only FFun is supported";
			},
			doc: field.doc,
			meta: Copy.metadata(field.meta),
			pos: field.pos			
		};
		
		
	}
	function getArgs():Array<FunctionArg> 
	{
		return switch (field.kind)
		{
			case FFun(f): Copy.arrayOfFunctionArg(f.args);
			case _: throw "Not a FFun";
		}
	}

	function isVoidMethod() {
		return switch (field.kind)
		{
			case FFun(_.ret => TPath({ name: 'Void', params: [], sub: null })): 
				true;
			case FFun(t): 
				false;
			case _: throw "Not a FFun";
		}
	}
	
	function hasAccess(a:Access) return field.access != null ? field.access.has(a) : false;
	
	function makeSureFieldCanBeBase()
	{
		if (isConstructor) 
			Context.fatalError('Mixin only allowed to have @overwrite constructor', pos);
		
		switch (field.kind)
		{
			case FVar(t, e):
				if (e != null)
					Context.fatalError('@base var can\'t have initializer', pos);
			case FProp(get, set, t, e):
				if (e != null)
					Context.fatalError('@base property can\'t have initializer', pos);
			case FFun(func):
				if (func.expr != null) 
					Context.fatalError('@base method can\'t have implementation', pos);
		}
	}
	
	function makeSureFieldCanBeMixin()
	{
		if (isConstructor)
			Context.fatalError('Mixin only allowed to have @overwrite constructor', pos);
			
		switch (field.kind)
		{
			case FVar(t, e):
			case FProp(get, set, t, e):				
			case FFun(func):
				if (func.expr == null) 
					Context.fatalError('@mixin method should have implementation (body)', pos);
		}
	}
	
	function makeSureFieldCanBeOverwrite()
	{
		switch (field.kind)
		{
			case FVar(t, e):				
				Context.fatalError('var can\'t be overwritten, makes no sense', pos);
			case FProp(get, set, t, e):				
				Context.fatalError('property can\'t be overwritten, but it\'s getter/setter can be', pos);
			case FFun(func):
				if (func.expr == null) 
					Context.fatalError('@overwrite method should have implementation (body)', pos);
		}
	}
}