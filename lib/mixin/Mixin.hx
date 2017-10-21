package mixin;
import haxe.ds.StringMap;
import haxe.io.Output;
import haxe.macro.ComplexTypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type.ClassField;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.Ref;
import haxe.macro.Type.VarAccess;
import mixin.copy.Copy;
import mixin.same.Same;
import mixin.tools.MoreExprTools;
import mixin.typer.VarStack;
import mixin.typer.Typer;

using haxe.macro.Tools;
using mixin.tools.MoreComplexTypeTools;
using mixin.tools.FieldTools;
using mixin.tools.MetadataTools;

using StringTools;
using Lambda;


enum FieldMixinType
{
	MIXIN;
	BASE;
	OVERWRITE;
}

enum MultipleOverwritesAction
{
	ERROR;
	WARN;
	IGNORE;
}

typedef CachedMixin = {
	fields:Array<Field>
}

class Mixin 
{
	static var mixins:StringMap<CachedMixin> = new StringMap();
	
	public static function sugar():Array<Field>
	{
		var lcRef = Context.getLocalClass();
		var lc = lcRef != null ? lcRef.get() : null;		
		var isMixin = lc != null && lc.meta.has("mixin");
		
		return isMixin ? createMixin() : null;
	}
	
	/**
	 * Creates mixin from interface
	 * @return
	 */
	@:noCompletion
	public static function createMixin():Array<Field>
	{	
		var lc = Context.getLocalClass().get();				
		
		if (!lc.isInterface) Context.fatalError('Mixin should be declared as interface', lc.pos);
		if (Context.getLocalUsing().length > 0) Context.fatalError('Mixins module with usings are not supported', lc.pos);

		var mixinFql = getFqlClassName(lc);
		
		lc.meta.add(":autoBuild", [macro mixin.Mixin.includeMixin($v{mixinFql})], lc.pos);
		
		if (!lc.meta.has("mixin")) lc.meta.add("mixin", [], lc.pos);
				
		var interfaceFields:Array<Field> = [];
		var mixinFields:Array<Field> = [];
		
		var buildFields = Context.getBuildFields();
		
		#if display
		
			for (field in buildFields)
			{				
				validateField(field);
				Typer.prepareForDisplay(field);
				
				mixinFields.push(field);
				if (field.isPublic() && !field.isConstructor())
					interfaceFields.push(field.makeInterfaceField());				
			}
			
		#else
		
			var typer = new Typer(Context.getLocalModule(), Context.getLocalImports());
		
			for (field in buildFields)
			{				
				validateField(field);
				Typer.makeFieldTypeDeterminable(field);
				
				if (typer == null) 
					typer = new Typer(Context.getLocalModule(), Context.getLocalImports());
				
				typer.resolveComplexTypesInField(field);
				
				switch (getFieldMixinType(field))
				{	
					case MIXIN:
						if (field.isConstructor()) Context.fatalError('Mixin only allowed to have @overwrite constructor', field.pos);
							
						makeSureFieldCanBeMixin(field, buildFields);
					case BASE:
						if (field.isConstructor()) Context.fatalError('Mixin only allowed to have @overwrite constructor', field.pos);
						
						makeSureFieldCanBeBase(field);
					case OVERWRITE:	
						makeSureFieldCanBeOverwrite(field);
					
				}

				mixinFields.push(field);			
				if (field.isPublic() && !field.isConstructor())
					interfaceFields.push(field.makeInterfaceField());
			}
			
			for (field in buildFields)
			{			
				typer.resolveComplexTypesInFieldExpr(field, buildFields);			
			}
				
		
		#end
		
		if (!mixins.exists(mixinFql))
			mixins.set(mixinFql, {
				fields: mixinFields
			});		
		else
			throw 'Mixin with ${mixinFql} already existed...';
		
		return interfaceFields;
	}
	
	

	/**
	 * Includes mixin into base class
	 * @return
	 */
	@:noCompletion
	public static function includeMixin(mixinFql:String):Array<Field>
	{
		var lc = Context.getLocalClass().get();		
		var classFql = getFqlClassName(lc);				
		var fields = Context.getBuildFields();
		
		assertWasNotYetIncluded(lc, mixinFql);

		var cached = mixins.get(mixinFql);
		
		#if display
			for (mf in cached.fields)
			{
				switch (getFieldMixinType(mf))
				{
					case MIXIN | OVERWRITE:
						var noConflicts = !fields.exists(function (f) return f.name == mf.name);
						if (noConflicts)
							fields.push(mf);
					
					case _:
				}
			}
		#else 
			var overwriteCache = new StringMap<String>();
			var typer = new Typer(Context.getLocalModule(), Context.getLocalImports());
			
			for (mf in cached.fields)
			{			
				//mf - mixin field
				//cf - existing class field (can be null)
				mf = Copy.field(mf);
				
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
							//if mixin field is public there is no need to check interface
							//haxe will check it for us
							//we have to check only private @:base fields
							if (mf.isPrivate() && !typer.satisfiesInterface(mf, cf))
							{
								Context.warning('@base field for <${cf.name}> is defined here', mf.pos);
								Context.fatalError('Field <${cf.name}> does not satisfy @base mixin interface', cf.pos);
							}						
						} else 
							Context.fatalError('@base field <${mf.name}> required by mixin not found in ${classFql}', lc.pos);
					case OVERWRITE:
						if (cf != null)
						{
							assertFieldIsNotGetSetForIsVarProperty(cf, fields);
							
							if (typer.satisfiesInterface(mf, cf))
							{
								if (cf.isConstructor())
									overwriteConstructor(mf, cf);
								else {				
									overwriteMethod(mixinFql, mf, cf);
									overwriteCache.set(cf.name, mf.name);
									
									fields.push(mf);
								}
							} else 
							{
								Context.warning('@overwrite field for <${cf.name}> is defined here', mf.pos);
								Context.fatalError('Field <${cf.name}> does not satisfy @overwrite mixin interface', cf.pos);
							}
							
						} else {								
							fields.push(mf);
							
							Context.warning('@overwrite mixin method <${mf.name}> not found in ${classFql}, method will be included!', lc.pos);						
						}
						
						
				}
			}
			
			for (field in fields)
				switch (getFieldMixinType(field)) {
					case MIXIN | OVERWRITE:
						switch (field.kind)
						{
							case FFun(fun):
								var debug = field.meta.hasMetaWithName("debug");
								if (debug) {
									
									Sys.println('-- debugging: ${field.name}');
									Sys.println('-- before:');
									Sys.println(fun.expr.toString());
								}
								
								replaceBaseCalls(fun.expr, overwriteCache, debug);
								
								if (debug)
								{
									Sys.println('-- after:');
									Sys.println(fun.expr.toString());
								}
							case _:
						}
					case _:
				}
				
			
		#end
		
		

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
	
	static function validateField(f:Field)
	{		
		if (f.access != null)
		{
			if (f.access.has(AStatic)) 	 Context.fatalError('Mixin: static fields are not supported', f.pos);
			if (f.access.has(AOverride)) Context.fatalError('Mixin: override fields are not supported', f.pos);
			if (f.access.has(AMacro)) 	 Context.fatalError('Mixin: macro fields are not supported', f.pos);	
		}
	}
	
	static function getFieldMixinType(f:Field):FieldMixinType
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

	static function getMultipleOverwritesAction(f:Field):MultipleOverwritesAction
	{
		var meta = f.meta.getMetaWithName("multipleOverwrites");
		
		if (meta != null) {
			if (meta.params == null || meta.params.length != 1) 
				Context.fatalError('Invalid number of parameters for @multipleOverwrites', f.pos);
				
			
			var param = meta.params[0];			
			var action:MultipleOverwritesAction = switch (param.expr)
			{
				case EConst(CString(_.toLowerCase() => action)):
					switch (action)
					{
						case "warn" | "warning": WARN;
						case "err" | "error": ERROR;
						case "ignore": IGNORE;
						case _: null;						
					}
				case _: null;
			};
			
			if (action == null)
				Context.fatalError('Unknown @multipleOverwrites action: ' + param.toString(), param.pos);
			
			return action;
		} else 
			return ERROR;	//default
	}
		

	/**
	 * Swaps implementations between mf and cf
	 * mf becames original function and gets renamed	 
	 * 
	 * @param	mixinFql
	 * @param	mf
	 * @param	cf
	 */
	static function overwriteMethod(mixinFql:String, mf:Field, cf:Field)
	{		
		var wasOverwrittenByAnotherMixin = cf.meta.hasMetaWithName("overwrite");
		if (wasOverwrittenByAnotherMixin)
			switch (getMultipleOverwritesAction(cf))
			{
				case ERROR:
					Context.fatalError('Two mixins overwriting the same method can cause undefined behaviour', cf.pos);
				case WARN:
					Context.warning('Two mixins overwriting the same method can cause undefined behaviour', cf.pos);
				case IGNORE:				
			};
		
		copyMeta(cf, mf);
		
		var mixinFunction = mf.extractFFunFunction();
		var originalFunction = cf.extractFFunFunction();
		
		mf.replaceFFunFunction(originalFunction);
		cf.replaceFFunFunction(mixinFunction);
		
		mf.name = mixinFql.replace(".", "_").toLowerCase() + "_" + cf.name;

	}
	
	static function overwriteConstructor(mf:Field, cf:Field)
	{
		copyMeta(cf, mf);
		
		var baseFunc = cf.extractFFunFunction();
		
		function searchForReturn(e:Expr)
		{
			switch (e.expr)
			{
				case EReturn(_):
					Context.fatalError('Constructors with <return> statements can\'t be overwritten', cf.pos);
				case _:
					e.iter(searchForReturn);
			}
		}
		
		searchForReturn(baseFunc.expr);
		
		
		var injected = false;
		function searchAndReplace(e:Expr)
		{			
			switch (e.expr)
			{
				case ECall(macro $base, []):			
					if (!injected)
					{
						injected = true;
						e.expr = baseFunc.expr.expr;
					} else 
						Context.fatalError("$base() constructor called more that once", cf.pos);
					
				case _:
					e.iter(searchAndReplace);
			}			
		};		

		var mfunc = mf.extractFFunFunction();	
		searchAndReplace(mfunc.expr);
		
		//replace original
		cf.replaceFFunFunction(mfunc);
		
		if (mf.meta.hasMetaWithName("debug"))
		{
			Sys.println('Overwritten constructor:');
			Sys.println(cf.extractFFunFunction().expr.toString());
		}
	}
	
	static function replaceBaseCalls(expr:Expr, map:StringMap<String>, debug:Bool = false)
	{
		function searchAndReplace(e:Expr)
		{			
			switch (e.expr)
			{				
				case EField(_.expr => EConst(CIdent("$base")), field):		
					if (map.exists(field))
						e.expr = EField(macro this, map.get(field));
					else 
						Context.fatalError('Unknown base field: ' + field, e.pos);
				case _:
					e.iter(searchAndReplace);
			}			
		};		

		searchAndReplace(expr);

	}
	
	/**
	 * Check if anywhere in the hierarchy mixin was already included
	 * @param	base
	 * @param	mixin
	 */
	static function assertWasNotYetIncluded(base:ClassType, mixinFql:String)
	{
		var includedMeta = '__included__' + mixinFql.replace(".","_").toLowerCase();
		var baseFql = getFqlClassName(base);
		
		inline function hasIncludedMeta(base:ClassType)
		{
			return base.meta.has(includedMeta);
		}
		
		inline function addIncludedMeta(base:ClassType)
		{
			base.meta.add(includedMeta, [], base.pos);
		}
		
		if (hasIncludedMeta(base))
		{
			Context.fatalError('Mixin <${mixinFql}> was already included in <${baseFql}>', base.pos);
		} else {
			addIncludedMeta(base);
			
			if (base.superClass != null && base.superClass.t.get() != null) {
				assertWasNotYetIncluded(base.superClass.t.get(), mixinFql);
			}
		}
	}
	
	
	
	
	
	
	
	/**
	 * Copies meta from class field (cf) to mixin field (mf)
	 * @param	mf
	 * @param	cf
	 */
	static function copyMeta(mf:Field, cf:Field)
	{
		if (cf.meta != null)
		{
			for (m in cf.meta)
			{
				if (mf.meta == null) mf.meta = [];
				
				var dm = mf.meta.getMetaWithName(m.name);

				if (dm != null)
				{
					
					if (!Same.metaEntries(m, dm))
					{
						Context.warning('Conflicting mixin field defined here', mf.pos);
						Context.fatalError('Found conflicting base|mixin metadata @${m.name} for field <${cf.name}>', cf.pos);
					}
				} else 
					mf.meta.push(m);
			}
		}
	}
	
	static function getFqlClassName(ct:ClassType)
	{
		return ct.module.endsWith("." + ct.name) ? ct.module : ct.module + "." + ct.name;
	}
	
	/**
	 * Fails if field is getter or setter for some property with @:isVar metadata
	 * Overwriting this kind of fields will result in stack overflow: overwritten method will call original and vice versa.
	 * @param	field
	 * @param	fields
	 */
	static function assertFieldIsNotGetSetForIsVarProperty(field:Field, fields:Array<Field>)
	{
		if (field.isMethod())
			for (f in fields)
				if (f.meta.hasMetaWithName(":isVar"))
					switch (f.kind)
					{
						case FProp(get, set, t, e):
							if (get == "get") get = "get_" + f.name;
							if (set == "set") set = "set_" + f.name;
							
							if (get == field.name)
								Context.fatalError('Overwriting a property getter for @:isVar property is not supported', field.pos);
								
							if (set == field.name)
								Context.fatalError('Overwriting a property setter for @:isVar property is not supported', field.pos);
							
						case _:
					}
	}
	
	
}