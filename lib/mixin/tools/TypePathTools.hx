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