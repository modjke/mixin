package ;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

typedef Test =
{
	main:String,
	name:String,
	matcher:EReg,
	?stderr:String,
	?stdout:String
	
}

class MacroTestRunner 
{

	/**
	 * Runs every class from cases package with haxe	 	 
	 */
	public static function main()
	{
		var casesPath = 'macro_test/cases';
		var caseFiles = FileSystem.readDirectory(casesPath)
			.map(function (f) return Path.join([casesPath, f]));
			
		for (hxFile in caseFiles)
		{
			var content = File.getContent(hxFile);			
			var tests = extractTests(hxFile, content);
		
			if (tests.length == 0)
				Sys.println('Warning: no tests found in $hxFile');
				
			for (test in tests)
			{
				Sys.print('Running ${test.main} # ${test.name}...');

				if (runTest(test))
					Sys.println('OK');
				else {
					Sys.println('FAILED');
					Sys.println('');
					Sys.println('-- stdout:');
					Sys.println(test.stdout);
					Sys.println('');
					Sys.println('-- stderr:');
					Sys.println(test.stderr);
					Sys.exit(1);
				}
			}
		}
		
		Sys.exit(0);
	}
	
	
	static function runTest(test:Test)
	{
		var p = new Process("haxe", [
			'extraParams.hxml', 
			'-cp', 'lib', 
			'-cp', 'macro_test', 
			'-D', test.name,
			'-main', test.main, 
			'--interp']);

		test.stderr = p.stderr.readAll().toString();
		test.stdout = p.stdout.readAll().toString();

		return test.matcher.match(test.stderr);		
	}
	
	static function getFqlMain(hxFile:String, content:String)
	{
		var packRe = ~/package (.+);/;
		packRe.match(content);
		var pack = StringTools.trim(packRe.matched(1));
		var main = Path.withoutExtension(Path.withoutDirectory(hxFile));
		
		return pack.length > 0 ? pack + "." + main : main;
		
	}
	
	static function extractTests(hxFile:String, content:String):Array<Test>
	{
		var re = ~/\/\/-(\S+)-\/(.+)\/(.*)/;
		var main = getFqlMain(hxFile, content);
		var pos = 0;
		return [
			while (re.matchSub(content, pos))
			{
				pos = re.matchedPos().pos + re.matchedPos().len;
				
				var testName = re.matched(1);
				var erStr = re.matched(2);
				var erFlags = StringTools.trim(re.matched(2) != null ? re.matched(3) : "");
				erFlags = erFlags == "" ? "g" : erFlags;								
				
				{
					main: main,
					name: testName,
					matcher: new EReg(erStr, erFlags)
				}
				
				
			}
		];
	}
}