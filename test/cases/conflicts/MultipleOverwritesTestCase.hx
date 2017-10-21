package cases.conflicts;
import haxe.unit.TestCase;

class MultipleOverwritesTestCase extends TestCase
{

	public function new() 
	{
		super();
	}
	
	public function testConstructor()
	{
		var val = "initialized";
		var o = new Object(val);
				
		assertEquals(val, o.objectString);
		assertEquals(val, o.mixin1String);
		assertEquals(val, o.mixin2String);		
	}
	
	
	public function testMethod()
	{
		var o = new Object("");
		var v = "hey";
		o.changeValue(v);
		
		assertEquals(v, o.objectString);
		assertEquals(v, o.mixin1String);
		assertEquals(v, o.mixin2String);
	}
}


class Object implements Mixin2 implements Mixin1
{
	public var objectString(default, null):String = null;
	
	
	public function new(v:String)
	{
		objectString = v;
	}
	
	@multipleOverwrites(IGNORE)
	public function changeValue(v:String):Void
	{
		objectString = v;
	}
}

@mixin interface Mixin1
{
	public var mixin1String(default, null):String = null;

	@overwrite public function new(v:String)
	{
		$base();
		this.mixin1String = v;
	}
	
	@overwrite public function changeValue(v:String):Void
	{		
		$base.changeValue(v);
		this.mixin1String = v;
	}
}

@mixin interface Mixin2
{
	public var mixin2String(default, null):String = null;
	
	@overwrite public function new(v:String)
	{		
		$base();
		
		this.mixin2String = v;
	}
	
	@overwrite public function changeValue(v:String):Void
	{				
		$base.changeValue(v);
		
		this.mixin2String = v;		
	}
}