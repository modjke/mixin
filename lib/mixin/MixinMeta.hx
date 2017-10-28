package mixin;
import haxe.macro.Context;
import haxe.macro.Expr.Field;

using mixin.tools.MetadataTools;
using mixin.tools.MoreExprTools;
using haxe.macro.Tools;

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

typedef MixinFieldMeta = {
	type: FieldMixinType,
	ignoreBaseCalls: Bool,
	inlineBase: Bool,
	debug: Bool
}

class MixinMeta 
{
	public static function consumeMixinFieldMeta(f:Field):MixinFieldMeta
	{
		var out:MixinFieldMeta = {
			type: MIXIN,
			ignoreBaseCalls: false,
			inlineBase: false,
			debug: false
		};
		
		var typeWasSet = false;
		function assertTypeWasNotSet() {
			if (typeWasSet)
				Context.fatalError('Multiple field mixin types are not allowed', f.pos);
				
			typeWasSet = true;
		}
		
		f.meta.consumeMetadata(function (meta)
		{
			switch (meta.name)
			{
				case "overwrite":
					assertTypeWasNotSet();
					
					out.type = OVERWRITE;
					meta.cosumeParameters(function (expr)
					{
						switch (expr)
						{
							case macro ignoreBaseCalls = $value:
								out.ignoreBaseCalls = value.getBoolValue();
								if (out.ignoreBaseCalls == null)
									Context.fatalError('Invalid value for ignoreBaseCalls', expr.pos);		
							case macro inlineBase = $value:
								out.inlineBase = value.getBoolValue();
								if (out.inlineBase == null)
									Context.fatalError('Invalid value for inlineBase', expr.pos);		
									
							case _:	
								Context.fatalError('Unknown parameter for @overwrite: ${expr.toString()}', meta.pos);
						}
						
						return true;
					});
					
				case "base":
					assertTypeWasNotSet();
					
					out.type = BASE;
				case "mixin":
					
					assertTypeWasNotSet();
					out.type = MIXIN;
					
				case "debug":
					out.debug = true;
					
				case _:
					return false;
			}
			
			return true;
		});
		
		return out;
	}
}