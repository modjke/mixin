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
package mixin.io;
import haxe.ds.StringMap;
import sys.FileSystem;

class CachedFS 
{

	static var cache:StringMap<{ ?exists:Bool, ?isDirectory:Bool, ?entries:Array<String> }> = new StringMap();
	
	public static function exists(path:String):Bool {
		
		var cached = retrieve(path);
		
		if (cached.exists == null)
			cached.exists = FileSystem.exists(path);
			
		return cached.exists;
	}
	
	public static function isDirectory(path:String):Bool {
		var cached = retrieve(path);
		
		if (cached.isDirectory == null)
			cached.isDirectory = FileSystem.isDirectory(path);
			
		return cached.isDirectory;
	}
	
	public static function readDirectory(path:String):Array<String> {
		var cached = retrieve(path);
		
		if (cached.entries == null)
			cached.entries = FileSystem.readDirectory(path);
		
		return cached.entries;
	}
	
	inline static function retrieve(path:String)
	{
		var cached = cache.get(path);
		if (cached == null) {
			cached = {};
			cache.set(path, cached);
		}
		return cached;
	}
}