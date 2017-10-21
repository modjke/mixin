package;
import cases.AutoImportsTestCase;
import cases.OneMixinForSeveralClassesTestCase;
import cases.conflicts.MultipleOverwritesTestCase;
import cases.MixinTestCase;
import cases.OverwriteCase;
import haxe.unit.TestRunner;


class RunAll 
{
	public static function main()
	{
		var runner = new TestRunner();
		
		runner.add(new AutoImportsTestCase());
		runner.add(new MixinTestCase());
		runner.add(new OverwriteCase());
		runner.add(new MultipleOverwritesTestCase());
		runner.add(new OneMixinForSeveralClassesTestCase());
		var success = runner.run();
		
		Sys.exit(success ? 0 : 1);
		
	}
	
}
