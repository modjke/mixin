//-test1-/Field <field> does not satisfy mixin's interface/
//-test2-/Field <method> does not satisfy mixin's interface/
//-test3-/Field method should be public as requested by cases\.Mixin/
package cases;

class BaseFieldSatisfaction implements Mixin
{

	var field:Float;
	
	function method(arg:Int = 0):Int
	{
		return 0;
	}
	
	public static function main() {}
	
}

@mixin interface Mixin 
{
	#if test1
	@base var field:Int;
	#end
	
	#if test2
	//default value for arg is missing
	@base function method(arg:Int):Int;
	#end
	
	#if test3
	//method should be private
	@base public function method(arg:Int = 0):Int;
	#end
	
	
}