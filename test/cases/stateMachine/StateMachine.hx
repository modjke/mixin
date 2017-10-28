package cases.stateMachine;


@mixin interface StateMachine<T>
{
	@base function enterState(state:T, ?exitState:T):Void;
	
	var state:T = null;
	var pendingState:T = null;
	
	@overwrite public function new(initial:T)
	{
		$base(initial);	
	}
	
	function switchState(state:T):Void
	{
		pendingState = state;
	}
	
	function updateState():T
	{
		while (pendingState != null)
		{			
			var _exit:T = state; 
			state = pendingState;
			pendingState = null;
			
			enterState(state, _exit);			
		}
		
		return state;
	}
	
}