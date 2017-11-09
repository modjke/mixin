package cases.overwriteSetterParent;
import haxe.unit.TestCase;


class OverwriteSetterInParentTestCase extends TestCase
{

	public function new() 
	{
		super();
	}
	
	public function testSetterInParent()
	{
		var b = new B();
		b.multiplier = 5;
		b.v = 5;
		assertEquals(5 * 5, b.v);
	}
	
}

class A {
	@:isVar
	public var v(get, set):Int;
	
	function set_v(v:Int) return this.v = v;
	function get_v() return this.v;
}

class B extends A implements Nasty
{
	public function new() {
		
	}
}

@mixin interface Nasty {
	public var multiplier = 5;
	
	@overwrite(addIfAbsent = true) 
	function set_v(v:Int):Int {
		return $base.set_v(v * multiplier);
	}
}