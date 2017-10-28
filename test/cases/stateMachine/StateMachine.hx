package cases.stateMachine;


@mixin interface StateMachine<T>
{

	@base function enterState(state:T, ?exitState:T):Void;
	
	var state:T = null;
	var pendingState:T = null;
	
	@overwrite public function new()
	{
		$base();	
	}
	
	function switchState(state:T):Void
	{
		pendingState = state;
	}
	
	function updateState():T
	{
		while (pendingState != null)
		{			
			var _exit = state; 
			state = pendingState;
			pendingState = null;
			
			enterState(state, _exit);			
		}
		
		return state;
	}
}