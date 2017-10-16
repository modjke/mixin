package;
import cases.AutoImportsTestCase;
import cases.MixinTestCase;
import haxe.unit.TestRunner;



class RunAll 
{

	public static function main()
	{
		var runner = new TestRunner();
		
		runner.add(new AutoImportsTestCase());
		runner.add(new MixinTestCase());
		
		
		var success = runner.run();
		
		Sys.exit(success ? 0 : 1);
	}
	
}