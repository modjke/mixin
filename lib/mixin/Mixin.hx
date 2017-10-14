package mixin;
import haxe.ds.StringMap;
import haxe.io.Output;
import haxe.macro.ComplexTypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type.ClassField;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.VarAccess;

import haxe.macro.TypeTools.*;
using haxe.macro.Tools;

using haxe.EnumTools;
using StringTools;
using Lambda;

enum FieldMixinType
{
	MIXIN;
	BASE;
	OVERWRITE;
}

class Mixin 
{
	static var mixins:StringMap<Array<Field>> = new StringMap();
	
	public static function sugar():Array<Field>
	{
		var lcRef = Context.getLocalClass();
		var lc = lcRef != null ? lcRef.get() : null;		
		var isMixin = lc != null && lc.meta.has("mixin");
		
		return isMixin ? createMixin() : Context.getBuildFields();
	}
	
	/**
	 * Creates mixin from interface
	 * @return
	 */
	@:noCompletion
	public static function createMixin():Array<Field>
	{	
		
		var lc = Context.getLocalClass().get();				
		
		if (!lc.isInterface)
			Context.fatalError('Mixin should be declared as interface', lc.pos);
		
		lc.meta.add(":autoBuild", [macro mixin.Mixin.includeMixin()], lc.pos);
		
		if (!lc.meta.has("mixin")) lc.meta.add("mixin", [], lc.pos);
				
		var interfaceFields:Array<Field> = [];
		var mixinFields:Array<Field> = [];
		
		var buildFields = Context.getBuildFields();
		
		for (field in buildFields)
		{				
			var isConstructor = field.name == "new";
			if (isConstructor) continue;	//implement constructor handling later
			
			var isPublic = field.access.has(APublic);
			switch (getFieldMixinType(field))
			{	
				case MIXIN:
					makeSureFieldCanBeMixin(field, buildFields);
				case BASE:
					makeSureFieldCanBeBase(field);
				case OVERWRITE:	
					makeSureFieldCanBeOverwrite(field);
				
			}
			
			mixinFields.push(field);			
			if (isPublic)
				interfaceFields.push(makeInterfaceField(field));
		}
		
		var fqlName = getFqlClassName(lc);
		if (!mixins.exists(fqlName))
			mixins.set(fqlName, mixinFields);		
		else
			throw 'Mixin for ${fqlName} is already existed...';
		
		return interfaceFields;
	}
	
	

	/**
	 * Includes mixin into base class
	 * @return
	 */
	@:noCompletion
	public static function includeMixin():Array<Field>
	{
		var lc = Context.getLocalClass().get();
		var fields = Context.getBuildFields();
		
		for (iface in lc.interfaces)
		{
			var ifaceClass = iface.t.get();
			if (ifaceClass.meta.has("mixin"))
			{				
				var classFql = getFqlClassName(lc);				
				var mixinFql = getFqlClassName(ifaceClass);

				for (mf in mixins.get(mixinFql))
				{
					//mf - mixin field
					//cf - existing class field (can be null)
					var cf = fields.find(function (f) return f.name == mf.name);
					
					switch (getFieldMixinType(mf))
					{
						case MIXIN:
							if (cf == null)
								fields.push(mf);
							else 
								Context.fatalError('@mixin field <${mf.name}> overlaps base field with the same name in ${classFql}', cf.pos);
						case BASE:
							if (cf != null)
							{
								if (!satisfiesInterface(mf, cf))
								{
									Context.warning('@base field for <${cf.name}> defined here', mf.pos);
									Context.fatalError('Field <${cf.name}> does not satisfy @base mixin interface', cf.pos);
								}
							} else 
								Context.fatalError('@base field <${mf.name}> required by mixin not found in ${classFql}', lc.pos);
						case OVERWRITE:
							if (cf != null)
							{
								overwriteMethod(mixinFql, mf, cf);
							} else {								
								Context.warning('@overwrite mixin method <${mf.name}> not found in ${classFql}, method will be added as @mixin', lc.pos);
							}
							
							fields.push(mf);
					}
				}
			}
			
		}

		return fields;
	}
	
	
	static function makeSureFieldCanBeBase(f:Field)
	{
		switch (f.kind)
		{
			case FVar(t, e):
				if (e != null)
					Context.fatalError('@base var can\'t have initializer', f.pos);
			case FProp(get, set, t, e):
				if (e != null)
					Context.fatalError('@base property can\'t have initializer', f.pos);
			case FFun(func):
				if (func.expr != null) 
					Context.fatalError('@base method can\'t have implementation', f.pos);
		}
	}
	
	static function makeSureFieldCanBeMixin(f:Field, fields:Array<Field>)
	{
		switch (f.kind)
		{
			case FVar(t, e):
			case FProp(get, set, t, e):				
			case FFun(func):
				if (func.expr == null) 
					Context.fatalError('@mixin method should have implementation (body)', f.pos);
		}
	}
	
	static function makeSureFieldCanBeOverwrite(f:Field)
	{
		switch (f.kind)
		{
			case FVar(t, e):				
				Context.fatalError('var can\'t be overwritten, makes no sense', f.pos);
			case FProp(get, set, t, e):				
				Context.fatalError('property can\'t be overwritten, but it\'s getter/setter can be', f.pos);
			case FFun(func):
				if (func.expr == null) 
					Context.fatalError('@overwrite method should have implementation (body)', f.pos);
		}
	}
	
	static function getFieldMixinType(f:Field):FieldMixinType
	{		
		var mixin = hasMetaWithName(f.meta, "mixin");
		var base = hasMetaWithName(f.meta, "base");
		var ow = hasMetaWithName(f.meta, "overwrite");		
	
		return switch [mixin, base, ow]
		{
			case [false, false, false]: MIXIN;	//default
			case [true,  false, false]: MIXIN;
			case [false, true,  false]: BASE;
			case [false, false, true ]: OVERWRITE;
			case _: Context.fatalError('Multiple field mixin types are not allowed', f.pos);
			
		}
	}
	
	/**
	 * Removes access, initial values, FFun exprs and 
	 * returns new valid interface field
	 * 
	 * @param	f
	 * @return
	 */
	static function makeInterfaceField(f:Field):Field
	{
		
		var out:Field = {
			name: f.name,
			access: [],
			kind: switch (f.kind)
			{
				case FVar(t, e): FVar(t, null);
				case FFun(f): 
					FFun({
						args: f.args,
						ret: f.ret != null ? f.ret : macro:Void,
						params: f.params,
						expr: null
					});
				case FProp(get, set, t, e): FProp(get, set, t, null);
			},
			doc: f.doc,
			meta: f.meta,
			pos: f.pos			
		};
		
		return out;
	}
		
	/**
	 * Renames old (cf) method to mixinFql + _ + cf.name
	 * Adding mixin fully qualified class name (mixinFql) avoids conflicts when more than one mixin overwrites method //fix my english :(
	 * Replaces all original method calls withing mixin method with renamed one
	 * 
	 * @param	mixinFql
	 * @param	mf
	 * @param	cf
	 */
	static function overwriteMethod(mixinFql:String, mf:Field, cf:Field)
	{		

		var original = cf.name;
		var renamed = mixinFql.replace(".", "_").toLowerCase() + "_" + original;
		cf.name = renamed;

		//replace base.$oldName with this.$newName
		function searchAndReplace(e:Expr)
		{
			switch (e.expr)
			{
				case EField(macro base, name) if (name == original):					
					e.expr = EField(macro this, renamed);
				case _:
					e.iter(searchAndReplace);
			}			
		};		
		
		
		var mfunc = extractFFunFunction(mf);		
		searchAndReplace(mfunc.expr);
	}
	
	
	
	static function getFqlClassName(ct:ClassType)
	{
		return ct.module.endsWith("." + ct.name) ? ct.module : ct.module + "." + ct.name;
	}
	
	static function hasMetaWithName(meta:Metadata, name:String):Bool
	{
		return meta.exists(function (e) return e.name == name);
	}
	
	/**
	 * Checks if field satisfies interface/mixin (interf) field
	 * @param	interf mixin field
	 * @param	field can be null, false returned
	 * @return 	true if satisfies
	 */
	static function satisfiesInterface(interf:Field, field:Null<Field>):Bool
	{		
		if (interf == null) 
			throw 'Interface field should not be null';
		
		if (field != null && 
			interf.name == field.name && 
			Same.access(interf.access, field.access))
		{
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
	
	static function extractFFunFunction(f:Field):Function
	{
		return switch (f.kind)
		{
			case FFun(f): f;
			case _: throw 'Not a FFun field';			
		}
	}
}