package goap;

import goap.Action.ActionPredicate;
import goap.Planner.PossibilitySpace;
import goap.WorldProperty;

class Goal {
	public var name:String;
	public var requirement:ActionPredicate;
	public var evaluator:PossibilitySpace->Bool;

	public function new(name:String) {
		this.name = name;
	}

	public function toString():String {
		var header = '[Goal ' + this.name;
		// for(r in requirements){
		header += '\n\tRequirement: ' + requirement;
		// }
		/*if(requirements.length>0)
			header += '\n'; */
		return header + ']';
	}
}
