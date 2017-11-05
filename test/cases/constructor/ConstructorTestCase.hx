package cases.constructor;
import haxe.unit.TestCase;

class ConstructorTestCase extends TestCase
{

	public function new() 
	{
		super();
	}
	
	public function testConstructors()
	{
		var v = "hey :)";
		
		assertEquals(v, new A(v).mixinValue);
		assertEquals(v, new B(v).mixinValue);		
	}
	
}

class A implements Mixin {
	public function new(value:String)
	{		
	}
}

class B implements Mixin {
	
}

@mixin interface Mixin {
	public var mixinValue:String;
	
	@overwrite(addIfAbsent = true)
	public function new(value:String)
	{
		$base();
		
		mixinValue = value;
	}
}