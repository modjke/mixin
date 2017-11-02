package cases.readme;
import haxe.unit.TestCase;

class LoggerTestCase extends TestCase
{

	public function new() 
	{
		super();
	}
	
	public function test()
	{
		var a = new A();
		var b = new B();
		assertEquals(0, 0);
	}
	
}

@mixin interface Logger {
    //adds public var to the base class
    public var loggingEnabled:Bool = true;
    //adds public function to the base class
    public function log(message:String):Void {
        if (loggingEnabled)
            trace(message);
    }
}

class A implements Logger {
    public function new() {
        //log("called A constructor");
    }
}

class B implements Logger {
    public function new() {
       // log("called B constructor");
    }
}