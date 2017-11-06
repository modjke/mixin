/*
Copyright (c) 2017 Ignatiev Mikhail (https://github.com/modjke) <ignatiev.work@gmail.com>

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

package mixin.tools;
import haxe.macro.Expr;

using haxe.macro.Tools;

class MoreExprTools 
{

	/**
	 * Prepends e to dst
	 */
	public static function prepend(dst:Expr, e:Expr)
	{
		dst.expr = switch (dst.expr)
		{
			case EBlock(exprs):
				exprs.unshift(e);
				EBlock(exprs);
			case _:
				(macro $b{[e, dst]}).expr;
		}
	}
	
	public static function setPos(e:Expr, pos:Position):Expr
	{
		return { 
			expr: e.expr,
			pos: pos
		}
	}
	
	public static function getBoolValue(e:Expr):Null<Bool>
	{
		try {
			var value = e.getValue();
			if (Std.is(value, Bool)) 
				return value;
				
		} catch (ignore:Dynamic) {}
		
		return null;
	}
}