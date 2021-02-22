package goap;

import goap.Action;
import goap.Action.ActionPredicate;

using Lambda;

enum GoalCompletion {
	Complete;
	Progress;
	Failed;
}

typedef Plan = {
	cost:Int,
	actions:Array<Action>
}

class PossibilitySpace {
	public var entities:Array<Entity>;
	public var actions:Array<Action>;

	public function new() {}

	public function cloneEntities():Array<Entity> {
		return entities.map(e -> e.clone());
	}

	public function clone():PossibilitySpace {
		var ps = new PossibilitySpace();
		ps.entities = cloneEntities();
		ps.actions = actions;
		return ps;
	}
}

class PlannerState {
	public var currentNode:PlanNode;
	public var goal:Goal;
	public var ignoredPaths:Array<{a:Action, b:Action}>;
	public var complete:Bool = false;
	public var plans:Array<Plan>;
	public var currentPlan:Plan;

	public function new() {
		plans = [];
		ignoredPaths = [];
		currentPlan = {
			actions: [],
			cost: 0
		};
		plans.push(currentPlan);
	}
}

class PlanEdge {
	public var action:Action;
	public var target:PlanNode;

	public function new() {}
}

class PlanNode {
	public var state:Array<Entity>;
	public var edges:Array<PlanEdge>;

	public function new() {}
}

class Planner {
	static inline final DEBUG = true;

	static inline function log(msg) {
		if (DEBUG)
			trace(msg);
	}

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
		var possibilities = buildPossibilitySpace(worldEntities, actions);

		var state:PlannerState = new PlannerState();

		explore(possibilities, goal, state);

		state.plans = state.plans.map(p -> {
			p.cost = p.actions.fold((a, r) -> {
				return r + a.cost;
			}, 0);
			return p;
		});

		state.plans.sort((a, b) -> {
			if (a.cost < b.cost)
				return -1;
			else if (a.cost > b.cost)
				return 1;
			return 0;
		});

		return state.plans;
	}

	function testEffect(eff:ActionEffect, outcome:ActionPredicate) {
		switch (eff) {
			case Despawn(entity):
				return outcome.equals(Query(None(entity)));
			case Spawn(entity):
				return outcome.equals(Query(Some(entity)));
			case Prop(entity, key, value):
				var wp = new WorldProperty(entity, key, value);
				switch (outcome) {
					case Prop(entity, key, value):
						return new WorldProperty(entity, key, value).compare(wp);
					case _:
						return false;
				}
			case TransformProp(entity, key, transform):
				// Predict before commit
				var propKey = key;
				var propEntity = entity;
				var p = entity.properties.get(key).clone();
				var currentValue = p.value;
				p.value = transform(p.value);
				switch (outcome) {
					case Prop(entity, key, value):
						// Is this transform affecting the desired prop?
						if (entity != propEntity || propKey != key) {
							return false;
						} else {
							var matches = new WorldProperty(entity, key, value).compare(p);
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
								if (matches) {
									log('\t\tTransform will bring numeric value closer to goal');
									return true;
								}
							}
							return false;
						}
					case _:
				}
				return false;
		}
	}

	function testPredicate(pred:ActionPredicate, space:PossibilitySpace):Bool {
		switch (pred) {
			case Query(None(entity)):
				if (space.entities.find(e -> e.id == entity.id) != null) {
					log("\t\t\t" + space.entities);
					log("\t\t\tThere are entities of type " + entity);
					return false;
				}
			case Query(Some(entity)):
				if (space.entities.find(e -> e.id == entity.id) == null) {
					log("\t\t\t" + space.entities);
					log("\t\t\tThere are no entities of type " + entity);
					return false;
				}
			case Prop(entity, key, value):
				var prop = new WorldProperty(space.entities.find(e -> e.id == entity.id), key, value);
				if (!prop.isValid()) {
					log("\t\t\tProp is not valid for " + entity + ":" + key + "=" + value);
					return false;
				}
			case Dynamic(func):
				return func(space);
		}
		return true;
	}

	function resolveOutcome(space:PossibilitySpace, outcome:ActionPredicate, plannerState:PlannerState):Bool {
		Sys.sleep(0.15);
		log("Looking for action that would result in outcome " + outcome);
		var matchedActions = [];
		for (a in space.actions) {
			// log('\tInspecting action "' + a.name + '"');
			var matches:Bool = false;
			for (eff in a.effects) {
				if (matches)
					break;
				matches = testEffect(eff, outcome);
			}
			if (matches) {
				matchedActions.push(a);
			}
		}

		if (matchedActions.length == 0)
			return false;

		var firstAction = matchedActions.shift();
		log('\t\t"' + firstAction.name + '" matches desired outcome');
		for (pred in firstAction.predicates) {
			log('\t\tTesting predicate ' + pred);
			var passed = testPredicate(pred, space);
			if (passed) {
				log('\t\t\t' + 'Predicate passed');
			} else {
				log('\t\t\t' + 'Predicate not passed');
				if (!resolveOutcome(space, pred, plannerState)) {
					throw "Couldn't solve predicate";
				}
			}
		}
		if (matchedActions.length > 0) {
			log("Applying " + firstAction + " (There are alternative paths that have not been explored " + matchedActions + ")");
		} else {
			log("Applying " + firstAction);
		}
		plannerState.currentPlan.actions.push(firstAction);
		firstAction.apply(space.entities);
		return true;
	}

	function getGoalCompletion(space:PossibilitySpace, goal:Goal):GoalCompletion {
		if (testPredicate(goal.requirement, space)) {
			return Complete;
		}
		if (goal.evaluator != null)
			if (goal.evaluator(space))
				return Progress;
		return Failed;
	}

	public function explore(space:PossibilitySpace, goal:Goal, plannerState:PlannerState):Void {
		var didSomething = resolveOutcome(space, goal.requirement, plannerState);
		if (!didSomething)
			throw 'Foo';

		trace("Done");
		switch (getGoalCompletion(space, goal)) {
			case Complete:
				trace("Completed successfully");
			case Progress:
				return explore(space, goal, plannerState);
			case Failed:
				throw 'Failed to find solution';
		}
	}
}
