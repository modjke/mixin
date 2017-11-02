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
import haxe.macro.Expr.Metadata;
import haxe.macro.Expr.MetadataEntry;

using Lambda;

class MetadataTools 
{

	public static function hasMetaWithName(meta:Metadata, name:String):Bool
	{
		return meta != null && meta.exists(function (e) return e.name == name);
	}
	
	public static function getMetaWithName(meta:Metadata, name:String):MetadataEntry
	{
		return meta != null ? meta.find(function (e) return e.name == name) : null;
	}
	
	public static function cosumeParameters(meta:MetadataEntry, consumer:Expr->Bool)
	{
		if (meta.params != null)
			meta.params = meta.params.filter(function invert(p) return !consumer(p));
	}
	
	public static function consumeMetadata(meta:Metadata, consumer:MetadataEntry->Bool)
	{
		if (meta != null)
		{
			var i = meta.length;
			while (i-- > 0)
				if (consumer(meta[i]))
					meta.remove(meta[i]);
		}
	}
}