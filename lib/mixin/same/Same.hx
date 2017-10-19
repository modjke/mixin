package mixin.same;
import haxe.macro.ComplexTypeTools;
import haxe.macro.Expr;
import haxe.macro.Expr.Access;
import haxe.macro.Expr.ComplexType;
import haxe.macro.Expr.FunctionArg;
import haxe.macro.Expr.Metadata;
import haxe.macro.Expr.TypeParam;
import haxe.macro.Expr.TypeParamDecl;
import mixin.typer.Typer;

using haxe.macro.Tools;
using mixin.tools.MoreComplexTypeTools;

@:publicFields
class Same 
{
	static function functionArgs(a:Array<FunctionArg>, b:Array<FunctionArg>):Bool
	{	
		return arrays(a, b, function(a, b)
		{
			return  a.name == b.name &&
					a.opt == b.opt &&
					metadatas(a.meta, b.meta) &&					
					complexTypes(a.type, b.type) &&
					exprs(a.value, b.value);
		});
	}
	
	static function metadatas(a:Metadata, b:Metadata)
	{
		return arrays(a, b, metaEntries);
	}
	
	static function metaEntries(a:MetadataEntry, b:MetadataEntry)
	{
		return a.name == b.name &&
			   arraysOfExpr(a.params, b.params);
	}
	
	static function access(a:Array<Access>, b:Array<Access>, ignore:Array<Access>)
	{
		var ac = a.copy().filter(function (a) return ignore.indexOf(a) == -1);
		var bc = b.copy().filter(function (a) return ignore.indexOf(a) == -1);
		return arrays(ac, bc, function(a, b)
		{
			return a.equals(b);
		});
	}
	
	static function typeParams(a:Array<TypeParam>, b:Array<TypeParam>)
	{
		return arrays(a, b, function(a, b)
		
			return switch [a, b]
			{
				case [TPType(at), TPType(bt)]: complexTypes(at, bt);
				case [TPExpr(ae), TPExpr(be)]: exprs(ae, be);
				case [_, _]: false;				
			});
	}
	
	static function typeParamDecls(?a:Array<TypeParamDecl>, ?b:Array<TypeParamDecl>)
	{
		if (a != null && a.length > 0 || b != null && b.length > 0) {
			throw 'TypeParams are not yet supported';
		}
		return true;
	}
	
	static function complexTypes(a:ComplexType, b:ComplexType)
	{		
		//TODO: find a better way
		return  a.safeToString() == 
				b.safeToString();
	}
	
	static function exprs(?a:Expr, ?b:Expr)
	{
		//TODO: find a better way
		return a.toString() == b.toString();
	}
	
	static function arraysOfExpr(?a:Array<Expr>, ?b:Array<Expr>)
	{
		return arrays(a, b, exprs);
	}
	
	static function stringArrays(?a:Array<String>, ?b:Array<String>)
	{
		return arrays(a, b, function(a, b) return a == b);
	}
	
	static function arrays<T>(?a:Array<T>, ?b:Array<T>, compare:T->T->Bool):Bool
	{		
		if (a.length == b.length)
		{			
			for (i in 0...a.length)
				if (!compare(a[i], b[i]))
					return false;
					
			return true;
		}
		
		return false;
	}
}