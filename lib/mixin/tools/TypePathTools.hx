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
import haxe.macro.Expr.TypePath;


class TypePathTools 
{

	public static function toTypePath(s:String):TypePath
	{
		var pack = s.split(".");
		var hasSub = pack.length > 1 && ~/\b[A-Z]/.match(pack[pack.length - 2]);
		var sub = hasSub ? pack.pop() : null;
		var name = pack.pop();
		if (name.indexOf("<") != -1) throw "Parsing type path with type parameters is not implemented";
		
		return {
			pack: pack,
			sub: sub,
			name: name,
			params: []
		}
	}
	
	public static function toString(tp:TypePath, includeTypeParams:Bool)
	{
		var str = tp.pack.join(".") + (tp.pack.length > 0 ? "." + tp.name : tp.name);
		if (tp.sub != null) str += "." + tp.sub;
		if (includeTypeParams && tp.params != null && tp.params.length > 0)
		{
			str += "<" + tp.params.map(TypeParamTools.toString).join(",") + ">";
		}
		
		return str;
	}	

}