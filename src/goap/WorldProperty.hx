package goap;

enum WorldPropValue {
	Int(i:Int);
	Float(f:Float);
	Bool(b:Bool);
	Entity(e:Entity);
	Anything;
	Nothing;
}

class WorldProperty {
	public var subject:Entity;
	public var key:String;
	public var value:WorldPropValue;

	public function new(subject:Entity, key:String, value:WorldPropValue) {
		this.subject = subject;
		this.key = key;
		this.value = value;
	}

	public function compare(other:WorldProperty):Bool {
		return other.subject == subject && other.key == key && other.value.equals(value);
	}

	public function toString():String {
		return "[Prop " + subject + ", '" + key + "'='" + value + "']";
	}

	public function apply() {
		var prop = subject.properties.get(key);
		prop.value = value;
	}

	public function isValid():Bool {
		switch (value) {
			case Nothing:
				return !subject.properties.exists(key) || subject.properties.get(key) == null || subject.properties.get(key).value == Nothing;
			case Anything:
				return subject.properties.exists(key) && subject.properties.get(key) != null;
			default:
				var prop = subject.properties.get(key).value;
				return prop.equals(value);
		}
	}

	public function clone():WorldProperty {
		return new WorldProperty(subject, key, value);
	}
}
