package cases;
import cases.autoImports.MixinWithImports;
import haxe.PosInfos;
import haxe.unit.TestCase;

class AutoImportsTestCase extends TestCase implements MixinWithImports
{
	/**
	 * all tests are in the MixinWithImports
	 */
	public function new()
	{
		super();
	}
	
	override function assertTrue(b:Bool, ?c:PosInfos):Void 
	{				
		super.assertTrue(b, c);
	}
	
	override function assertEquals<T>(expected:T, actual:T, ?c:PosInfos):Void 
	{
		super.assertEquals(expected, actual, c);
	}
}


