package cases.autoImports;
import haxe.PosInfos;

enum SomeEnum
{
	ONE(v:Int);
	TWO(v:Int);
}

@mixin interface MixinWithImports 
{

	var field:SomeOtherClass<Int>;
	
	@base function assertTrue(b:Bool, ?c:PosInfos):Void;
	@base function assertEquals<T>(expected:T, actual:T, ?c:PosInfos):Void;
	

	@overwrite public function new()
	{
		base();
		
		field = new SomeOtherClass(0);
	}
	
	public function testCreateOtherClass():Void
	{
		var o = new SomeOtherClass(5);
		
		assertTrue(o.getValue() == 5);
	}
	
	public function testFactory():Void
	{
		var factory = SomeOtherClass.new;
		assertTrue(factory(5).getValue() == 5);
	}
		
	public function testValueFromLocalVar():Void
	{
		var some:SomeOtherClass<Int>;
		var v:Int = 5;
		some = new SomeOtherClass(v);
		assertTrue(some.getValue() == v);
	}
	
	var vField:Int;
	public function testValueFromField():Void
	{
		vField = 5;
		var some = new SomeOtherClass(vField);
		assertTrue(vField == some.getValue());
	}
	
	public function testValueFromArg(v:Int):Void
	{
		assertTrue(new SomeOtherClass(v).getValue() == v);
	}
	
	public function testTyping():Void
	{		
		assertTrue(Type.getClassName(SomeOtherClass) == "cases.autoImports.SomeOtherClass");
		assertTrue(Type.getClassName(cases.autoImports.SomeOtherClass) == "cases.autoImports.SomeOtherClass");
		
	}
	
	public function testSwitch():Void
	{
		
		var someEnum:SomeEnum = SomeEnum.ONE(5);
		assertEquals(5, switch (someEnum)
		{
			case ONE(v): new SomeOtherClass(v).getValue();
			case TWO(v): new SomeOtherClass(v).getValue();
		});
		
		
	}
	
	@mixin public function getValue():Int
	{
		return field.getValue();
	}

}