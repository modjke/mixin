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
		assertEquals(0, val);
		assertEquals(1, h.getValueCalls);
	}
	
	public function testPropertySetterOverwrite()
	{
		var h = new ValueHolder(0);		
		h.value = 5;
		assertEquals(5, h.value);
		assertEquals(1, h.setValueCalls);
	}
	
	public function testMethodOverwrite()
	{
		var h = new ValueHolder(0);
		h.callIncrementValue(5);
		assertEquals(5,h.value);
		assertEquals(5,h.incrementValueCalls);
	}
}

class ValueHolder implements ValueHolderMixin
{
	var _value:Int;
	public var value(get, set):Int;
	
	function get_value():Int
	{
		return _value;
	}
	
	function set_value(v:Int):Int
	{
	
		return _value = v;
	}
	
	public function new(value:Int)
	{
		this._value = value;
	}
	
	public function incrementValue():Void
	{
		this._value += 1;
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
		getValueCalls++;
		return base.get_value();
	}
	
	@overwrite
	function set_value(v:Int):Int
	{		
		setValueCalls++;
		return base.set_value(v);
	}
	
	@overwrite
	public function incrementValue():Void
	{
		incrementValueCalls++;
		base.incrementValue();		
	}
	
	public function callIncrementValue(times:Int):Void
	{
		while (times-- > 0)
			incrementValue();
	}
}