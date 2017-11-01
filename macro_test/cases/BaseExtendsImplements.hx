//-test1-/Mixin cases\.BaseExtendsImplements\.Test1 requires base class to implement/
//-test2-/Mixin cases\.BaseExtendsImplements\.Test2 requires base class to extend/
package cases;

class BaseExtendsImplements 
	#if test1 
	implements Test1
	#end
	#if test2
	implements Test2
	#end
{

	public static function main()
	{
		
	}
	
}

interface JustAnInterface
{
	
}

@baseImplements(cases.BaseExtendsImplements.JustAnInterface)
@mixin
interface Test1
{
	
}

@baseExtends(haxe.io.Path)
@mixin
interface Test2
{
	
}