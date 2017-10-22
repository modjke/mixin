package mixin;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.Access;
import haxe.macro.Expr.Field;
import haxe.macro.Expr.Position;
import mixin.Mixin.FieldMixinType;
import mixin.copy.Copy;
import mixin.typer.Typer;

using mixin.tools.MetadataTools;
using mixin.tools.MoreExprTools;
using StringTools;
using Lambda;

class MixinField 
{
	var field:Field;
	
	public var type(default, null):FieldMixinType;
	
	public var pos(get, null):Position;
	inline function get_pos() return field.pos;
	
	public var debug(get, null):Bool;
	inline function get_debug() return field.meta.hasMetaWithName("debug");
	
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
	
	public var inlineBase(default, null):Bool = false;
	
	//only methods and constructors has implementation
	public var implementation(get, null):Null<Expr>;
	inline function get_implementation()
		return switch (field.kind)
		{
			case FFun(f): f.expr;
			case _: null;
		}
	
	public var baseFieldName(default, null):Null<String>;
	
	public var mixinFql(default, null):String;
	
	public function new(mixinFql:String, field:Field) 
	{
		if (field == null) throw 'Supplied field is null';
		
		this.mixinFql = mixinFql;
		this.field = field;
		this.type = processFieldMeta();	
		
		this.baseFieldName = switch (type) {
			case OVERWRITE: '_' + mixinFql.replace(".", "_").toLowerCase() + '_${field.name}';
			case BASE: field.name;
			case MIXIN: null;
		};
		
		if (hasAccess(AStatic))   Context.fatalError('Mixin: static fields are not supported', pos);
		if (hasAccess(AOverride)) Context.fatalError('Mixin: override fields are not supported', pos);
		if (hasAccess(AMacro)) 	  Context.fatalError('Mixin: macro fields are not supported', pos);	
		
	}
	
	public function mixin():Field
	{
		return Copy.field(field);
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
	
	function processFieldMeta():FieldMixinType
	{		
		var f = this.field;
		
		var mixin = f.meta.hasMetaWithName("mixin");
		var base = f.meta.hasMetaWithName("base");
		var ow = f.meta.hasMetaWithName("overwrite");		
	
		return switch [mixin, base, ow]
		{
			case [false, false, false]: MIXIN;	//default
			case [true,  false, false]: MIXIN;
			case [false, true,  false]: BASE;
			case [false, false, true ]: 
				f.meta.getMetaWithName("overwrite").cosumeParameters(function (p)
				{
					return switch (p.expr)
					{
						case EBinop(OpAssign, macro inlineBase, _.getBoolValue() => value):
							if (value != null)
								this.inlineBase = value;
							else 
								Context.fatalError('Invalid value for inlineBase', p.pos);
							
							true;
						case _:
							false;
					}
				});
				
				OVERWRITE;
			case _: Context.fatalError('Multiple field mixin types are not allowed', f.pos);
		}
	}

}