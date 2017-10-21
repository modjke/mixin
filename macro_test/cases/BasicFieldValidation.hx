//-test1-/Mixin: static fields are not supported/
//-test2-/Mixin: override fields are not supported/
//-test3-/Mixin: macro fields are not supported/

package cases;

@mixin interface Mixin
{
	#if test1
	static var notAllowed:Float;
	#end
	
	#if test2
	override function notAllowed():Void {}
	#end
	
	#if test3
	macro function notAllowed() {}
	#end
}

class BasicFieldValidation implements Mixin
{

	public function new() 
	{
		
	}
	
}