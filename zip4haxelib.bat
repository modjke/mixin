@echo off
del haxelib.zip
7z.exe a haxelib.zip README.md haxelib.json extraParams.hxml lib 
haxelib submit haxelib.zip
del haxelib.zip