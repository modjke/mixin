package cases;
import cases.other.SomeOtherClass;



@mixin interface SampleMixin 
{

	var otherClass:SomeOtherClass<Int>;
	
	@overwrite public function new() 
	{
		base();
		
		this.otherClass = new SomeOtherClass(0);
		
		var factory = cases.other.SomeOtherClass.new;
		
		var some:SomeOtherClass<Int>;
		Type.getClass(SomeOtherClass);
		Type.getClass(cases.other.SomeOtherClass);
		var Some:SomeOtherClass<Int> = null;
		Type.getClass(Some);
		
		
		{
			
			var some:SOC<Int>;
			Type.getClass(SOC);
			Type.getClass(SomeOtherClass.SOC);
			var Some:SOC<Int> = null;
			Type.getClass(Some);
			
		}
		
	}
	
	public function getValue():Int
	{
		return otherClass.getValue();
	}
}