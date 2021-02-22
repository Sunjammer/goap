package goap;

import goap.Planner.PossibilitySpace;
import goap.WorldProperty;

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

	public function apply(space:PossibilitySpace) {
		for (effect in effects)
			switch (effect) {
				case Prop(entity, key, value):
					new WorldProperty(entity, key, value).apply();
				case Spawn(e):
					space.entities.push(e);
				case Despawn(e):
					space.entities.remove(e);
				case TransformProp(entity, key, transform):
					var val = entity.properties.get(key).value;
					entity.properties.get(key).value = transform(val);
			}
	}

	public function toString():String {
		return '[Action="' + this.name + '"]';
	}
}
