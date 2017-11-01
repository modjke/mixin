package cases;
import cases.should.ShouldMixin;
import haxe.unit.TestCase;

class ShouldExtendImplementTestCase extends TestCase
	implements ShouldMixin
	implements SomeInterface
{

	public function new() 
	{
		super();
	}
	
	public function test()
	{
		assertEquals(0, 0);
	}
	
}