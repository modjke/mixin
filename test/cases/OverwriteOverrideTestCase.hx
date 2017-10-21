package cases;
import cases.OverwriteOverrideTestCase.Child;
import haxe.unit.TestCase;

class OverwriteOverrideTestCase extends TestCase
{

	public function new() 
	{
		super();
	}
	
	public function testOverwriteOverride()
	{
		var c = new Child();
		c.work();
		
		assertEquals(1, c.childWorked);
		assertEquals(1, c.superWorked);
		assertEquals(1, c.mixinWorked);
	}
}

class Super
{
	public var superWorked:Int = 0;
	public function work():Void {
		superWorked++;
	}
}

class Child extends Super implements OverwriteMixin
{
	public var childWorked:Int = 0;
	
	override public function work():Void 
	{
		super.work();
		
		childWorked++;
	}
	
	public function new()
	{
		
	}
}

@mixin interface OverwriteMixin
{
	public var mixinWorked:Int = 0;
	
	@overwrite public function work():Void
	{
		$base.work();
		mixinWorked++;
	}
}