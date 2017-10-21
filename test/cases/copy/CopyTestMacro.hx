package cases.copy;
import haxe.macro.Context;
import haxe.macro.Expr.Field;
import haxe.macro.Printer;
import mixin.copy.Copy;


class CopyTestMacro 
{

	public static function build():Array<Field>
	{
		var printer = new Printer();
		for (original in Context.getBuildFields())
		{
			var copy = Copy.field(original);
		
			if (printer.printField(original) != printer.printField(copy))
				throw "Copy differs from original field";
		}
		
		return null;	//do not modify test class
	}
	
}