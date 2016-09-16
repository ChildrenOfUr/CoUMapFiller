part of CoUMapFiller;

Input playerInput;

class Input
{
	bool leftKey, rightKey, upKey, downKey, jumpKey;
	bool ignoreKeys = false;
	DivElement zIndexDisplay;
	Element hoveredElement;
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
		
		document.onMouseDown.listen((MouseEvent event)
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
				removeHoverButtons();
				setCursorMove();
				unCrossOff(target);
				stopListener = querySelector("#ToolBox").onMouseUp.listen((_) => stop(target));
				clickListener = getClickListener(target,event);
				moveListener = getMoveListener(target);
			}
			if(target.id == "Report")
			{
				document.body.append(ReportWindow.create());
			}
		});
		
		document.onMouseOver.listen((MouseEvent event) {
			if(event.target is! Element || querySelector('.dashedBorder') != null) {
				return;
			}

			Element target = event.target;
			if(target.className == 'placedEntity') {
				if (hoveredElement == null) {
					addHoverButtons(target);
				}
			} else if(target.classes.contains('hoverButtonParent')) {
				addHoverButtons(target.parent);
			} else if(target.classes.contains('flipButton') || target.classes.contains('deleteButton')
				|| target.classes.contains('rotateLeftButton') || target.classes.contains('rotateRightButton')
			    || target.classes.contains('zUpButton') || target.classes.contains('zDownButton')) {
				addHoverButtons(target.parent.parent);
			} else {
				removeHoverButtons();
			}
		});
		
		CheckboxInputElement doNotShow = querySelector("#doNotShow") as CheckboxInputElement;
		doNotShow.onChange.listen((Event event) => window.localStorage['showTut'] = (!doNotShow.checked).toString());
       	querySelector('#tutorial').onClick.listen((_)
		{
			Element motdWindow = querySelector("#motdWindow");
			if(motdWindow.hidden)
				motdWindow.hidden = false;
			else
				motdWindow.hidden = true;
		});
		querySelector("#motdWindow .close").onClick.listen((_) => querySelector("#motdWindow").hidden = true);
		
		CheckboxInputElement collisions = querySelector("#collisionLines") as CheckboxInputElement;
		collisions.onChange.listen((Event event) => currentStreet.showLineCanvas());
		
        //Handle player input
	    //KeyUp and KeyDown are neccesary for preventing weird movement glitches
	    //keyCode's could be configurable in the future
	    document.onKeyDown.listen((KeyboardEvent k)
		{
			// space and arrow keys
			if(!ignoreKeys && (k.keyCode == 32 || k.keyCode == 37 || k.keyCode == 38 
				|| k.keyCode == 39 || k.keyCode == 40))
            	k.preventDefault();
			
	    	//check for delete key
	    	if(k.keyCode == 46)
	    		delete();
	    	
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
	
	void addHoverButtons(Element element)
	{
		removeHoverButtons(except:element);
		Element h = element.querySelector('.hoverButtonParent');
		if(h != null)
			return;
		
		DivElement hoverParent = new DivElement();
		num left = num.parse(element.style.left.replaceAll('px', '')) - 31;
		num top = num.parse(element.style.top.replaceAll('px', '')) - 31;
		num width = element.getBoundingClientRect().width + 62;
		num height = element.getBoundingClientRect().height + 62;
		if (width < 92) {
			width = 92;
		}
		if (height < 92) {
			height = 92;
		}
		
		hoverParent
			..className = "hoverButtonParent"
			..style.top = top.toString()+'px'
			..style.left = left.toString()+'px'
			..style.width = width.toString()+'px'
			..style.height = height.toString()+'px';

		DivElement flipButton = new DivElement()
			..className = 'hoverButton flipButton fa fa-arrows-h'
			..title = 'Flip Horizontally'
			..onClick.listen((_) => flip(element));
		DivElement rotateLeftButton = new DivElement()
			..className = 'hoverButton rotateLeftButton fa fa-rotate-left'
			..title = 'Rotate Left'
			..onClick.listen((_) => rotate(element,-90));
		DivElement rotateRightButton = new DivElement()
			..className = 'hoverButton rotateRightButton fa fa-rotate-right'
			..title = 'Rotate Right'
			..onClick.listen((_) => rotate(element,90));
		DivElement deleteButton = new DivElement()
			..className = 'hoverButton deleteButton fa fa-times'
			..title = 'Delete'
			..onClick.listen((_) => delete(element));
		DivElement zIndexUpButton = new DivElement()
			..className = 'hoverButton zUpButton fa fa-plus'
			..title = 'z-index up'
			..onClick.listen((_) => zIndex(element, 'up'));
		DivElement zIndexDownButton = new DivElement()
			..className = 'hoverButton zDownButton fa fa-minus'
			..title = 'z-index down'
			..onClick.listen((_) => zIndex(element, 'down'));
		zIndexDisplay = new DivElement()
			..className = 'zIndexDisplay'
			..text = element.style.zIndex;
		
		hoverParent..append(flipButton)..append(deleteButton)
				   ..append(rotateLeftButton)..append(rotateRightButton)
		           ..append(zIndexUpButton)..append(zIndexDisplay)..append(zIndexDownButton);

		element.parent.insertBefore(hoverParent, element);
		element.classes.add("dashedHoveredBorder");
		hoveredElement = element;
//		querySelector("#EntityHolder").append(hoverParent);
	}
	
	void removeHoverButtons({Element except : null})
	{
		hoveredElement?.classes?.remove('dashedHoveredBorder');
		hoveredElement = null;

		querySelectorAll('.hoverButtonParent').forEach((Element e)
		{
			if(e.parent != except)
				e.remove();
		});
	}
}
