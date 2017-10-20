package mixin.tools;
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
	
	
	
}