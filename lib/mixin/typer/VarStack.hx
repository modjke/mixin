package mixin.typer;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.ComplexType;

using haxe.macro.Tools;

enum VarDef {
	VAR(name:String, type:ComplexType);
	METHOD(name:String, args:Array<FunctionArg>, ret:ComplexType);
}

class VarStack 
{
	var stack:Array<Array<VarDef>> = [];
	
	public static function levelFromFields(fields:Array<Field>):Array<VarDef>
	{
		return [
			for (f in fields)
			{
				switch (f.kind)
				{				
					case FVar(t, e): 
						VAR(f.name, t);
					case FProp(get, set, t, e):
						VAR(f.name, t);
					case FFun(fun): 
						METHOD(f.name, fun.args, fun.ret);
				}
			}
		];
	}
	
	public static function levelFromArgs(args:Array<FunctionArg>):Array<VarDef>
	{
		return [
			for (a in args)
				VAR(a.name, a.type)
		];
		
	}
	
	

	public function new() 
	{
		
	}
	
	public function hasIdentifier(id:String):Bool {
		for (level in stack)
			for (def in level)
				if (id == getDefName(def)) return true;			
			
		
		return false;
	}
	
	public function addVar(name:String, type:ComplexType)
	{
		stack[stack.length - 1].push(VAR(name, type));
	}
	
	public function pushLevel(?level:Array<VarDef>)
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
			trace(level.map(getDefName).join(", "));			
		}
	}
	
	function getDefName(def:VarDef):String
	{
		return switch(def)
		{
			case VAR(name, _): name;
			case METHOD(name, _, _): name;
		}
	}
}