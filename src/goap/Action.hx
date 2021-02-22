package goap;

import goap.Planner.PossibilitySpace;
import goap.WorldProperty;
using Lambda;

typedef ActionMetrics = {
	isValid:Bool
};

enum QueryArg {
	Some(entity:Entity); // replace these refs with types
	None(entity:Entity); // replace these refs with types
}

enum ActionPredicate {
	Prop(entity:Entity, key:String, value:WorldPropValue);
	Query(arg:QueryArg);
	Dynamic(func:PossibilitySpace->Bool);
}

enum ActionEffect {
	Spawn(entity:Entity);
	Despawn(entity:Entity);
	Prop(entity:Entity, key:String, value:WorldPropValue);
	TransformProp(entity:Entity, key:String, transform:WorldPropValue->WorldPropValue);
}

class Action extends Identified {
	public var predicates:Array<ActionPredicate>;
	public var effects:Array<ActionEffect>;
	public var name:String;
	public var cost:Int = 0;

	public function new(name:String, cost:Int = 0) {
		effects = [];
		predicates = [];
		this.name = name;
		this.cost = cost;
	}

	public function apply(entities:Array<Entity>) {
		for (effect in effects)
			switch (effect) {
				case Prop(entity, key, value):
					var e = entities.find(e -> e.id == entity.id);
					new WorldProperty(e, key, value).apply();
				case Spawn(e):
					entities.push(e);
				case Despawn(e):
					entities.remove(e);
				case TransformProp(entity, key, transform):
					var e = entities.find(e -> e.id == entity.id);
					var val = e.properties.get(key).value;
					e.properties.get(key).value = transform(val);
			}
	}

	public function toString():String {
		return '[Action="' + this.name + '"]';
	}
}
