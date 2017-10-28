package mixin.typer.resolver;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.ComplexType;

using haxe.macro.Tools;


class VarStack 
{
	var stack:Array<Array<String>> = [];
	
	public static function levelFromArgs(args:Array<FunctionArg>):Array<String>
	{
		return [
			for (a in args)
				a.name
		];
		
	}
	
	

	public function new() 
	{
		
	}
	
	public function hasVarNamed(id:String):Bool {
		for (level in stack)
			for (def in level)
				if (id == def) return true;			
			
		
		return false;
	}
	
	public function addVar(name:String)
	{
		stack[stack.length - 1].push(name);
	}
	
	public function pushLevel(?level:Array<String>)
	{
		if (level == null) level = [];
		stack.push(level);
	}
	
	public function popLevel()
	{
		stack.pop();
	}
	
	function traceStack()
	{
		for (level in stack)
		{
			trace(level.join(", "));			
		}
	}
}