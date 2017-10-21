package;
import cases.AutoImportsTestCase;
import cases.CopyTest;
import cases.ExtendingMixinsTestCase;
import cases.OneMixinForSeveralClassesTestCase;
import cases.OverwriteOverrideTestCase;
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
		runner.add(new CopyTest());
		runner.add(new OverwriteOverrideTestCase());
		runner.add(new ExtendingMixinsTestCase());
		
		var success = runner.run();
		
		Sys.exit(success ? 0 : 1);
		
	}
	
}
