package cases.funcType;


@mixin interface FuncTypesMixin<T>
{

	var value:T;
	function setValue(v:T):Void
	{
		this.value = v;
	}
	
	function getValue():T
	{
		return this.value;
	}
	
}