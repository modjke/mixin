package;
import cases.AutoImportsTestCase;
import cases.MixinTestCase;
import cases.OverwriteCase;
import haxe.unit.TestRunner;

#if !display
@:build(mixin.saver.ModuleToHx.saveAs("mixin.gen"))
#end

@:build(NewTypeOfMixin.build())
class RunAll 
{
	public static function main()
	{
		
		var runner = new TestRunner();
		
		runner.add(new AutoImportsTestCase());
		runner.add(new MixinTestCase());
		runner.add(new OverwriteCase());
		
		
		var success = runner.run();
		
		Sys.exit(success ? 0 : 1);
		
	}
	
}

typedef LolKek = RunAll;

class Topkek extends RunAll
{
	
}

interface TopLols {
	
}