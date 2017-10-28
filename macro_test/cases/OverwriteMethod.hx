//-test1-/Field <method> does not satisfy @overwrite mixin interface/
//-test2-/Field <method> does not satisfy @overwrite mixin interface/
//-test3-/@overwrite mixin method <missing> not found in (.+), method will be included!/
package cases;

class OverwriteMethod implements Mixin
{

	public static function main() {}
	
	function method(arg:Int = 0):Int 
	{		
		#if test3
		missing();	//make sure method was included
		#end
		
		return 0;
	}
}

@mixin interface Mixin
{
	
	#if test1
	@overwrite function method():Void
	{
		
	}
	#end
	
	#if test2
	@overwrite function method(arg:Int):Int 
	{
		return 0;		
	}
	#end
	
	#if test3
	@overwrite public function missing():Void
	{
		
	}
	#end
}