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
import haxe.macro.Context;
import haxe.macro.Expr.Field;

enum FieldMixinType
{
	MIXIN;
	BASE;
	OVERWRITE;
}

typedef MixinFieldMeta = {
	type: FieldMixinType,
	ignoreBaseCalls: Bool,
	inlineBase: Bool,
	debug: Bool,
	addIfAbsent: Bool
}

class MixinMeta 
{
	public static function consumeMixinFieldMeta(f:Field):MixinFieldMeta
	{
		var out:MixinFieldMeta = {
			type: MIXIN,
			ignoreBaseCalls: false,
			inlineBase: false,
			addIfAbsent: false,
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
							case macro addIfAbsent = $value:
								out.addIfAbsent = value.getBoolValue();
								if (out.addIfAbsent == null)
									Context.fatalError('Invalid value for addIfAbsent', expr.pos);
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