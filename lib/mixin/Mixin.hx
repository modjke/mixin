/*
Copyright (c) 2020 Ignatiev Mikhail (https://github.com/modjke) <ignatiev.work@gmail.com>

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
import haxe.macro.Printer;
import haxe.macro.Type;
import haxe.macro.Type.ClassField;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.Ref;
import mixin.same.Same;
import mixin.tools.ClassFieldTools;
import mixin.typer.Typer;

#if macro

class Mixin 
{
	static var mixins:StringMap<Mixin> = new StringMap();
	static var printer = new Printer();
	
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
		
		if (!declaredProperly(lc)) Context.fatalError('Mixin should be declared as non-extern interface with @mixin meta present', lc.pos);
		
		if (Context.getLocalUsing().length > 0) Context.fatalError('Mixins module with usings are not supported', lc.pos);

		var typeParams = lc.params.map(function (tp) return tp.name);
		var baseExtends:Array<String> = [];		
		var baseImplements:Array<String> = []; 
				
		lc.meta.get().consumeMetadata(function (meta)
		{
			switch (meta.name)
			{
				case "baseExtends":
					baseExtends = consumeFqlsFromMetaArgs(meta);
					lc.meta.remove(meta.name);				
				case "baseImplements":	
					baseImplements = consumeFqlsFromMetaArgs(meta);
					lc.meta.remove(meta.name);
				case _:
			}
			
			return true;
		});
		
		var mixin = new Mixin(getFqlClassName(lc), typeParams, baseExtends, baseImplements);
		
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
				var mf = new MixinField(mixin, field);
				mf.convertForDisplay();				
				mixin.fields.push(mf);
				
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

			var typer = new Typer(lc, Context.getLocalModule(), Context.getLocalImports());
			
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

		#if display
		if(null == cached) {
			return null;
		}
		#end
		
		for (shouldImplement in cached.baseImplements)
		{
			if (!lc.interfaces.exists(function (iface)
			{
				return getFqlClassName(iface.t.get()) == shouldImplement;
			})) Context.fatalError('Mixin $mixinFql requires base class to implement $shouldImplement', lc.pos);
		}
		
		for (shouldExtend in cached.baseExtends)
		{
			var satisfies = false;
			
			var superLc:ClassType = lc;
			while (superLc != null)
				if (getFqlClassName(superLc) == shouldExtend) {					
					satisfies = true;
					break;
				} else 
					superLc = getSuperClass(superLc);
			
			if (!satisfies)
				Context.fatalError('Mixin $mixinFql requires base class to extend $shouldExtend', lc.pos);
		}
		
		
		var typeParams:Array<Type> = traverseTypeParameters(lc, mixinFql);
		
		#if display
			for (mf in cached.fields)
			{
				switch (mf.type)
				{
					case MIXIN | OVERWRITE:
						var noConflicts = !fields.exists(function (f) return f.name == mf.name);
						if (noConflicts)
							fields.push(mf.create(typeParams, true));
					
					case _:
				}
			}
		#else 
			var typer = new Typer(lc, Context.getLocalModule(), Context.getLocalImports());
			
			for (mf in cached.fields)			
			{			
				
				//mf - mixin field
				//cf - existing class field (can be null)

				var isBuildField = true;
				var cf = fields.find(function (f) return f.name == mf.name);
				if (cf == null)
				{
					isBuildField = false;
					cf = getFieldFromHierarchy(lc, mf.name);
				}
				
				var mixin = mf.create(typeParams, false);	//basically a field copy, do whatever you want with it
		
				
				inline function assertSatisfiesInterface()
				{
					if (cf != null)
						if (!typer.satisfiesInterface(mixin, cf))
						{
							Context.warning('Field <${cf.name}> is defined here', mf.pos);
							Context.fatalError('Field <${cf.name}> does not satisfy mixin\'s interface', cf.pos);
						}
				}
				
				
				switch (mf.type)
				{
					case MIXIN:
						if (cf == null)
							fields.push(mixin);
						else 
							Context.fatalError('@mixin field <${mf.name}> overlaps base field with the same name in ${classFql}', cf.pos);
					case BASE:
						assertSatisfiesInterface();
						
						if (cf == null)
							Context.fatalError('@base field <${mf.name}> required by mixin not found in ${classFql}', lc.pos);
					case OVERWRITE:
						assertSatisfiesInterface();
						
						if (cf != null || mf.meta.addIfAbsent)
						{
							//when isBuildField is true, cf is always NOT NULL
							//if base class itself has declared that field
							if (isBuildField) {
								
								//fail if this is getter or setter for @:isVar proprerty
								assertFieldIsNotGetSetForIsVarProperty(cf, fields);
								
								if (mf.isConstructor) {
									overwriteConstructor(mixin, cf);
								} else {
									mixin.name = mf.baseFieldName;	
									
									//so we make it private
									mixin.makePrivate();
									if (mf.meta.inlineBase) mixin.makeInline();									
									
									//mixin field recieves all meta from base field
									//class field recieves mixin's implementation
									copyMetaAndExchangeImpl(mixin, cf);	
									
									fields.push(mixin);
								}
								
							} else {
								//isBuildField = false
								//cf can be NULL								
								if (mf.isConstructor) {
									//if any of the super classes have constructor
									if (cf != null) 
										replaceBaseConstructorCallsWithSuper(mixin);						
									else 
										removeBaseConstructorCalls(mixin);
										
								} else {
									var shouldBeOverridden = cf != null;
									var mockBase = mf.createEmptyBaseMethod(shouldBeOverridden);
									mockBase.makePrivate();
									
									if (shouldBeOverridden) 
										mixin.makeOverride();
									
									fields.push(mockBase);
								}
								
								fields.push(mixin);
							}
							
							
						} else 
							Context.fatalError('@overwrite mixin method <${mf.name}> not found in ${classFql} (@overwrite(addIfAbsent=true) to add anyway)', lc.pos);						
						
						
						
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
	 * Removes $base(arg1...) calls (replaces it with empty blocks
	 * @param	field
	 */
	static function removeBaseConstructorCalls(field:Field)
	{
		function searchAndRemove(expr:Expr)
		{
			switch (expr.expr)
			{
				case ECall(_.expr => EConst(CIdent("$base")), params):
					expr.expr = EBlock([]);
				case _:
					expr.iter(searchAndRemove);
			}
		}
		
		switch (field.kind)
		{
			case FFun(f): searchAndRemove(f.expr);
			case _: throw "Only FFun is supported";
		}
	}
	
	/**
	 * Replaces $base(arg1,arg2...) with super(arg1,arg2,...)
	 * @param	field
	 */
	static function replaceBaseConstructorCallsWithSuper(field:Field)
	{
		function searchAndReplace(expr:Expr)
		{
			switch (expr.expr)
			{
				case ECall(e, params):
					switch (e.expr)
					{
						case EConst(CIdent("$base")):
							e.expr = EConst(CIdent("super"));
						case _:
					}					
				case _:
					expr.iter(searchAndReplace);
			}
		}
		
		switch (field.kind)
		{
			case FFun(f): searchAndReplace(f.expr);
			case _: throw "Only FFun is supported";
		}		
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
	
	static function declaredProperly(lc:ClassType):Bool
	{
		return lc.isInterface && !lc.isExtern && lc.meta.has("mixin");
	}
		
	static function getFieldFromHierarchy(lc:ClassType, fieldName:String):Field
	{
		while ((lc = getSuperClass(lc)) != null) {
			if (fieldName == "new") {
				if (lc.constructor != null)
					return ClassFieldTools.toField(lc.constructor.get());
			} else 			
				for (f in lc.fields.get())
					if (f.name == fieldName)
						return ClassFieldTools.toField(f);
		}
				
					
		return null;
	}
	
	static function getSuperClass(lc:ClassType):Null<ClassType>
	{
		if (lc.superClass != null)
			return lc.superClass.t.get();
		else
			return null;
	}
	
	static function getSuperClassRef(lcRef:Ref<ClassType>):Ref<ClassType>
	{
		var lc = lcRef != null ? lcRef.get() : null;
		return (lc != null && lc.superClass != null) ? lc.superClass.t : null;
	}
	
	static function traverseTypeParameters(lc:ClassType, mixinFql:String):Array<Type>
	{
		var inheritancePath:Array<{ t: ClassType, params: Array<Type> }> = [];
		var found = false;
		function traverse(interfaces:Array<{ t:Ref<ClassType>, params:Array<Type> }>) {
			for (iface in interfaces) {					
				
				
				var ifaceClass = iface.t.get();
				traverse(ifaceClass.interfaces);
				
				if (mixinFql == getFqlClassName(ifaceClass))
					found = true;
					
				if (found)
				{
					inheritancePath.push({
						t: ifaceClass,
						params: iface.params
					});
					break;
				}
			}
		}
		
		traverse(lc.interfaces);
		
		if (!found) throw "Unable to traverse inheritance path to " + mixinFql;
		
		//trace('Path for '+ getFqlClassName(lc) + '/' + mixinFql +': ' + inheritancePath.map(function (ct) return ct.t.name).join(" -> "));
		
		var out:Array<Type> = null;
		for (entry in inheritancePath)
		{
			var expected = entry.t.params;
			var supplied = entry.params;
			
			//trace('Expected: ' + getFqlClassName(entry.t), expected);
			//trace('Supplied: ' + getFqlClassName(entry.t), supplied);
			if (out == null)
				out = supplied.copy();
			else {
				for (e in expected)
				{
					for (i in 0...out.length)
						if (out[i].toString() == e.t.toString())
							out[i] = supplied[expected.indexOf(e)];
				}
			}
		}
		
		return out;		
	}
	
	static function consumeFqlsFromMetaArgs(meta:MetadataEntry):Array<String>
	{
		var out = [];
		meta.cosumeParameters(function (expr)
		{
			try {
				
				switch (Context.getType(expr.toString()))
				{
					case TInst(t, params):
						out.push( getFqlClassName(t.get()) );					
					case _ => value:
						throw 'Invalid class or interface type: $value';						
				}
			} catch (any:Any) {
				Context.fatalError(Std.string(any), meta.pos);
			}
			
			return true;
		});
		return out;
	}
	
	
	
	
	/* non static */
	public var fql(default, null):String;
	public var fields(default, null):Array<MixinField>;	
	public var typeParams(default, null):Array<String>;
	public var baseImplements(default, null):Array<String>;
	public var baseExtends(default, null):Array<String>;
	
	public function new(fql:String, typeParams:Array<String>, baseExtends:Array<String>, baseImplements:Array<String>)
	{
		this.fql = fql;
		this.fields = [];
		this.typeParams = typeParams;		
		this.baseExtends = baseExtends;		
		this.baseImplements = baseImplements;
	}
}

#end