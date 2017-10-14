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
			var ct = iface.t.get();
			if (ct.meta.has("mixin"))
			{				
				var fqlName = getFqlClassName(ct);
				for (mf in mixins.get(fqlName))
				{
					//mf - mixin field
					//cf - existing class field (can be null)
					var cf = fields.find(function (f) return f.name == mf.name);
					
					switch (getFieldMixinType(mf))
					{
						case MIXIN:
							
						case BASE:
							
						case OVERWRITE:
							
					}
					
					switch (mf.kind)
					{
						
						case FFun(f):	
							
							
							if (hasMetaWithName(mf.meta, "overwrite"))
							{
								if (canFieldBeOverwritten(mf,cf))
								{									
									injectMethodCall(mf, cf);
									fields.push(mf);
								}
								else 
									Context.fatalError('Mixin @overwrite method (${mf.name}) signature differs from base', mf.pos);
							} else 
								if (cf == null)
									fields.push(mf)
								else
									Context.fatalError('Method (${mf.name}) overwrites base method with the same name, but has no @overwrite meta', mf.pos);
									
						case FVar(t, e):
							
							// no meta = do not overwrite, 
							
							if (canFieldBeOverwritten(mf, cf))
							{
								
							} else {
								
							}
							
						case _:
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
				Context.fatalError('var can\'t be overwritten (@overwrite)', f.pos);
			case FProp(get, set, t, e):				
				Context.fatalError('property can\'t be overwritten (@overwrite), but it\'s getter/setter can be', f.pos);
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
	 * Injects cf (class field) method into mf (mixin) method
	 * @param	mixinFql
	 * @param	mf
	 * @param	cf
	 */
	static function injectMethodCall(mf:Field, cf:Field)
	{		
		var mfunc = extractFFunFunction(mf);
		var cfunc = extractFFunFunction(cf);
		
		//replace base.$oldName with this.$newName
		mfunc.expr.iter(function (e)
		{
			switch (e.expr)
			{
				case ECall(e.expr => EField(macro base, name), params) if (name == cf.name):					
					e = macro ${cfunc.expr};
				case _:
			}
		});			
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
	 * For all: compares name, kind, type
	 * For FVar | FProp: compares default values, error if different
	 * For FFun: compares signatures, ignores body (expr), that is: two methods with the same api and different implementation considered equal
	 * @param	a should not be null (mixin field)
	 * @param	b can be null (class field)
	 * @return
	 */
	static function canFieldBeOverwritten(a:Field, b:Null<Field>):Bool
	{		
		if (a == null) 
			throw 'First field to compare should not be null!';
		
		if (b != null && a.name == b.name && Same.access(a.access, b.access))
		{
			
			switch ([a.kind,b.kind])
			{
				case [FFun(af), FFun(bf)]:
				
					return 
						Same.functionArgs(af.args, bf.args) &&
						Same.complexTypes(af.ret, bf.ret) &&
						Same.typeParamDecls(af.params, bf.params);												
					
				case [FProp(ag, as, at, ae), FProp(bg, bs, bt, be)]:
					
					if (be != null && !Same.exprs(ae, be))					
						Context.fatalError('Mixin initialiazation value for exising field is different: ${b.name}', b.pos);
						
					return 
						ag == bg &&
						as == bs &&
						Same.complexTypes(at, bt);
						
				case [FVar(at, ae), FVar(bt, be)]:
					
					if (be != null && !Same.exprs(ae, be))					
						Context.fatalError('Mixin initialiazation value for exising field is different: ${b.name}', b.pos);			
					
					return at.equals(bt);
				case _:					
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