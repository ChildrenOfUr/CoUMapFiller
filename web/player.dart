part of CoUMapFiller;

Player CurrentPlayer;

class Player
{
	int width = 116, height = 137, speed = 300;
	num posX = 1.0, posY = 300.0;
	num yVel = 0, yAccel = -2400;
	bool jumping = false, moving = false, climbingUp = false, climbingDown = false;
	bool activeClimb = false, facingRight = true, firstRender = true;
	Map<String,Animation> animations = new Map();
	Animation currentAnimation;
	Random rand = new Random();
	String intersectingObject = null;
  		
	//for testing purposes
	//if false, player can move around with wasd and arrows, no falling
	bool doPhysicsApply = true;
  
	DivElement playerParentElement;
	CanvasElement playerCanvas;
	DivElement playerName;
  
	Player([String name])
	{
		playerCanvas = new CanvasElement()
			..style.transform = "translateZ(0)";
		
		playerName = new DivElement()
			..classes.add("playerName")
			..text = "tester";
				
		playerParentElement = new DivElement()
			..classes.add("playerParent")
			..style.width = width.toString() + "px"
			..style.height = height.toString() + "px";
		
		playerParentElement.append(playerName);
		playerParentElement.append(playerCanvas);
		gameScreen.append(playerParentElement);
	}
	
	Future<List<Animation>> loadAnimations()
	{
		//need to get background images from some server for each player based on name
		List<int> idleFrames=[], baseFrames=[], jumpUpFrames=[], fallDownFrames, landFrames, climbFrames=[];
		for(int i=0; i<57; i++)
			idleFrames.add(i);
		for(int i=0; i<12; i++)
        	baseFrames.add(i);
		for(int i=0; i<16; i++)
            jumpUpFrames.add(i);
		for(int i=0; i<19; i++)
			climbFrames.add(i);
		fallDownFrames = [16,17,18,19,20,21,22,23];
		landFrames = [24,25,26,27,28,29,30,31,32];
				
		animations['idle'] = new Animation("./assets/sprites/idle.png","idle",2,29,idleFrames,loopDelay:new Duration(seconds:10),delayInitially:true);
		animations['base'] = new Animation("./assets/sprites/base.png","base",1,15,baseFrames);
		animations['jumpup'] = new Animation("./assets/sprites/jump.png","jumpup",1,33,jumpUpFrames);
		animations['falldown'] = new Animation("./assets/sprites/jump.png","falldown",1,33,fallDownFrames);
		animations['land'] = new Animation("./assets/sprites/jump.png","land",1,33,landFrames);
				
		List<Future> futures = new List();
		animations.forEach((String name,Animation animation) => futures.add(animation.load()));
		
		return Future.wait(futures);
	}
  
	update(double dt)
	{	
		num cameFrom = posY;
		
		if(playerInput.rightKey == true)
		{
			posX += speed * dt;
			facingRight = true;
			moving = true;
		}
		else if(playerInput.leftKey == true)
		{
			posX -= speed * dt;
			facingRight = false;
			moving = true;
		}
		else
			moving = false;
			
	    if(playerInput.downKey == true)
				posY += speed * dt;
			if(playerInput.upKey == true)
				posY -= speed * dt;
	    
	    if(posX < 0)
			posX = 0.0;
	    if(posX > currentStreet.streetBounds.width - width)
			posX = currentStreet.streetBounds.width - width;
	    
	    if(posY < 0)
			posY = 0.0;
	    
	    updateAnimation(dt);
						
		updateTransform();
		
		if(ui.progressIndicator != null)
		{
			num percentX = (posX+width/2)/currentStreet.streetBounds.width;
			num percentY = (posY+height/2)/currentStreet.streetBounds.height;
			ui.progressIndicator.style.left = (ui.preview.width*percentX+ui.preview.offset.left-ui.progressIndicator.client.width/2).toString()+"px";
			ui.progressIndicator.style.top = (ui.preview.height*percentY+ui.preview.offset.top-ui.progressIndicator.client.height/2).toString()+"px";
		}
	}
  
	void render()
	{
		if(currentAnimation != null && currentAnimation.dirty)
		{
			//it's not obvious, but setting the width and/or height erases the current canvas as well
			//it is necessary to do this in order to prevent the player from moving within the frame
			//because the aniation sizes are different (walk vs idle, etc.)
			if(playerCanvas.width != currentAnimation.width || playerCanvas.height != currentAnimation.height)
			{
				playerCanvas.width = currentAnimation.width;
                playerCanvas.height = currentAnimation.height;
			}
			else
				playerCanvas.context2D.clearRect(0, 0, currentAnimation.width, currentAnimation.height);
			
			Rectangle destRect = new Rectangle(0,0,currentAnimation.width,currentAnimation.height);
    		playerCanvas.context2D.drawImageToRect(currentAnimation.spritesheet, destRect, sourceRect: currentAnimation.sourceRect);
    		currentAnimation.dirty = false;
		}
	}
	
	void updateAnimation(double dt)
	{
		if(!moving)
			currentAnimation = animations['idle'];
		else
		{
			//reset idle so that the 10 second delay starts over
			animations['idle'].reset();
			
			if(moving)
    			currentAnimation = animations['base'];
		}
		
		currentAnimation.updateSourceRect(dt,holdAtLastFrame:jumping);
	}
	
	void updateTransform()
	{
		String xattr = playerParentElement.attributes['translateX'];
		String yattr = playerParentElement.attributes['translateY'];
		num prevX, prevY, prevCamX = camera.x, prevCamY = camera.y;
		if(xattr != null)
			prevX = num.parse(xattr);
		else
			prevX = 0;
		if(yattr != null)
			prevY = num.parse(yattr);
		else
			prevY = 0;
				
		num translateX = posX, translateY = ui.gameScreenHeight - height;
		num camX = camera.x, camY = camera.y;
		if(posX > currentStreet.streetBounds.width - width/2 - ui.gameScreenWidth/2)
		{
			camX = currentStreet.streetBounds.width - ui.gameScreenWidth;
			translateX = posX - currentStreet.streetBounds.width + ui.gameScreenWidth; //allow character to move to screen right
		}
		else if(posX + width/2 > ui.gameScreenWidth/2)
		{
			camX = posX + width/2 - ui.gameScreenWidth/2;
			translateX = ui.gameScreenWidth/2 - width/2; //keep character in center of screen
		}
		else
			camX = 0;
		
		if(posY + height/2 < ui.gameScreenHeight/2)
		{
			camY = 0;
			translateY = posY;
		}
		else if(posY < currentStreet.streetBounds.height - height/2 - ui.gameScreenHeight/2)
		{
			num yDistanceFromBottom = currentStreet.streetBounds.height - posY - height/2;
			camY = currentStreet.streetBounds.height - (yDistanceFromBottom + ui.gameScreenHeight/2);
			translateY = ui.gameScreenHeight/2 - height/2;
		}
		else
		{
			camY = currentStreet.streetBounds.height - ui.gameScreenHeight;
			translateY = ui.gameScreenHeight - (currentStreet.streetBounds.height - posY);
		}
		
		camera.setCamera((camX~/1).toString()+','+(camY~/1).toString());
		
		//translateZ forces the whole operation to be gpu accelerated (which is very good)
		String transform = 'translateZ(0) translateX('+translateX.toString()+'px) translateY('+translateY.toString()+'px)';
		if(!facingRight)
		{
			transform += ' scale(-1,1)';
			playerName.style.transform = 'scale(-1,1)';
		}
		else
		{
			playerName.style.transform = 'scale(1,1)';
		}
		
		playerParentElement.style.transform = transform;
		playerParentElement.attributes['translateX'] = translateX.toString();
		playerParentElement.attributes['translateY'] = translateY.toString();
		num diffX = translateX-prevX, diffY = translateY-prevY;
	}
}