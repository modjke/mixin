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
using mixin.tools.MoreExprTools;

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
	fields:Array<MixinField>
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
	static function createMixin():Array<Field>
	{	
		var lc = Context.getLocalClass().get();				
		
		if (!isMixin(lc)) Context.fatalError('Mixin should be declared as interface', lc.pos);
		
		if (Context.getLocalUsing().length > 0) Context.fatalError('Mixins module with usings are not supported', lc.pos);

		var mixinFql = getFqlClassName(lc);
		
		lc.meta.add(":autoBuild", [macro mixin.Mixin.includeMixin($v{mixinFql})], lc.pos);
			
		var interfaceFields:Array<Field> = [];
		var mixinFields:Array<MixinField> = [];	
		var buildFields = Context.getBuildFields();
		
		#if display
		
			for (field in buildFields)
			{				
				var mf = new MixinField(field);
				mf.convertForDisplay();				
				mixinFields.push(mf);
				
				if (mf.isPublic && !mf.isConstructor)
					interfaceFields.push(mf.createInterface());			
			}
			
		#else
		
			//to check conflicts with merging mixins we collect all of them
			var parentMixins:StringMap<CachedMixin> = new StringMap();
				
			for (parent in lc.interfaces) {
				var parentFql = getFqlClassName(parent.t.get());
				if (mixins.exists(parentFql))			
					parentMixins.set(parentFql, mixins.get(parentFql));
			}
			
			function getConflictingMixinName(name:String):String {
				for (mixinName in parentMixins.keys())
					for (field in parentMixins.get(mixinName).fields)
						if (field.name == name)
							return mixinName;
					
				return null;
			}
			
			//ok lets go :)
			var typer = new Typer(Context.getLocalModule(), Context.getLocalImports());
		
			for (field in buildFields)
			{		
				typer.resolveComplexTypesInField(field);
				
				var mf = new MixinField(field);			
				
				if (mf.type == MIXIN) 
				{
					var conflictingMixin = getConflictingMixinName(mf.name);
					if (conflictingMixin != null)
						Context.fatalError('Field ${mf.name} is defined in $mixinFql and $conflictingMixin', mf.pos);
				}
					
				mf.validateMixinType();

				mixinFields.push(mf);		
				
				if (mf.isPublic && !mf.isConstructor)
					interfaceFields.push(mf.createInterface());	
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
		
		if (lc.isExtern) Context.fatalError("Can't include mixin into extern class", lc.pos);
		
		// if extending interface (or mixin) skip
		if (lc.isInterface) 
			return null;	
		
		// if mixin was included - skip
		if (whereMixinWasIncluded(lc, mixinFql, false) == lc)
			return null;
			
		var superClass = getSuperClass(lc);
		if (superClass != null) {
			var includedIn = whereMixinWasIncluded(superClass, mixinFql, true);
			if (includedIn != null)
				Context.fatalError('Mixin <${mixinFql}> was already included in <${getFqlClassName(includedIn)}>', includedIn.pos);
		}

		mixinWasIncludedHere(lc, mixinFql);
			
		var classFql = getFqlClassName(lc);				
		var fields = Context.getBuildFields();
		var cached = mixins.get(mixinFql);
		
		#if display
			for (mf in cached.fields)
			{
				switch (mf.type)
				{
					case MIXIN | OVERWRITE:
						var noConflicts = !fields.exists(function (f) return f.name == mf.name);
						if (noConflicts)
							fields.push(Copy.field(mf.field));
					
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

				var cf = fields.find(function (f) return f.name == mf.name);
				
				switch (mf.type)
				{
					case MIXIN:
						if (cf == null)
							fields.push(mf.mixin());
						else 
							Context.fatalError('@mixin field <${mf.name}> overlaps base field with the same name in ${classFql}', cf.pos);
					case BASE:
						if (cf != null)
						{
							//if mixin field is public there is no need to check interface
							//haxe will check it for us
							//we have to check only private @:base fields
							if (!mf.isPublic && !typer.satisfiesInterface(mf.field, cf))
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
							
							if (typer.satisfiesInterface(mf.field, cf))
							{
								var mixin = mf.mixin();
								
								if (cf.isConstructor())
									overwriteConstructor(mixin, cf);
								else {				
									overwriteMethod(mixinFql, mixin, cf);									
									overwriteCache.set(cf.name, mixin.name);
									
									fields.push(mixin);
								}
							} else 
							{
								Context.warning('@overwrite field for <${cf.name}> is defined here', mf.pos);
								Context.fatalError('Field <${cf.name}> does not satisfy @overwrite mixin interface', cf.pos);
							}
							
						} else {								
							fields.push(mf.mixin());
							
							Context.warning('@overwrite mixin method <${mf.name}> not found in ${classFql}, method will be included!', lc.pos);						
						}
						
						
				}
			}
			
			for (field in fields)
				switch (MixinField.getFieldMixinType(field)) {
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
		
	
	


	static function getMultipleOverwritesAction(f:Field):MultipleOverwritesAction
	{
		var meta = f.meta.getMetaWithName("multipleOverwrites");
		
		var action:MultipleOverwritesAction = ERROR;	//default
		if (meta != null)
			meta.cosumeParameters(function (p)
			{
				return switch (p.expr)
				{
					case EConst(CIdent(_.toLowerCase() => a)):
						switch (a)
						{
							case "warn" | "warning": action = WARN;
							case "err" | "error": action = ERROR;
							case "ignore": action = IGNORE;
							case _:
								Context.fatalError('Unknown @multipleOverwrites action: $a', p.pos);
						}
						true;
					case _:
						false;
				}
			});
		
		return action;

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
		
		var meta = mf.meta.getMetaWithName("overwrite");
		var inlineBase = false;
		
		meta.cosumeParameters(function (p)
		{
			return switch (p.expr)
			{
				case EBinop(OpAssign, macro inlineBase, _.getBoolValue() => value):
					if (value != null)
						inlineBase = value;
					else 
						Context.fatalError('Invalid value for inlineBase', p.pos);
					
					true;
				case _:
					false;
			}
		});
		
		
		copyMeta(cf, mf);
		
		var mixinFunction = mf.extractFFunFunction();
		var originalFunction = cf.extractFFunFunction();
		
		mf.replaceFFunFunction(originalFunction);
		cf.replaceFFunFunction(mixinFunction);
		
		mf.name = mixinFql.replace(".", "_").toLowerCase() + "_" + cf.name;
		if (inlineBase) {
			mf.makeInline();
		}

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
	static inline var inlcudedMetaTemplate = '__included__%fql%';
	
	static function includedMeta(fql:String) return inlcudedMetaTemplate.replace('%fql%', fql.replace(".", "_").toLowerCase());
	
	static function whereMixinWasIncluded(base:ClassType, mixinFql:String, recursive:Bool = false):ClassType
	{
		if (base.meta.has(includedMeta(mixinFql)))
			return base;
		else if (recursive)
		{
			var superClass = getSuperClass(base);
			if (superClass != null) 
				return whereMixinWasIncluded(superClass, mixinFql, recursive);
			else
				return null;
		} else 
			return null;
	}
	
	static function mixinWasIncludedHere(base:ClassType, mixinFql:String)
	{
		//trace('$mixinFql -> ' + getFqlClassName(base));
		base.meta.add(includedMeta(mixinFql), [], base.pos);
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
	
	static function isMixin(lc:ClassType):Bool
	{
		return lc.isInterface && !lc.isExtern && lc.meta.has("mixin");
	}
	
	static function getSuperClass(lc:ClassType):Null<ClassType>
	{
		if (lc.superClass != null && lc.superClass.t != null && lc.superClass.t.get() != null)
			return lc.superClass.t.get();
		else
			return null;
	}
}