package;
import haxe.macro.Compiler;
import haxe.macro.Expr.Field;


class NewTypeOfMixin 
{
	public static function build():Array<Field>	
	{
		Compiler.addClassPath("mixin.gen");
		return null;
	}
	
}