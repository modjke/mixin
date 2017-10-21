package cases;
import haxe.unit.TestCase;


@:build(cases.copy.CopyTestMacro.build())
class CopyTest extends TestCase
{

	public function new() 
	{
		super();		
	}
	
	public function test()
	{
		
		//does not really need to assert anything		
		//build macro will throw an error if something goes wrong
		//we fill this class with different expressions to copy with build macro
		
		assertTrue(true);
	}
	
	
	public function copyingThisMethodWillBeTestedInAMacro(t:TestCase, ?p:Float = 0.0, i:Int = -1):Null<Bool>	
	{
		try {
			var result = switch (p)
			{
				case 0.0: 1.0;
				case _: p + 2.0;
			};
			
			if (result < 0.0)
			{
				return t != null ? true : false;
			}
			
			function testMore() {
				var b = "testing more";
				return b;
			}
			
			var c:String = null;
			var a:Bool = true;
			
			return a;
		} catch (e:Dynamic)
		{
			trace("Hey ho");
			return false;
		}
	}
}