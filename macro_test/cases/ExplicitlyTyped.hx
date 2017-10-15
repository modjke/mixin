//-test1-/Mixin vars should be explicitly typed/
//-test2-/Mixin properties should be explicitly typed/
//-test3-/Mixin methods should be explicitly typed/
package cases;

class ExplicitlyTyped implements Mixin
{

	public static function main() {}
	
	public function new()
	{
		
	}
}

@mixin interface Mixin 
{
	#if test1
	var variable = 0.0;
	#end
	
	#if test2
	var prop(default, null) = 0.0;
	#end
	
	#if test3
	function method()
	{
		return 0.0;
	}
	#end
	
	//no type for constructor
	@overwrite public function new()
	{
		base();
	}
}