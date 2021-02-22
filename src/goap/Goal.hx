package goap;

import goap.Action.ActionPredicate;
import goap.Planner.PossibilitySpace;
import goap.Action.QueryArg;
import goap.WorldProperty;

class Goal {
	public var name:String;
	public var requirements:Array<ActionPredicate>;

	public function new(name:String) {
		this.name = name;
	}

	public function toString():String {
		var header = '[Goal ' + this.name;
		for(r in requirements){
			header += '\n\tRequirement: '+r;
		}
		if(requirements.length>0)
			header += '\n';
		return header + ']';
	}

	public function isComplete(space:PossibilitySpace):Bool {
		for (o in requirements) {
			switch (o) {
				case Prop(entity, key, value):
					if (!new WorldProperty(entity, key, value).isValid())
						return false;
				case Query(arg):
					switch (arg) {
						case Some(entity):
							if (!space.entities.contains(entity)) return false;
						case None(entity):
							if (space.entities.contains(entity)) return false;
					}
			}
		}
		return true;
	}
}
