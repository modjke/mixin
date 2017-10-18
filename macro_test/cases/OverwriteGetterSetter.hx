//-test1-/Overwriting a property getter for @:isVar property is not supported/
//-test2-/Overwriting a property setter for @:isVar property is not supported/
package cases;


class OverwriteGetterSetter implements Mixin
{

	@:isVar
	var value(get, set):Int;
	function get_value():Int return value;
	function set_value(v:Int):Int return value = v;
	
	public static function main() {}
	
}

@mixin interface Mixin
{
	#if test1
	@overwrite
	function get_value():Int
	{
		return base.get_value();
	}
	#end
	
	#if test2
	@overwrite
	function set_value(v:Int):Int
	{
		return base.set_value(v);
	}
	#end
	
}