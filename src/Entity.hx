package;

import goap.WorldProperty;
import haxe.ds.StringMap;

class Entity extends Identified {
	public var name:String;
	public var properties:StringMap<WorldProperty>;

	public function new(name:String) {
		this.name = name;
		properties = new StringMap();
	}

	public function toString() {
		return 'Entity="' + name + '"';
	}

	public function clone():Entity{
		var e = new Entity(name);
		e.id = this.id;
		for(k in properties.keys()){
			var prop = properties.get(k).clone();
			prop.subject = e;
			e.properties.set(k, prop);
		}
		return e;
	}
}
