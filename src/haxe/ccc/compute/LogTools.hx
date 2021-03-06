package ccc.compute;

import haxe.Json;

import ccc.compute.Definitions;

class LogTools
{
	public static function removePrivateKeys<T>(val :T) :T
	{
		if (!Reflect.isObject(val)) {
			return val;
		} else {
			var copy :T = Json.parse(Json.stringify(val));
			stripAllKeys(copy, 'privateKey');
			stripAllKeys(copy, 'Key');
			stripAllKeys(copy, 'key');
			stripAllKeys(copy, 'ca');
			stripAllKeys(copy, 'cert');
			stripAllKeys(copy, 'password');
			return copy;
		}
	}

	public static function stripAllKeys(o :Dynamic, key :String)
	{
		try {
			if (o == null) {
				return;
			} else {
				for (f in Reflect.fields(o)) {
					if (f == key) {
						Reflect.deleteField(o, f);
					} else {
						var val = Reflect.field(o, f);
						var isObject = (untyped __typeof__(val)) == 'object';
						if (isObject) {
							stripAllKeys(val, key);
						}
					}
				}
			}
		} catch(err :Dynamic) {
			js.Node.process.stdout.write(Std.string(err) + '\n');
		}
	}
}