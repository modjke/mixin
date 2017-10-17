package cases;
import haxe.unit.TestCase;


class OverwriteCase extends TestCase
{

	public function new() 
	{
		super();
	}
	
	public function testPropertyGetterOverwrite()
	{
		var h = new ValueHolder(0);
		var val = h.value;
		assertTrue(val == 0);
		assertTrue(h.getValueCalls == 1);
	}
	
	public function testPropertySetterOverwrite()
	{
		var h = new ValueHolder(0);		
		h.value = 5;
		assertTrue(h.value == 5);
		assertTrue(h.setValueCalls == 1);
	}
	
	public function testMethodOverwrite()
	{
		var h = new ValueHolder(0);
		h.callIncrementValue(5);
		assertTrue(h.value == 5);
		assertTrue(h.incrementValueCalls == 5);
	}
}

class ValueHolder implements ValueHolderMixin
{
	@:isVar
	public var value(get, set):Int;
	
	function get_value():Int
	{
		return value;
	}
	
	function set_value(v:Int):Int
	{
		return value = v;
	}
	
	public function new(value:Int)
	{
		this.value = value;
	}
	
	public function incrementValue():Void
	{
		this.value++;
	}
}

@mixin interface ValueHolderMixin
{
	public var getValueCalls:Int = 0;
	public var setValueCalls:Int = 0;
	public var incrementValueCalls:Int = 0;
	
	@overwrite 
	function get_value():Int
	{
		return base.get_value();
	}
	
	@overwrite
	function set_value(v:Int):Int
	{
		return base.set_value(v);
	}
	
	@overwrite
	public function incrementValue():Void
	{
		base.incrementValue();		
	}
	
	public function callIncrementValue(times:Int):Void
	{
		while (times-- > 0)
			incrementValue();
	}
}