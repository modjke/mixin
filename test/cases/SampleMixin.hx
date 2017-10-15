package cases;
import cases.other.SomeOtherClass;



@mixin interface SampleMixin 
{

	var otherClass:SomeOtherClass;
	
	@overwrite public function new() 
	{
		base();
		
		this.otherClass = new SomeOtherClass(0);
	}
	
	public function getValue():Int
	{
		return otherClass.getValue();
	}
}