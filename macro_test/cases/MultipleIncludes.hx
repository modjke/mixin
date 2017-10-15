//-test1-/Mixin <cases.MultipleImplements.Mixin> was already included in <cases.MultipleImplements.SuperClass>/
//-test2-/Mixin <cases.MultipleImplements.Mixin> was already included in <cases.MultipleImplements>/
package cases;

//when mixin included more that once in a hierarchy
class MultipleIncludes
	#if test1
	extends SuperClass
	#end
	
	#if test2
	implements Mixin	
	#end
	
	implements Mixin 
	
{

	public function new() 
	{
		
	}
	
}

class SuperClass implements Mixin
{
	
}

@mixin interface Mixin
{
	
}