package cases;
import cases.funcType.FuncTypesMixin;
import haxe.unit.TestCase;


class ResolvingFunctionTypeTestCase extends TestCase 
	implements FuncTypesMixin<Void->Int>
{

	public function new() 
	{
		super();
	}
	
	public function test()
	{
		setValue(getInt);
		assertEquals(0, getValue()());
	}
	
	function getInt():Int
	{
		return 0;
	}
}