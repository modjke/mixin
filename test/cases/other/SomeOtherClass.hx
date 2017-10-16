package cases.other;

typedef SOC = SomeOtherClass;

class SomeOtherClass 
{
	var value:Int;	
	
	public function new(value:Int) 
	{
		this.value = value;
	}
	
	public function getValue()
	{
		return value;
	}
	
}