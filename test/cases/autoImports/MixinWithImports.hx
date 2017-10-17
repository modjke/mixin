package cases.autoImports;
import haxe.PosInfos;

@mixin interface MixinWithImports 
{

	var field:SomeOtherClass<Int>;
	
	@base function assertTrue(b:Bool, ?c:PosInfos):Void;
	
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
	
	@mixin public function getValue():Int
	{
		return field.getValue();
	}

}