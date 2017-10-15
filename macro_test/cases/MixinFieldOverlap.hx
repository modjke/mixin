//-test1-/@mixin field <overlapped> overlaps base field with the same name in (.*)/
//-test2-/@mixin field <overlapped> overlaps base field with the same name in (.*)/
//-test3-/@mixin field <overlapped> overlaps base field with the same name in (.*)/
package cases;

class MixinFieldOverlap implements Mixin
{

	var overlapped:Float;
	
	public static function main() {}
	
}

@mixin interface Mixin 
{
	#if test1
	@mixin var overlapped:Float;
	#end
	
	#if test2
	var overlapped:Float;
	#end
	
	#if test3
	function overlapped():Void {}
	#end
}