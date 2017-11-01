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
	
	public function testMixinTypeParam()
	{
		var testValue = 1000;
		function getTestValue() return testValue;
		
		setValue(getTestValue);
		assertEquals(testValue, getValue()());
		
		var complex = getComplex(5);
		assertEquals(5, complex.index);
		assertEquals(testValue, complex.value());
		
		var complexFunction = getComplexFunction();
		assertEquals(testValue, complexFunction()());
	}
	
	public function testInnerFunctioWithTypeParam()
	{
		var string = "hey, it's a string!";
		assertEquals(string, this.anotherType(string));
	}
}