package;
import haxe.macro.Compiler;
import haxe.macro.Expr.Field;

/**
 * ...
 * @author 
 */
class NewTypeOfMixin 
{
	public static function build():Array<Field>	
	{
		Compiler.addClassPath("mixin");
		return null;
	}
	
}