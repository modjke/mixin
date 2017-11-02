# Mixins for haxe 
Macro-powered [mixin](https://en.wikipedia.org/wiki/Mixin) system for haxe 3.4  
* *haxe 4.0 will be supported after a stable release*  
* *PRs/bug reports/feature requests are welcomed*

[![Build Status](https://travis-ci.org/modjke/mixin.svg?branch=master)](https://travis-ci.org/modjke/mixin)

## How to use
 1. Declare your mixin as interface with ```@mixin``` meta
 2. Inlcude mixins into your class by adding ```implements Mixin```

### Obligatory logger example

```haxe
@mixin interface Logger {
	var loggingEnabled:Bool = true;
	public function log(message:String):Void {
    	if (loggingEnabled)
        	trace(message);
    }
}

class A implements Logger {
	public function new() {
    	log("called A constructor");
    }
}

class B implements Logger {
	public function new() {
    	loggingEnabled = false;
    	log("called B constructor");
    }
}
```

Logger mixin adds ```private var loggingEnabled``` and ```public function log``` to every base class without need to extend it.
Also mixin's public field will become interface fields so casting to mixin and calling them is possible:
```haxe
var logger:Logger = new A(); 
logger.log("Hey");
```


## Features

##### Call base class method within mixin and vice versa

```haxe
@mixin interface Mixin {
	public function callBase():Void {
    	base();
    }
    
    function mixin():Void {
    	trace("mixin() called");
    }
}

class Object implements Mixin {
	public function callMixin() {
    	this.mixin();
    }
    
    function base() {
    	trace("base() called");
    }
}
```
Since including above mixin inside a class that have no base() method will result in compile-time error it is possible to require base class to have that method, keep reading :)

##### Base class requirements 
* ```@base``` field meta to require base class to have that field implemented (private or public) (no function body required)
* ```@baseExtends(superClass)``` mixin meta to make sure base class extends superClass
* ```@baseImplements(interface1, interface2, ...)``` mixin meta to make sure base class implements certain interfaces
```haxe
// base should extend flash.display.DisplayObject
@baseExtends(flash.display.DisplayObject)
// base should implement flash.display.IBitmapDrawable
@baseImplements(flash.display.IBitmapDrawable)
@mixin interface Mixin
{
	//also base should have this function
	@base public function getBitmapData():BitmapData;
}
```
##### Overwriting base methods

* Overwrite any base class method by adding ```@overwrite``` meta
* To call overwritten base method use ```$base.method()```
* ```$base.method()``` gets inlined by default (multiple returns is not allowed) - ```@overwrite(inlineBase=false)``` to disable
* Not calling base method will trigger an error, add ```@overwrite(ignoreBaseCalls=true)``` to suppress
* *Multiple mixins can overwrite the same method, if one of them is not calling base method behaviour is undefined*
```haxe
class Object implements Mixin {
	public function foo(arg:Int):Void {
    	//do something
    }
}
@mixin interface Mixin {
	@overwrite public function foo(arg:Int):Void {
    	//do smth
    	$base.foo(arg);		//call base class method
        //do more
    }
}
```

##### Overwriting getters / setters

* Overwriting getters and setters is similar to overwriting methods
* Overwriting getter or setter for ```@:isVar``` field is not allowed

```haxe
class Object implements VeryNastyMixin {
	var foo(default, set):Int;
    function set_foo(v:Int):Int {
    	return foo = v;
    }
}
@mixin interface VeryNastyMixin {
	// declaring base property is optional
	@base var foo(default, set):Int;	
    
	@overwrite function set_foo(v:Int):Int {   
    	v = Std.int(Math.random() * 1000);
    	return $base.set_foo(v);
    }
}
```

##### Overwriting constructor

* Constructor can be overwritten to perform some mixin initialisation
* Similar to overwriting methods but base constructor can be called only once as ```$base()```
* Overwriting constructors with return statements is not supported
```haxe
class Object implements Mixin {
	public function new() {
    	trace(mixinVar);	// traces "initialized"
    }
}
@mixin interface Mixin {
	var mixinVar:String;
	@overwrite public function new() {
    	mixinVar = "initialized";
    	$base();
    }
}
```

##### Merging (extending) mixins

* Mixins can extend other mixins (that merges them together)
* Interfaces can extend mixins (to alias certain collection of mixins)
* One mixin can be included in the 'extends' hierarchy only once

```haxe
@mixin interface Actor {}
@mixin interface KeanuReeves extends Actor {}
@mixin interface Driver {}
@mixin interface Killer {}
class JohnWick implements KeanuReeves implements Driver implements Killer {}
```

##### Typed mixins

* Typed mixins are very cool! :)
* Typed methods (function\<T\>) and constraints on type parameters are supported too.

```haxe
class Object implements Collection<String> {
	function createItem():String return "Item!";
    
    public function new() {
    	createCollection(100);
    }
}
@mixin interface Collection<T> {    
    @base function createItem():T;
        
   	var collection:Array<T>;
	public function createCollection(count:Int) {
    	collection = [for (i in 0...count) createItem()];
    }
}
```

## Limitations
* All mixin fields should be explicitly typed (same applies to base class fields if they declared as @base or @overwrite in a mixin)
* All @base & @overwrite methods should have the same arg names/arg types/arg defaults/return type as a base method
* Using ```using``` for mixin module is not supported
* Importing static functions is not supported
* import.hx is not *yet* supported (that said everything would work if you have the same import.hx for mixin and base class module, but in that case your mixin will depend on import.hx location)

## Lincese
Copyright (c) 2017 Ignatiev Mikhail (https://github.com/modjke) <ignatiev.work@gmail.com>
	

Permission is hereby granted, free of charge, to any person obtaining a copy  
of this software and associated documentation files (the "Software"), to deal  
in the Software without restriction, including without limitation the rights  
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell  
copies of the Software, and to permit persons to whom the Software is  
furnished to do so, subject to the following conditions:  

The above copyright notice and this permission notice shall be included in all  
copies or substantial portions of the Software.  
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR  
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER  
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE  
SOFTWARE.