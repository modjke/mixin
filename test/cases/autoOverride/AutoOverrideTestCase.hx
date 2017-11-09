package cases.autoOverride;
import cases.constructor.ConstructorTestCase.Mixin;
import haxe.unit.TestCase;

class AutoOverrideTestCase extends TestCase
{

	public function new()
	{
		super();
	}
	
	
	public function testWasCalled()
	{
		var b = new B();
		assertTrue(b.constructorCalled);
		assertEquals(10, b.foo(10));
		assertTrue(b.fooCalled);
	}
}

class A {
	public var constructorCalled:Bool = false;
	public var fooCalled:Bool = false;
	
	public function new() {
		constructorCalled = true;
	}
	
	public function foo(arg:Int = 0):Int {
		fooCalled = true;
		return arg;
	}
	
	public function typed<T>(arg:T):T {
		return arg;
	}
	
	var aVar:String;
}

class B extends A implements Mixin {
	
}

@mixin interface Mixin 
{
	@base var aVar:String;
	
	@overwrite(addIfAbsent=true) public function new() {
		$base();
	}
	
	@overwrite(addIfAbsent=true) public function foo(arg:Int = 0):Int {
		return $base.foo(arg);
	}
	
	@overwrite(addIfAbsent = true) 
	public function typed<T>(arg:T):T {
		return $base.typed(arg);
	}
	
	public function getAVar():String return aVar;
}