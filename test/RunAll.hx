package;
import cases.AutoImportsTestCase;
import cases.CopyTest;
import cases.ExtendingMixinsTestCase;
import cases.OneMixinForSeveralClassesTestCase;
import cases.OverwriteOverrideTestCase;
import cases.ResolvingFunctionTypeTestCase;
import cases.ShouldExtendImplementTestCase;
import cases.conflicts.MultipleOverwritesTestCase;
import cases.MixinTestCase;
import cases.OverwriteCase;
import cases.constructor.ConstructorTestCase;
import cases.readme.LoggerTestCase;
import cases.stateMachine.StateMachineTestCase;
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
		runner.add(new StateMachineTestCase());
		runner.add(new ResolvingFunctionTypeTestCase());
		runner.add(new ShouldExtendImplementTestCase());
		runner.add(new LoggerTestCase());
		runner.add(new ConstructorTestCase());
		
		var success = runner.run();
		
		Sys.exit(success ? 0 : 1);
		
	}
	
}
