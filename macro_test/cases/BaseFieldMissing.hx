//-test1-/@base field <baseField> required by mixin not found in (.*)/
//-test2-/@base field <baseMethod> required by mixin not found in (.*)/

package cases;

class BaseFieldMissing implements Mixin
{

	public static function main() {}
	
}

@mixin interface Mixin 
{
	#if test1
	@base var baseField:Int;
	#end
	
	#if test2
	@base function baseMethod():Void;
	#end
}