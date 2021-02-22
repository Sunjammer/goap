import haxe.Json;
import goap.WorldProperty;
import goap.Goal;
import goap.Action;

using Lambda;

class Main {

	public static function main() {
		var ore = new Entity('ore');

		// World entities
		var miner = new Agent('miner');
		miner.properties.set('holding', new WorldProperty(miner, 'holding', Nothing));

		var chest = new Entity('Chest');
		chest.properties.set('orecount', new WorldProperty(chest, 'orecount', Int(0)));

		var pickaxe = new Entity('Pickaxe');

		// Actions
		var getPickaxe = new Action('Get pickaxe', 1);
		getPickaxe.predicates = [Prop(miner, 'holding', Nothing)];
		getPickaxe.effects = [Prop(miner, 'holding', Entity(pickaxe))];

		var kickRock = new Action('Kick rock', 4);
		kickRock.predicates = [Prop(miner, 'holding', Nothing)];
		kickRock.effects = [Spawn(ore)];

		var getOre = new Action('Get ore', 2);
		getOre.predicates = [Query(Some(ore)), Prop(miner, 'holding', Nothing)];
		getOre.effects = [Prop(miner, 'holding', Entity(ore)), Despawn(ore)];

		var dropItem = new Action('Drop item', 1);
		dropItem.predicates = [Prop(miner, 'holding', Anything)];
		dropItem.effects = [Prop(miner, 'holding', Nothing)];

		var mine = new Action('Mine', 2);
		mine.predicates = [Prop(miner, 'holding', Entity(pickaxe))];
		mine.effects = [Spawn(ore), Spawn(ore), Spawn(ore)];

		var placeOre = new Action('Place ore in chest', 2);
		placeOre.predicates = [Prop(miner, 'holding', Entity(ore))];
		placeOre.effects = [
			TransformProp(chest, 'orecount', (val) -> {
				return switch (val) {
					case Int(i):
						Int(i + 1);
					default:
						throw 'Blah!';
				}
			}),
			Prop(miner, 'holding', Nothing)
		];

		// Goal
		var chestMustBeFull = new Goal('Chest must contain 4 ores');
		chestMustBeFull.requirements = [Prop(chest, 'orecount', Int(4))];

		// Make a plan!
		var worldEntities = [miner, chest, pickaxe];
		var actions = [getPickaxe, dropItem, mine, getOre, placeOre];
		var plan = miner.planner.getPlans(worldEntities, actions, chestMustBeFull)[0];

		trace("Create plan for " + chestMustBeFull);
		trace(plan);
		//trace("Plan cost: " + plan.fold((action, count) -> count + action.cost, 0));
		/* [
			[Action="Get pickaxe"],
			[Action="Mine"],
			[Action="Drop item"],
			[Action="Get ore"],
			[Action="Place ore in chest"],
			[Action="Get ore"],
			[Action="Place ore in chest"],
			[Action="Get ore"],
			[Action="Place ore in chest"],
			[Action="Get pickaxe"],
			[Action="Mine"],
			[Action="Drop item"],
			[Action="Get ore"],
			[Action="Place ore in chest"]
		] */
	}
}
