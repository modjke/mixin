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
import haxe.macro.Expr.Field;

using Lambda;

class FieldTools 
{

	public static function isMethod(f:Field):Bool
	{
		return switch (f.kind)
		{
			case FFun(_): true;
			case _: false;
		}
	}
	
	public static function isConstructor(f:Field):Bool
	{
		return f.name == "new";
	}
	
	public static function extractFFunFunction(f:Field):Function
	{
		return switch (f.kind)
		{
			case FFun(f): f;
			case _: throw 'Not a FFun field';			
		}
	}
	
	public static function replaceFFunFunction(f:Field, func:Function)
	{
		f.kind = switch (f.kind)
		{
			case FFun(_): FFun(func);
			case _: throw 'Not a FFun field';			
		}
	}
	
	public static function setExpr(f:Field, e:Expr)
	{
		f.kind = switch (f.kind)
		{
			case FVar(t, _): FVar(t, e);
			case FProp(get, set, t, _): FProp(get, set, t, e);
			case FFun(f): 
				FFun({
					args: f.args,
					ret: f.ret,
					params: f.params,
					expr: e
				});			
		};
	}
	
	public static function makeInline(f:Field)
	{
		if (f.access == null)
			f.access = [AInline]
		else if (!f.access.has(AInline))
			f.access.push(AInline);
	}
	
	public static function makePrivate(f:Field)
	{
		if (f.access == null) 
			f.access = [APrivate];
		else {
			f.access.remove(APublic);
			if (!f.access.has(APrivate))
				f.access.push(APrivate);
		}
		
	}
	
	public static function makeOverride(f:Field)
	{
		if (f.access == null)
			f.access = [AOverride];
		else 
			if (!f.access.has(AOverride))
				f.access.push(AOverride);
	}
}