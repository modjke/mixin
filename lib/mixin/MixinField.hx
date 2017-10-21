package mixin;
import haxe.macro.Context;
import haxe.macro.Expr.Access;
import haxe.macro.Expr.Field;
import haxe.macro.Expr.Position;
import mixin.Mixin.FieldMixinType;
import mixin.copy.Copy;
import mixin.typer.Typer;

using mixin.tools.MetadataTools;
using Lambda;

class MixinField 
{
	public var field(default, null):Field;
	
	public var type(default, null):FieldMixinType;
	
	public var pos(get, null):Position;
	inline function get_pos() return field.pos;
	
	public var isPublic(get, null):Bool;
	inline function get_isPublic() return hasAccess(APublic);
	
	public var isConstructor(get, null):Bool;
	inline function get_isConstructor() return field.name == "new";
	
	public var name(get, null):String;
	inline function get_name() return field.name;	

	public function new(field:Field) 
	{
		if (field == null) throw 'Supplied field is null';
		
		this.field = field;
		this.type = getFieldMixinType(field);
		
		validate();		
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
	
	function validate()
	{
		if (hasAccess(AStatic))   Context.fatalError('Mixin: static fields are not supported', pos);
		if (hasAccess(AOverride)) Context.fatalError('Mixin: override fields are not supported', pos);
		if (hasAccess(AMacro)) 	  Context.fatalError('Mixin: macro fields are not supported', pos);	
		
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
	
	public static function getFieldMixinType(f:Field):FieldMixinType
	{		
		var mixin = f.meta.hasMetaWithName("mixin");
		var base = f.meta.hasMetaWithName("base");
		var ow = f.meta.hasMetaWithName("overwrite");		
	
		return switch [mixin, base, ow]
		{
			case [false, false, false]: MIXIN;	//default
			case [true,  false, false]: MIXIN;
			case [false, true,  false]: BASE;
			case [false, false, true ]: OVERWRITE;
			case _: Context.fatalError('Multiple field mixin types are not allowed', f.pos);
		}
	}

}