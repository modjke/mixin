package mixin;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.ComplexType;

using haxe.macro.Tools;

enum TypeDef {
	VAR(name:String, type:ComplexType);
	METHOD(name:String, args:Array<FunctionArg>, ret:ComplexType);
}

class TypeStack 
{
	var stack:Array<Array<TypeDef>> = [];
	
	public static function levelFromFields(fields:Array<Field>):Array<TypeDef>
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
	
	public static function levelFromArgs(args:Array<FunctionArg>):Array<TypeDef>
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
	
	public function pushLevel(?level:Array<TypeDef>)
	{
		if (level == null) level = [];
		stack.push(level);
	}
	
	public function popLevel()
	{
		stack.pop();
	}
	
	public function wrap(e:Expr)
	{		
		var exprs:Array<Expr> = [
			for (level in stack)
				for (def in level)
				{
					switch (def)
					{
						case VAR(name, type): 
							{
								expr: ExprDef.EVars([{
									name: name,
									type: type,
									expr: null
								}]),
								pos: Context.currentPos()
							}
						case METHOD(name, args, ret): 
							var expr = macro return null;
							{							
								expr: ExprDef.EFunction(name, {
									args: args,
									ret: ret,
									expr: expr
								}),
								pos: Context.currentPos()
							}
					}
				}
		];
				
		
		exprs.push(e);
	
		var out = macro $b{exprs};
		return out;
	}
	
	function traceStack()
	{
		for (level in stack)
		{
			trace(level.map(getDefName).join(", "));			
		}
	}
	
	function getDefName(def:TypeDef):String
	{
		return switch(def)
		{
			case VAR(name, _): name;
			case METHOD(name, _, _): name;
		}
	}
}