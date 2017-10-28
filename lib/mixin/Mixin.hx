package mixin;
import haxe.ds.StringMap;
import haxe.io.Output;
import haxe.macro.ComplexTypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Type.ClassField;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.Ref;
import haxe.macro.Type.VarAccess;
import mixin.copy.Copy;
import mixin.same.Same;
import mixin.tools.MoreExprTools;
import mixin.typer.resolver.VarStack;
import mixin.typer.Typer;

using haxe.macro.Tools;
using mixin.tools.MoreComplexTypeTools;
using mixin.tools.FieldTools;
using mixin.tools.MetadataTools;
using mixin.tools.MoreExprTools;

using StringTools;
using Lambda;


class Mixin 
{
	static var mixins:StringMap<Mixin> = new StringMap();
	
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

		var typeParams = lc.params.map(function (tp) return tp.name);
		var mixin = new Mixin(getFqlClassName(lc), typeParams);
		
		if (!mixins.exists(mixin.fql))
			mixins.set(mixin.fql, mixin);
		else
			throw 'Mixin with ${mixin.fql} already existed...';
		
		lc.meta.add(":autoBuild", [macro mixin.Mixin.includeMixin($v{mixin.fql})], lc.pos);
			
		var interfaceFields:Array<Field> = [];	
		var buildFields = Context.getBuildFields();
		
		
		#if display
		
			for (field in buildFields)
			{				
				var mf = new MixinField(mixinFql, typeParams, field);
				mf.convertForDisplay();				
				mixinFields.push(mf);
				
				if (mf.isPublic && !mf.isConstructor)
					interfaceFields.push(mf.createInterface());			
			}
			
		#else
		
			//to check conflicts with merging mixins we collect all of them
			var parentMixins:StringMap<Mixin> = new StringMap();
				
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
			
			var overwriteCache = new StringMap<String>();
			for (field in buildFields)
			{		
				typer.resolveComplexTypesInField(field);
				
				var mf = new MixinField(mixin, field);		
				
				if (mf.type == MIXIN) 
				{
					var conflictingMixin = getConflictingMixinName(mf.name);
					if (conflictingMixin != null)
						Context.fatalError('Field ${mf.name} is defined in ${mixin.fql} and $conflictingMixin', mf.pos);
				}
					
				mf.validateMixinType();				
				mixin.fields.push(mf);	
				
				overwriteCache.set(mf.name, mf.baseFieldName);
				
				if (mf.isPublic && !mf.isConstructor)
					interfaceFields.push(mf.createInterface());	
			}
			
			var allFields = buildFields.map(function (f) return f.name);
			for (field in buildFields)
			{			
				typer.resolveComplexTypesInFieldExpr(field, allFields);			
			}
			
			for (mf in mixin.fields)
			{
				if (mf.isMethod)
					switch (mf.type)				
					{
						//if has bodyyyy
						case MIXIN | OVERWRITE:
							if (mf.meta.debug) {
								
								Sys.println('-- debugging: ${mf.name}');
								Sys.println('-- before:');
								Sys.println(mf.implementation.toString());
							}
							
							var baseCalls = replaceBaseCalls(mf.implementation, overwriteCache);
							//if this method is OVERWRITE and not constructor and if not ignoring base calls and base method was not called then warn!
							if (mf.type == OVERWRITE && !mf.isConstructor && !mf.meta.ignoreBaseCalls && baseCalls.indexOf(mf.name) == -1)
								Context.warning('Not calling base method in @overwrite can cause undefined behaviour (add ignoreBaseCalls=true to suppress)', mf.pos);
					
							
							if (mf.meta.debug)
							{
								Sys.println('-- after:');
								Sys.println(mf.implementation.toString());
							}
						case _:
					}
			}
				
		
		#end
		
	
		
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
		
		//can't add mixin to an extern
		if (lc.isExtern) 
			Context.fatalError("Can't include mixin into extern class", lc.pos);
		
		// if extending interface (or mixin) skip
		if (lc.isInterface) 
			return null;	
			
		// error if mixin was included twice or more somewhere in hierarchy 		
		var includedIn = whereMixinWasIncluded(lc, mixinFql, true);
		if (includedIn != null)
			Context.fatalError('Mixin <${mixinFql}> was already included in <${getFqlClassName(includedIn)}>', includedIn.pos);
		

		markAsMixinWasIncludedHere(lc, mixinFql);
			
		var classFql = getFqlClassName(lc);				
		var fields = Context.getBuildFields();
		var cached = mixins.get(mixinFql);
		
		//maps mixin fql -> [TypeParams]
		var typeParamMap:StringMap<Array<Type>> = collectTypeParamMap(lc);
		var typeParams = typeParamMap.get(mixinFql);
		
		#if display
			for (mf in cached.fields)
			{
				switch (mf.type)
				{
					case MIXIN | OVERWRITE:
						var noConflicts = !fields.exists(function (f) return f.name == mf.name);
						if (noConflicts)
							fields.push(mf.create(typeParams));
					
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
				
				var mixin = mf.create(typeParams);	//basically a field copy, do whatever you want with it
				switch (mf.type)
				{
					case MIXIN:
						if (cf == null)
							fields.push(mixin);
						else 
							Context.fatalError('@mixin field <${mf.name}> overlaps base field with the same name in ${classFql}', cf.pos);
					case BASE:
						if (cf != null)
						{
							//if mixin field is public there is no need to check interface
							//haxe will check it for us
							//we have to check only private @:base fields
							if (!mf.isPublic && !typer.satisfiesInterface(mixin, cf))
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
							
							if (typer.satisfiesInterface(mixin, cf))
							{
								if (cf.isConstructor()) {
											
									overwriteConstructor(mixin, cf);
								} else {				
									//mixin becames base field																
									mixin.name = mf.baseFieldName;	
									
									//so we make it private
									mixin.makePrivate();
									if (mf.meta.inlineBase) mixin.makeInline();									
									
									//mixin field recieves all meta from base field
									//class field recieves mixin's implementation
									copyMetaAndExchangeImpl(mixin, cf);	
									
									overwriteCache.set(cf.name, mixin.name);
									
									fields.push(mixin);
								}
							} else 
							{
								Context.warning('@overwrite field for <${cf.name}> is defined here', mf.pos);
								Context.fatalError('Field <${cf.name}> does not satisfy @overwrite mixin interface', cf.pos);
							}
							
						} else {								
							fields.push(mixin);
							
							Context.warning('@overwrite mixin method <${mf.name}> not found in ${classFql}, method will be included!', lc.pos);						
						}
						
						
				}
			}
			
			
				
			
		#end
		
		

		return fields;
	}
	
	static function copyMetaAndExchangeImpl(mixin:Field, cf:Field)
	{		
		copyMeta(cf, mixin);
		
		var mixinFunction = mixin.extractFFunFunction();
		var originalFunction = cf.extractFFunFunction();
		
		mixin.replaceFFunFunction(originalFunction);		
		cf.replaceFFunFunction(mixinFunction);
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
				case ECall(macro $base, params):			
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
	}
	
	//returns array of base calls replaced
	static function replaceBaseCalls(expr:Expr, map:StringMap<String>):Array<String>
	{
		var baseCalls:Array<String> = [];
		function searchAndReplace(e:Expr)
		{			
			switch (e.expr)
			{				
				case EField(_.expr => EConst(CIdent("$base")), field):		
					if (map.exists(field)) {
						baseCalls.push(field);
						e.expr = EField(macro this, map.get(field));
					} else 
						Context.fatalError('Unknown base field: ' + field, e.pos);
				case _:
					e.iter(searchAndReplace);
			}			
		};		

		searchAndReplace(expr);
		
		return baseCalls;

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
	
	static function markAsMixinWasIncludedHere(base:ClassType, mixinFql:String)
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
	
	static function collectTypeParamMap(lc:ClassType):StringMap<Array<Type>>
	{
		var typeParamMap:StringMap<Array<Type>> = new StringMap();
		
		function traverse(interfaces:Array<{ t:Ref<ClassType>, params:Array<Type> }>) {
			for (iface in interfaces) {					
				var ct = iface.t.get();
				var fql = getFqlClassName(ct);
				
				if (mixins.exists(fql))					
					typeParamMap.set(fql, iface.params.copy());
					
				traverse(ct.interfaces);
			}
		}
		
		traverse(lc.interfaces);
		
		return typeParamMap;		
	}
	
	
	/* non static */
	public var fields(default, null):Array<MixinField> = [];
	public var fql(default, null):String;
	public var typeParams(default, null):Array<String>;
	
	public function new(fql:String, typeParams:Array<String>)
	{
		this.fql = fql;
		this.typeParams = typeParams;
	}
}