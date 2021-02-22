package goap;

import goap.Action.ActionPredicate;

using Lambda;

typedef Plan = {
	cost:Int,
	actions:Array<Action>
}

class PossibilitySpace {
	public var entities:Array<Entity>;
	public var actions:Array<Action>;

	public function new() {}

	public function clone():PossibilitySpace {
		var ps = new PossibilitySpace();
		ps.entities = entities.map(e -> e.clone());
		ps.actions = actions;
		return ps;
	}
}

class PlannerState {
	public var lastFailedAction:Action;
	public var currentStep:PlanStep;

	public function new() {}

	public function clone() {
		var p = new PlannerState();
		p.lastFailedAction = lastFailedAction;
		p.currentStep = currentStep;
		return p;
	}
}

typedef PlanStep = {
	action:Null<Action>,
	steps:Array<PlanStep>
}

class Planner {
	public function new() {}

	// Sweep a reasonable area around the agent for world states that can be reached and manipulated
	// Can this be done simply by breaking possibility searches when the cost exceeds N or does this mean we still have to traverse
	public function buildPossibilitySpace(entities:Array<Entity>, actions:Array<Action>):PossibilitySpace {
		var ps = new PossibilitySpace();
		ps.entities = entities.map(e -> e.clone());
		ps.actions = actions;
		return ps;
	}

	public function getPlans(worldEntities:Array<Entity>, actions:Array<Action>, goal:Goal):Array<Plan> {
		var out:Array<Plan> = [];
		var possibilities = buildPossibilitySpace(worldEntities, actions);

		var state:PlannerState = new PlannerState();
		state.currentStep = {
			action: null,
			steps: []
		};

		var planActions:Array<Action> = [];
		while (!goal.isComplete(possibilities)) {
			var nextStep = getNextStep(possibilities, goal, state);
			planActions.push(nextStep.action);
			trace("Applying " + nextStep);
			nextStep.action.apply(possibilities);
		}

		trace("Created plan");

		out.push({
			actions: planActions,
			cost: planActions.fold((a, sum) -> {
				return sum + a.cost;
			}, 0)
		});

		out.sort((a, b) -> {
			if (a.cost < b.cost)
				return -1;
			else if (a.cost > b.cost)
				return 1;
			return 0;
		});

		return out;
	}

	function resolveAction(space:PossibilitySpace, outcome:ActionPredicate, plannerState:PlannerState):PlanStep {
		trace("Looking for action that would result in outcome " + outcome);
		var matchedActions = [];
		for (a in space.actions) {
			for (eff in a.effects) {
				var matches:Bool = false;
				switch (eff) {
					case Despawn(entity):
						matches = outcome.equals(Query(None(entity)));
					case Spawn(entity):
						matches = outcome.equals(Query(Some(entity)));
					case Prop(entity, key, value):
						var wp = new WorldProperty(entity, key, value);
						switch (outcome) {
							case Prop(entity, key, value):
								matches = new WorldProperty(entity, key, value).compare(wp);
							case _:
						}
					case TransformProp(entity, key, transform):
						// Predict before commit
						var p = entity.properties.get(key).clone();
						var currentValue = p.value;
						p.value = transform(p.value);
						switch (outcome) {
							case Prop(entity, key, value):
								matches = new WorldProperty(entity, key, value).compare(p);
								if (!matches) {
									// Will this transform bring us *closer* to our desired outcome?
									var cvNum:Float = switch (currentValue) {
										case Int(i):
											cast i;
										case Float(i):
											i;
										default:
											0;
									}
									var nvNum:Float = switch (p.value) {
										case Int(i):
											cast i;
										case Float(i):
											i;
										default:
											0;
									}
									var goalNum:Float = switch (value) {
										case Int(i):
											cast i;
										case Float(i):
											i;
										default:
											0;
									}
									matches = goalNum - cvNum > goalNum - nvNum;
									if (matches)
										trace('\tTransform will bring numeric value closer to goal');
								}
							case _:
						}
				}
				if (matches) {
					matchedActions.push(a);
				}
			}
		}
		for (a in matchedActions) {
			trace('\t"' + a.name + '" matches desired outcome');
			if (a.predicates.length == 0) {
				// return a;
				return {
					action: a,
					steps: []
				};
			}
			for (pred in a.predicates) {
				// our new desired outcome is the first predicate of this action
				trace('\t"' + a.name + '" has predicate: ' + pred);
				var passed = true;
				switch (pred) {
					case Query(None(entity)):
						if (space.entities.contains(entity)) {
							passed = false;
						}
						trace('\t\t' + 'Pass');
					case Query(Some(entity)):
						if (!space.entities.contains(entity)) {
							passed = false;
						}
						trace('\t\t' + 'Pass');
					case Prop(entity, key, value):
						var prop = new WorldProperty(entity, key, value);
						if (!prop.isValid()) {
							trace("\tProp is not valid");
							passed = false;
						}
						trace('\t\t' + 'Pass');
				}
				if (!passed) {
					return resolveAction(space.clone(), pred, plannerState);
				}
			}
		}
		throw 'Could not resolve to desired outcome';
	}

	public function getNextStep(space:PossibilitySpace, goal:Goal, plannerState:PlannerState):PlanStep {
		var notResolved = goal.requirements.find(wp -> {
			switch (wp) {
				case Prop(entity, key, value):
					return !new WorldProperty(entity, key, value).isValid();
				case Query(Some(entity)):
					return !space.entities.contains(entity);
				case Query(None(entity)):
					return space.entities.contains(entity);
			}
		});
		return resolveAction(space, notResolved, plannerState);
	}
}
