package cases;
import haxe.unit.TestCase;

class MixinTestCase extends TestCase
{

	public function new() 
	{
		super();		
	}
	
	public function testBasic()
	{
		var o = new Object();
		assertEquals(o.baseProp, "overwritten base property");
		var i = cast(o, BasicMixin);
		assertEquals(i.baseProp, "overwritten base property");
	}
	
}

class Object implements BasicMixin
{
	public var baseProp(get, never):String;
	function get_baseProp() return "base property";
	
	var baseVar:Float = 0;
	public var pBaseVar:Float;
	
	function baseMethod():Void
	{
		
	}

	public function new()
	{
		trace("Constructor was called");
	}
}

@mixin interface BasicMixin
{
	
	//public variables and methods will become part of the interface
	//mixins are not allowed to changes access rules and initial values
	//mixins are not allowed to change methods arguments
		
	
	//private
	@mixin var mixinVar:Float = 0.0;	//mixin adds this private var, raises exception if base already have it (default)
	@base var baseVar:Float;			//base must have this private var, raises exception if base does not have it	
	
	@mixin var prop(get, never):String;
	function get_prop() return "";
	
	@base public var baseProp(get, never):String;
	@overwrite function get_baseProp() {
		return "overwritten " + base.get_baseProp();
	}
	
	
	//public
	@mixin public var pMixinVar:Float = 0.0;	//mixin adds this var, raises exception if base already have it (default)
	@base public var pBaseVar:Float;		//base must have this var, raises exception if base does not have it													
	

										
	@mixin function mixinMethod() {}			//mixin method, raises exception if base already have it (default)
	@base function baseMethod():Void;			//base must have this method, raises exception if base does not have it	
	@overwrite function overwriteMethod() {}	//similar to base, but allows mixin method to overwrite base's method, 'base.method()' calls base method	
	
	
	//constructor can be mixed in too
	//only @overwrite mode supported (default)
	//base should be called
	@overwrite public function new() {
		base();
	}
	
}