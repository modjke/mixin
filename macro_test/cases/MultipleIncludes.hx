//-test1-/Mixin <cases.MultipleIncludes.Mixin> was already included in <cases.MultipleIncludes.SuperClass>/
package cases;

//when mixin included more that once in a hierarchy
class MultipleIncludes
	#if test1
	extends SuperClass
	#end
	
	implements Mixin 
	
{

	public static function main() {}
}

class SuperClass implements Mixin
{
	
}

@mixin interface Mixin
{
	
}