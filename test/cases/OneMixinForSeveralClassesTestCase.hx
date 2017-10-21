package cases;
import haxe.unit.TestCase;


class OneMixinForSeveralClassesTestCase extends TestCase
{

	public function new() 
	{
		super();
	}
	
	public function test()
	{
		var a = new A();
		var b = new B();
		
		assertEquals(a.a, "a");
		assertEquals(b.b, "b");
	}
	
}

class A implements Defaults
{
	public var a(default, null):String;
	public function new() {
		setDefaults();
	}

	function setDefaults():Void
	{
		a = "a";
	}
}

class B implements Defaults
{
	public var b(default, null):String;
	public function new()
	{
		setDefaults();
	}
	
	function setDefaults():Void
	{
		b = "b";
	}
}

@mixin interface Defaults
{
	@overwrite 
	function setDefaults():Void
	{		
		$base.setDefaults();
	}
}