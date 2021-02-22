package;
import goap.*;

class Agent extends Entity{
    public var planner:Planner;
    public function new(name:String){
        super(name);
        planner = new Planner();
    }
}