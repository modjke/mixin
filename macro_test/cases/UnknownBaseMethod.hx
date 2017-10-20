//-test1-/Unknown base field\:/
package cases;

@mixin interface Mixin
{
	function foo():Void
	{
		#if test1
		$base.unknown();
		#end
	}
}

class UnknownBaseMethod implements Mixin
{

	public static function main() {}
	
}