package cases;

@mixin interface SampleMixin 
{


	@overwrite public function new() 
	{
		base();
	}
	
	public function getValue():Int
	{
		return otherClass.getValue();
	}
}