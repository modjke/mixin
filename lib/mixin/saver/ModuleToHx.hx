package mixin.saver;
import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr.Field;
import sys.FileSystem;
import sys.io.File;

using StringTools;
using haxe.macro.Tools;

class ModuleToHx 
{

	public static function saveAs(cp:String):Array<Field>
	{
		var module = Context.getLocalModule();
		var modulePath = Context.getPosInfos(Context.currentPos()).file;		
		var newModulePath = Path.join([ Path.normalize(cp), Path.withExtension(module.replace(".", "/"), "hx") ]);
		
		

		return null;
	}
	
	static function addAutoGenWarn(src:StringBuf)
	{
		
	}
	
	static function addImports(src:StringBuf)
	{
		
	}
	
}