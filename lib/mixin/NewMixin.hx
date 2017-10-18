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
import mixin.same.Same;
import mixin.typer.TypeStack;
import mixin.typer.Typer;

using haxe.macro.Tools;
using mixin.tools.MoreMacroTools;
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

typedef CachedMixin = {
	fields:Array<Field>,
	imports:Array<ImportExpr>,
	usings:Array<Ref<ClassType>>
}

class NewMixin 
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
		
		if (!lc.isInterface)
			Context.fatalError('Mixin should be declared as interface', lc.pos);

		var mixinFql = getFqlClassName(lc);
		
		lc.meta.add(":autoBuild", [macro mixin.Mixin.includeMixin($v{mixinFql})], lc.pos);
		
		if (!lc.meta.has("mixin")) lc.meta.add("mixin", [], lc.pos);
				
		var interfaceFields:Array<Field> = [];
		var mixinFields:Array<Field> = [];
		
		var buildFields = Context.getBuildFields();
		
		for (field in buildFields)
		{				
			#if display
			
			Typer.prepareForDisplay(field);
			Typer.resolveComplexTypesInField(field);
			
			#else

			Typer.makeFieldTypeDeterminable(field);
			Typer.resolveComplexTypesInField(field);			
			
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
			#end
			
			mixinFields.push(field);			
			if (field.isPublic() && !field.isConstructor())
				interfaceFields.push(field.makeInterfaceField());
		}
		
		
		if (!mixins.exists(mixinFql))
			mixins.set(mixinFql, {
				fields: mixinFields,
				imports: Context.getLocalImports(),
				usings: Context.getLocalUsing()
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
		
		for (mf in cached.fields)
		{
			//mf - mixin field
			//cf - existing class field (can be null)
		
			var cf = fields.find(function (f) return f.name == mf.name);
			
			#if display
			
			switch (getFieldMixinType(mf))
			{
				case MIXIN | OVERWRITE:
					if (cf == null)
						fields.push(mf);
				
				case _:
			}
			#else 
			
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
						if (mf.isPrivate() && !Typer.satisfiesInterface(mf, cf))
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
						
						if (Typer.satisfiesInterface(mf, cf))
						{
							if (cf.isConstructor())
								overwriteConstructor(mf, cf);
							else
								overwriteMethod(mixinFql, mf, cf);
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
			
			#end
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
	
	
	
	
		

	/**
	 * class method is transformed into function
	 * mf code injected into cf with
	 * base.method calls becoming function calls
	 * @param	mixinFql
	 * @param	mf
	 * @param	cf
	 */
	static function overwriteMethod(mixinFql:String, mf:Field, cf:Field)
	{		

		copyMeta(cf, mf);
		
		var baseFuncName = mixinFql.replace(".", "_").toLowerCase() + "_" + cf.name;
		var baseFunc = cf.extractFFunFunction();
		
		var baseFuncExpr:Expr = {
			expr: EFunction(baseFuncName, baseFunc),
			pos: mf.pos
		};
		
		var mfunc = mf.extractFFunFunction();	
		
		function searchAndReplace(e:Expr)
		{			
			switch (e.expr)
			{
				
				case ECall(_.expr => EField(macro base, field), p) if (field == cf.name):						
					e.expr = ECall(macro $i{baseFuncName}, p);
				case _:
					e.iter(searchAndReplace);
			}			
		};		

		searchAndReplace(mfunc.expr);
		//prepend basefunc
		mfunc.expr = macro $b{[ baseFuncExpr, mfunc.expr ]};
		
		//replace original
		cf.replaceFFunFunction(mfunc);
		
		if (mf.meta.hasMetaWithName("debug"))
		{
			Sys.println('Overwritten method $mixinFql > ${mf.name}:');
			Sys.println(cf.extractFFunFunction().expr.toString());
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
				case ECall(macro base, []):			
					if (!injected)
					{
						injected = true;
						e.expr = baseFunc.expr.expr;
					} else 
						Context.fatalError('base() constructor called more that once', cf.pos);
					
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