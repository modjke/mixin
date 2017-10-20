//-test1-/Two mixins overwriting the same method can cause undefined behaviour/
package cases;

class MultipleOverwrites implements Mixin1 implements Mixin2
{
	public static function main() {}
	
	#if test1
	function method():Void
	{
		
	}
	#end
}


@mixin interface Mixin1
{
	#if test1
	@overwrite function method():Void
	{
		
	}
	#end
}

@mixin interface Mixin2
{
	#if test1
	@overwrite function method():Void
	{
		
	}
	#end
}