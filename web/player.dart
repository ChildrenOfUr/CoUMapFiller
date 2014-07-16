part of CoUMapFiller;

Player CurrentPlayer;

class Player
{
	int width, height, canvasHeight, speed;
	num posX, posY;
	num yVel, yAccel = -2400;
	bool jumping = false, moving = false, climbingUp = false, climbingDown = false, facingRight = true;
	Map<String,Animation> animations = new Map();
	Animation currentAnimation;
	Random rand = new Random();
  		
	//for testing purposes
	//if false, player can move around with wasd and arrows, no falling
	bool doPhysicsApply = true;
  
	DivElement playerCanvas;
	DivElement avatar;
	DivElement playerName;
  
	Player([String name])
	{
		//TODO: Remove hard-coded values used for testing
		width = 116;
		height = 137;
		speed = 300; //pixels per second
		yVel = 0;
		posX = 1.0;
		posY = 0;//currentStreet.ui.gameScreenHeight - 170;
		for(Platform platform in currentStreet.platforms)
		{
			if(platform.start.x <= 5)
				posY = platform.start.y-height;
		}

		playerCanvas = new DivElement()
			..style.pointerEvents = "none"
			..style.display = "inline-block"
			..style.textAlign = "center";
		
		playerName = new DivElement()
			..text = "tester";
		
		avatar = new DivElement();
		
		playerCanvas.append(playerName);
		playerCanvas.append(avatar);
		
		gameScreen.append(playerCanvas);
		
		canvasHeight = playerCanvas.clientHeight;
	}
	
	Future<List<Animation>> loadAnimations()
	{
		//need to get background images from some server for each player based on name
		animations['idle'] = new Animation("assets/sprites/idle.png",'idle');
		animations['base'] = new Animation("assets/sprites/base.png",'base');
		animations['jump'] = new Animation("assets/sprites/jump.png",'jump');
		animations['stillframe'] = new Animation("assets/sprites/base.png",'stillframe');
		
		List<Future> futures = new List();
		animations.forEach((String name,Animation animation) => futures.add(animation.load()));
		
		return Future.wait(futures);
	}
  
	update(double dt)
	{
		//wait for dt to settle down (hopefully)
		if(dt > .1)
			return;
				
		num cameFrom = posY;
		
		if(playerInput.upKey == true)
		{
			bool found = false;
			Rectangle playerRect = new Rectangle(posX,posY+currentStreet._data['dynamic']['ground_y'],width,height-15);
			for(Ladder ladder in currentStreet.ladders)
			{
				if(intersect(ladder.boundary,playerRect))
				{
					//if our feet are above the ladder, stop climbing
					if(playerRect.top+playerRect.height < ladder.boundary.top)
						break;
					
					posY -= speed/4 * dt;
					climbingUp = true;
					found = true;
					break;
				}
			}
			if(!found)
			{
				climbingUp = false;
				climbingDown = false;
			}
		}
		
		if(playerInput.downKey == true)
		{
			bool found = false;
			Rectangle playerRect = new Rectangle(posX,posY+currentStreet._data['dynamic']['ground_y'],width,height);
			for(Ladder ladder in currentStreet.ladders)
			{
				if(intersect(ladder.boundary,playerRect))
				{
					//if our feet are below the ladder, stop climbing
					if(playerRect.top+playerRect.height > ladder.boundary.top+ladder.boundary.height)
						break;
					
					posY += speed/4 * dt;
					climbingDown = true;
					found = true;
					break;
				}
			}
			if(!found)
			{
				climbingDown = false;
				climbingUp = false;
			}
		}
		
		if(playerInput.downKey == false && playerInput.upKey == false)
		{
			bool found = false;
			Rectangle playerRect = new Rectangle(posX,posY+currentStreet._data['dynamic']['ground_y'],width,height);
			for(Ladder ladder in currentStreet.ladders)
			{
				if(intersect(ladder.boundary,playerRect))
				{
					found = true;
					break;
				}
			}
			if(!found)
			{
				climbingDown = false;
				climbingUp = false;
			}
		}
		
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
			
	    //primitive jumping
		if (playerInput.jumpKey == true && !jumping && !climbingUp && !climbingDown)
		{
			Random rand = new Random();
			if(rand.nextInt(4) == 3)
				yVel = -1200;
			else
				yVel = -900;
			jumping = true;
		}
	    
	    //needs acceleration, some gravity const somewhere
	    //for jumps/falling	    
		if(doPhysicsApply && !climbingUp && !climbingDown)
		{
			yVel -= yAccel * dt;
			posY += yVel * dt;
	    }
		else
		{
			if(playerInput.downKey == true)
				posY += speed * dt;
			if(playerInput.upKey == true)
				posY -= speed * dt;
	    }
	    
	    if(posX < 0)
			posX = 0.0;
	    if(posX > currentStreet.streetBounds.width - width)
			posX = currentStreet.streetBounds.width - width;
	    
	    //check for collisions with platforms
	    if(doPhysicsApply && !climbingDown && yVel >= 0)
		{
			num x = posX+width/2;
			Platform bestPlatform = _getBestPlatform(cameFrom);
			
			if(bestPlatform != null)
			{
				num goingTo = posY+height+currentStreet._data['dynamic']['ground_y'];
    			num slope = (bestPlatform.end.y-bestPlatform.start.y)/(bestPlatform.end.x-bestPlatform.start.x);
    			num yInt = bestPlatform.start.y - slope*bestPlatform.start.x;
    			num lineY = slope*x+yInt;
    			
    			if(goingTo >= lineY)
    			{
    				posY = lineY-height-currentStreet._data['dynamic']['ground_y'];
    				yVel = 0;
    				jumping = false;
    			}
			}
			//else
				//print("bestPlatform is null");
		}
	    
	    if(posY < 0)
			posY = 0.0;	    
			
		if(!moving && !jumping)
			currentAnimation = animations['idle'];
		else if(moving && !jumping)
			currentAnimation = animations['base'];
		else if(jumping)
			currentAnimation = animations['jump'];
		else
			currentAnimation = animations['stillframe'];
		
		if(!avatar.style.backgroundImage.contains(currentAnimation.backgroundImage))
		{
			avatar.style.backgroundImage = 'url('+currentAnimation.backgroundImage+')';
			avatar.style.width = currentAnimation.width.toString()+'px';
			avatar.style.height = currentAnimation.height.toString()+'px';
			avatar.style.animation = currentAnimation.animationStyleString;
			canvasHeight = currentAnimation.height+50;
		}
						
		num translateX = posX, translateY = ui.gameScreenHeight - canvasHeight;
		num camX = camera.getX(), camY = camera.getY();
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
		
		if(posY + canvasHeight/2 < ui.gameScreenHeight/2)
		{
			camY = 0;
			translateY = posY;
		}
		else if(posY < currentStreet.streetBounds.height - canvasHeight/2 - ui.gameScreenHeight/2)
		{
			num yDistanceFromBottom = currentStreet.streetBounds.height - posY - canvasHeight/2;
			camY = currentStreet.streetBounds.height - (yDistanceFromBottom + ui.gameScreenHeight/2);
			translateY = ui.gameScreenHeight/2 - canvasHeight/2;
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
		
		playerCanvas.style.transform = transform;		
	}
  
	render()
	{
		//Need scaling; some levels change player's apparent size
		//scaling should be done as needed, not in render cycle
		//CurrentPlayer.playerCanvas.context2D.clearRect(0, 0, width, height);
		//CurrentPlayer.playerCanvas.context2D.drawImage(avatar, 0, 0);
	}
	
	bool intersect(Rectangle a, Rectangle b) 
	{
		return (a.left <= b.right &&
				b.left <= a.right &&
				a.top <= b.bottom &&
				b.top <= a.bottom);
    }
	
	//ONLY WORKS IF PLATFORMS ARE SORTED WITH
	//THE HIGHEST (SMALLEST Y VALUE) FIRST IN THE LIST
	Platform _getBestPlatform(num cameFrom)
	{
		Platform bestPlatform;
		num x = posX+width/2;
		num from = cameFrom+height+currentStreet._data['dynamic']['ground_y'];
		
		//print("num platforms to choose from: " + currentStreet.platforms.length.toString());
		for(Platform platform in currentStreet.platforms)
		{
			if(x >= platform.start.x && x <= platform.end.x)
			{
				num slope = (platform.end.y-platform.start.y)/(platform.end.x-platform.start.x);
    			num yInt = platform.start.y - slope*platform.start.x;
    			num lineY = slope*x+yInt;
    			    			    			
    			if(bestPlatform == null)
					bestPlatform = platform;
				else
				{
					//+5 helps with upward slopes and not falling through things
					if(lineY+5 >= from)
						bestPlatform = platform;
				}
			}
		}
		
		return bestPlatform;
	}
}