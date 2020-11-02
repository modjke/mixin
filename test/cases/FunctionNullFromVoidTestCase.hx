package cases;
import haxe.unit.TestCase;



class FunctionNullFromVoidTestCase extends TestCase
{

	public function new() 
	{
		super();		
	}
	
	public function test()
	{
		var mixinImpl = new MixinImpl();

		//does not really need to assert anything		
		//build macro will throw an error if something goes wrong
		//we fill this class with different expressions to copy with build macro
		
		assertTrue(true);
  }
}


class MixinImpl implements SomeMixin {
	public function new() {
		update();
	}
}

@mixin interface SomeMixin {
	@overwrite(addIfAbsent=true) function update():Void {
		$base.update();
	}
}