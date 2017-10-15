//-test1-/Mixin only allowed to have @overwrite constructor/
//-test2-/Mixin only allowed to have @overwrite constructor/
//-test3-/Constructors with <return> statements can\'t be overwritten/
//-test4-/base\(\) constructor called more that once/
package cases;

class Constructor implements Mixin
{

	public static function main() {}
	
	
	function new()
	{
		#if test3
		return;
		#end
	}
	
}

@mixin interface Mixin 
{
	#if test1
	@base function new () {}
	#end
	
	#if test2
	@mixin function new() {}
	#end
	
	#if test3
	@overwrite function new() {
		base();
	}
	#end
	
	#if test4
	@overwrite function new() {
		base();
		base();
	}
	#end
	
}