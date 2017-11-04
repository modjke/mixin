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