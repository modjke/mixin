package cases.funcType;

typedef SomeTypedTypedef<T> = {
	value:T
}

@mixin interface FuncTypesMixin<T>
{

	var value:T;
	
	var complexValue: {>SomeTypedTypedef<T>,
		oneMoreValue:T
	};
	
	var moreComplexValue: {>SomeTypedTypedef<T>,
		complexValue: SomeTypedTypedef<T>
	};
	
	function setValue(v:T):Void
	{
		this.value = v;
	}
	
	function getValue():T
	{
		return this.value;
	}
	
	
	
	public function anotherType<T>(p:T):T
	{
		var k:T = p;
		return k;
	}
	 
	public function getComplexFunction():Void->T
	{
		return function ()
		{
			return this.value;
		};
	}
	
	
	public function getComplex(index:Int):{ value:T, index: Int }
	{
		var out: { value: T, index: Int } = {
			value: getValue(),
			index: index
		};
		
		function accept(value:T):T
		{
			out.value = value;
			return out.value;
		}
		
		function customTypeDecl<K>(kValue:K, tValue:T):K
		{
			return kValue;
		}
		
		customTypeDecl("String!", getValue());
		accept(getValue());
		
		return out;
	}
}