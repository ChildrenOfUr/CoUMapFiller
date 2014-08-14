part of CoUMapFiller;

Input playerInput;

class Input
{
	bool leftKey, rightKey, upKey, downKey, jumpKey;
	bool ignoreKeys = false;
	Map<String,int> keys = {"LeftBindingPrimary":65,"LeftBindingAlt":37,"RightBindingPrimary":68,"RightBindingAlt":39,"UpBindingPrimary":87,"UpBindingAlt":38,"DownBindingPrimary":83,"DownBindingAlt":40,"JumpBindingPrimary":32,"JumpBindingAlt":32,};
	
	Input()
	{
		leftKey = false;
		rightKey = false;
		upKey = false;
		downKey = false;
		jumpKey = false;
    }
	
	init()
	{
		querySelectorAll("input").onFocus.listen((_)
		{
			ignoreKeys = true;
		});
		querySelectorAll("input").onBlur.listen((_)
		{
			ignoreKeys = false;
		});
		
		document.onClick.listen((MouseEvent event)
		{
			Element target = event.target;
			if(target.className == "ExitLabel")
			{
				ScriptElement loadStreet = new ScriptElement();
				loadStreet.src = target.attributes['url'];
				playerTeleFrom = target.attributes['from'];
				document.body.append(loadStreet);
			}
			if(target.className == "placedEntity")
			{
				querySelector("#$currentLayer").style.cursor = "move";
                querySelector("#ToolBox").style.cursor = "move";
				unCrossOff(target);
				stopListener = querySelector("#ToolBox").onClick.listen((_) => stop(target));
				clickListener = getClickListener(target,event);
				moveListener = getMoveListener(target);
			}
		});
		
		Element tutorial = querySelector('#tutorial');
		tutorial.onMouseDown.listen((_)
    	{
    		tutorial.classes.remove("shadow");
    	});
        tutorial.onMouseUp.listen((_)
    	{
        	querySelector("#motdWindow").hidden = false;
    		tutorial.classes.add("shadow");
    	});
                    
		querySelector("#motdWindow .close").onClick.listen((_) => querySelector("#motdWindow").hidden = true);
		
		CheckboxInputElement collisions = querySelector("#collisionLines") as CheckboxInputElement;
		collisions.onChange.listen((Event event) => currentStreet.showLineCanvas());
		
		//Handle player input
	    //KeyUp and KeyDown are neccesary for preventing weird movement glitches
	    //keyCode's could be configurable in the future
	    document.onKeyDown.listen((KeyboardEvent k)
		{
	    	//check for delete key
	    	if(k.keyCode == 46)
	    	{
	    		clickListener.cancel();
	    		moveListener.cancel();
	    		querySelectorAll(".dashedBorder").forEach((Element element)
	    		{
	    			unCrossOff(element);
	    			element.remove();
	    			madeChanges = true;
	    		});
	    	}
	    	
	    	if ((k.keyCode == keys["UpBindingPrimary"] || k.keyCode == keys["UpBindingAlt"]) && !ignoreKeys) //up arrow or w and not typing
	    	{
	    		querySelectorAll(".dashedBorder").forEach((Element element)
				{
	    			if(k.shiftKey)
	    				flip(element);					
				});
	    		if(!k.shiftKey)
					upKey = true;
	    	}
			if ((k.keyCode == keys["DownBindingPrimary"] || k.keyCode == keys["DownBindingAlt"]) && !ignoreKeys) //down arrow or s and not typing
			{
	    		querySelectorAll(".dashedBorder").forEach((Element element)
				{
	    			if(k.shiftKey)
	    				flip(element);					
				});
	    		if(!k.shiftKey)
					downKey = true;
	    	}
			if ((k.keyCode == keys["LeftBindingPrimary"] || k.keyCode == keys["LeftBindingAlt"]) && !ignoreKeys) //left arrow or a and not typing
			{
	    		querySelectorAll(".dashedBorder").forEach((Element element)
				{
	    			if(k.shiftKey)
						rotate(element,-90);
				});
	    		if(!k.shiftKey)
					leftKey = true;
			}
			if ((k.keyCode == keys["RightBindingPrimary"] || k.keyCode == keys["RightBindingAlt"]) && !ignoreKeys) //right arrow or d and not typing
			{
	    		querySelectorAll(".dashedBorder").forEach((Element element)
				{
	    			if(k.shiftKey)
						rotate(element,90);
				});
	    		if(!k.shiftKey)
					rightKey = true;
			}
			if ((k.keyCode == keys["JumpBindingPrimary"] || k.keyCode == keys["JumpBindingAlt"]) && !ignoreKeys) //spacebar and not typing
				jumpKey = true;
	    });
	    
	    document.onKeyUp.listen((KeyboardEvent k)
		{
			if ((k.keyCode == keys["UpBindingPrimary"] || k.keyCode == keys["UpBindingAlt"]) && !ignoreKeys) //up arrow or w and not typing
				upKey = false;
			if ((k.keyCode == keys["DownBindingPrimary"] || k.keyCode == keys["DownBindingAlt"]) && !ignoreKeys) //down arrow or s and not typing
				downKey = false;
			if ((k.keyCode == keys["LeftBindingPrimary"] || k.keyCode == keys["LeftBindingAlt"]) && !ignoreKeys) //left arrow or a and not typing
				leftKey = false;
			if ((k.keyCode == keys["RightBindingPrimary"] || k.keyCode == keys["RightBindingAlt"]) && !ignoreKeys) //right arrow or d and not typing
				rightKey = false;
			if ((k.keyCode == keys["JumpBindingPrimary"] || k.keyCode == keys["JumpBindingAlt"]) && !ignoreKeys) //spacebar and not typing
				jumpKey = false;
	    });
	}
}