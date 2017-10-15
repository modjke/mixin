//-test1-/Found conflicting base|mixin metadata @conflict for field <method>/
package cases;

class MetaConflicts implements Mixin
{

	public static function main() {}
	
	#if test1
	@conflict(false)
	function method()
	{
		
	}
	#end
}

@mixin interface Mixin 
{
	#if test1
	@conflict(true)
	@overwrite 
	function method() {
		
	}
	#end
}