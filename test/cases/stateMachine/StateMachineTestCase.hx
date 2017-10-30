package cases.stateMachine;
import cases.stateMachine.StateMachineTestCase.State;
import haxe.unit.TestCase;

/**
 * Test Mixin<T> and type params inheritance
 */
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


@mixin interface StateMachine2<T,K> extends StateMachine<T,K>
{
	public function getCurrentState():T
	{
		return this.state;
	}
}

//mixin here is optional since we are not adding anything
@mixin interface ConcreteStateMachine<K> extends StateMachine2<State, K>
{
	
}

class GameObject implements ConcreteStateMachine<Int>
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