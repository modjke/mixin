package cases.autoImports;

typedef SOC<T> = SomeOtherClass<T>;

class SomeOtherClass<T> 
{
	var value:T;
	
	public function new(value:T) 
	{
		this.value = value;
	}
	
	public function getValue()
	{
		return value;
	}
	
}