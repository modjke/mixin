package cases;
import cases.ExtendingMixinsTestCase.MixinA;
import cases.ExtendingMixinsTestCase.MixinB;
import haxe.unit.TestCase;

class ExtendingMixinsTestCase extends TestCase
{

	public function new() 
	{
		super();
		
		
	}
	
	public function test()
	{
		var a = new ABC();
		assertEquals("a", a.a);
		assertEquals("b", a.b);
		assertEquals("c", a.c);
		
		
		
	}
	
}

class ABC implements MixinABC
{
	public var original:String = "original";
	
	
	public function new()
	{
		
	}
}

@mixin interface MixinABC extends MixinA extends MixinB extends MixinC
{
	
}

@mixin interface MixinB
{
	public var b:String;
	
	@base public var original:String;
	
	@overwrite public function new()
	{
		$base();
		
		b = "b";
	}
	
	public function modifyB():Void
	{
		original = "b";
	}
}

@mixin interface MixinA
{	
	public var a:String;
	
	@base public var original:String;
	
	@overwrite public function new()
	{
		$base();
		
		a = "a";
	}
	
	public function modifyA():Void
	{
		original = "a";
	}
}

@mixin interface MixinC
{
	public var c:String;
	
	@base public var original:String;
	
	@overwrite public function new()
	{
		$base();
		
		c = "c";
	}
	
	public function modifyC():Void
	{
		original = "c";
	}
}