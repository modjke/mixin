package cases.stateMachine;
import cases.stateMachine.StateMachineTestCase.State;
import haxe.unit.TestCase;

class StateMachineTestCase extends TestCase
{

	public function new() 
	{
		super();
	}
	
	public function testStateMachine()
	{
		var gameObject = new GameObject(IDLE);
		gameObject.update();
		
		assertEquals(IDLE, gameObject.enteredState);
	}
	
}

enum State
{
	IDLE;
	PLAYING;
	GAME_OVER;
}


//mixin here is optional since we are not adding anything
@mixin interface ConcreteStateMachine extends StateMachine2<State>
{
	
}

@mixin interface StateMachine2<T> extends StateMachine<T>
{
	public function getCurrentState():T
	{
		return this.state;
	}
}

class GameObject implements ConcreteStateMachine
{	
	public var enteredState:State = null;
	
	public function new(initial:State)
	{
		switchState(initial);
	}
	
	function enterState(state:State, ?exitState:State):Void	
	{
		this.enteredState = state;
	}
	
	public function update()
	{
		switch (this.updateState())
		{
			case IDLE:
			case PLAYING:
			case GAME_OVER:
		}
	}
}