package armory.trait;

import iron.Trait;

class NavCrowd extends Trait {

    public function new() {
        super();

        notifyOnInit(init);
        notifyOnUpdate(update);
		notifyOnRemove(removed);
    }
	
	function removed() {

	}

    function init() {

    }

    function update() {
		
    }
}
