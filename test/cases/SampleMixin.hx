package cases;
import cases.other.SomeOtherClass;



@mixin interface SampleMixin 
{

	var otherClass:SomeOtherClass;
	
	@overwrite public function new() 
	{
		base();
		
		this.otherClass = new SomeOtherClass(0);
		var factory = cases.other.SomeOtherClass.new;
		
		var some:SomeOtherClass;
		Type.getClass(SomeOtherClass);
		Type.getClass(cases.other.SomeOtherClass);
		var Some:SomeOtherClass = null;
		Type.getClass(Some);
		
		
		{
			
			var some:SOC;
			Type.getClass(SOC);
			Type.getClass(SomeOtherClass.SOC);
			var Some:SOC = null;
			Type.getClass(Some);
			
		}
	}
	
	public function getValue():Int
	{
		return otherClass.getValue();
	}
}