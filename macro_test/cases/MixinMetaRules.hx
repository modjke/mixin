//-test1-/@base var can\'t have initializer/
//-test2-/@base property can\'t have initializer/
//-test3-/@base method can\'t have implementation/

//-test4-/@mixin method should have implementation \(body\)/

//-test5-/var can\'t be overwritten, makes no sense/
//-test6-/property can\'t be overwritten, but it\'s getter/setter can be/
//-test7-/@overwrite method should have implementation \(body\)/

//-test8-/Multiple field mixin types are not allowed/
package cases;

class MixinMetaRules implements Mixin
{

	public static function main() {}
	
}

@mixin interface Mixin
{
	#if test1
	@base var field = 0;
	#end
	
	#if test2
	@base var prop(default, null):String = "";
	#end
	
	#if test3
	@base function method():Int { return 0; }
	#end
	
	#if test4
	@mixin function method():Void;
	#end
	
	#if test5
	@overwrite var field:Int;
	#end
	
	#if test6
	@overwrite var prop(get, set):Int;
	#end
	
	#if test7
	@overwrite function method():Void;
	#end
	
	#if test8
	@mixin 
	@overwrite 
	function method():Void
	{
		
	}
	#end
}