package cases.autoImports;

@mixin interface MixinWithImports 
{

	var field:SomeOtherClass<Int>;
	
	@base public function assertTrue(expr:Bool):Void;
	
	@overwrite public function new()
	{
		base();
		
		field = new SomeOtherClass(0);
	}
	
	public function testCreateOtherClass()
	{
		var o = new SomeOtherClass(5);
		
		assertTrue(o.getValue() == 5);
	}
	
	public function testFactory()
	{
		var factory = SomeOtherClass.new;
		assertTrue(factory(5));
	}
	
	public function getValueFromLocalVar(v:Int):Int
	{
		var some:SomeOtherClass<Int>;
		some = new SomeOtherClass(v);
		return some.getValue();
	}
	
	public function checkTyping():Bool
	{		
		return  Type.getClassName(SomeOtherClass) == "cases.autoImports.SomeOtherClass" &&
				Type.getClassName(cases.autoImports.SomeOtherClass) == "cases.autoImports.SomeOtherClass" &&
				Type.getClass(field) == "cases.autoImports.SomeOtherClass";
		
	}
	
	@mixin public function getValue():Int
	{
		return field.getValue();
	}

}