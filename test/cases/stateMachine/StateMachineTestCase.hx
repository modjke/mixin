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
		var gameObject = new GameObject();
		gameObject.update();
	}
	
}

enum State
{
	IDLE;
	PLAYING;
	GAME_OVER;
}

class GameObject implements StateMachine<State>
{	
	public function new()
	{
		switchState(IDLE);
	}
	
	function enterState(state:State, ?exitState:State):Void	
	{
		
	}
	
	function update()
	{
		switch (this.updateState())
		{
			case IDLE:
			case PLAYING:
			case GAME_OVER:
		}
	}
}