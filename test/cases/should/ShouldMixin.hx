package cases.should;

interface SomeInterface {
	
}

@mixin 
@baseExtends(haxe.unit.TestCase)
@baseImplements(cases.should.ShouldMixin.SomeInterface)
interface ShouldMixin 
{
	@overwrite public function new()
	{
		$base();
	}
	
	public function testTestCase():Void
	{
		assertEquals(0, 0);
	}
	
	public function testSomeInterface():Void
	{
		assertEquals(0, 0);
	}
}