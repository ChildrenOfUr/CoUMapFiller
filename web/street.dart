part of CoUMapFiller;

Street currentStreet;

Camera camera = new Camera(0,400);
class Camera
{
	int _x,_y;
	int zoom = 0; // for future eyeballery
	bool dirty = true;
	Camera(this._x,this._y);
	Rectangle visibleRect;
	
  	// we're using css transitions for smooth scrolling.
	void setCamera(String xy) //  format 'x,y'
	{
		try
		{
			int newX = int.parse(xy.split(',')[0]);
			int newY = int.parse(xy.split(',')[1]);
			if(newX != _x || newY != _y)
				dirty = true;
			_x = newX;
			_y = newY;
			visibleRect = new Rectangle(_x,_y,ui.gameScreenWidth,ui.gameScreenHeight);
		}
		catch (error)
		{
			print(error);
		}
	}
	
	int getX() => _x;
	int getY() => _y;
}

class Platform
{
	Point start, end;
	String id;
	bool itemPerm, pcPerm;
	Platform(this.id,this.start,this.end,[this.itemPerm = false, this.pcPerm = false]);
	
	String toString()
	{
		return "(${start.x},${start.y})->(${end.x},${end.y})";
	}
	
	int compareTo(Platform other)
	{
		return other.start.y - start.y;
	}
}

class Ladder
{
	Rectangle boundary;
	String id;
	Ladder(this.id,this.boundary);
}

String playerTeleFrom = "";

class Street 
{    
	String label;
	Map _data;
	Map<String,String> exits = new Map();
	List<Platform> platforms = new List();
	List<Ladder> ladders = new List();
	Map<String,double> offsetX = {}, offsetY = {};
	int groundY;
	
	Rectangle streetBounds;
  
	Street(Map data)
	{
		_data = data;

		// sets the label for the street
		label = _data['label'];
		
		streetBounds = new Rectangle(_data['dynamic']['l'],
								_data['dynamic']['t'],
								_data['dynamic']['l'].abs() + _data['dynamic']['r'].abs(),
								_data['dynamic']['t'].abs());
	}
  
	Future <List> load()
	{
		Completer c = new Completer();
		// clean up old street data
		//currentStreet = null;
		layers.children.clear();
   
		// Collect the url's of each deco to load.
		List decosToLoad = [];
		for (Map layer in _data['dynamic']['layers'].values)
		{
			if(layer['decos'] != null)
			{
				for (Map deco in layer['decos'])
    			{
    				if (!decosToLoad.contains('http://childrenofur.com/locodarto/scenery/' + deco['filename'] + '.png'))
                            decosToLoad.add('http://childrenofur.com/locodarto/scenery/' + deco['filename'] + '.png');
    			}
			}
		}
    
		// turn them into assets
		List assetsToLoad = [];
		for (String deco in decosToLoad)
		{
			assetsToLoad.add(new Asset(deco));
		}
		
		// Load each of them, and then continue.
		Batch decos = new Batch(assetsToLoad);
		decos.load(print).then((_)
        {
			//Decos should all be loaded at this point//
			
			// set the street.
			currentStreet = this;
			
			groundY = 0;
			if(_data['dynamic']['ground_y'] != null)
				groundY = -(_data['dynamic']['ground_y'] as num).abs();
		      
			DivElement interactionCanvas = new DivElement()
				..classes.add('streetcanvas')
				..style.pointerEvents = "auto"
				..id = "EntityHolder"
				..style.width = streetBounds.width.toString() + "px"
				..style.height = streetBounds.height.toString() + "px"
				..style.position = 'absolute'
				..attributes['ground_y'] = "0";
			
			DivElement buttonCanvas = new DivElement()
				..classes.add('streetcanvas')
				..style.pointerEvents = "auto"
				..id = "ButtonCanvas"
				..style.width = streetBounds.width.toString() + "px"
				..style.height = streetBounds.height.toString() + "px"
				..style.position = 'absolute'
				..style.pointerEvents = "none"
				..style.zIndex = "5"
				..attributes['ground_y'] = "0";
			
			/* //// Gradient Canvas //// */
			DivElement gradientCanvas = new DivElement();
			gradientCanvas.classes.add('streetcanvas');
			gradientCanvas.id = 'gradient';
			gradientCanvas.style.zIndex = (-100).toString();
			gradientCanvas.style.width = streetBounds.width.toString() + "px";
			gradientCanvas.style.height = streetBounds.height.toString() + "px";
			gradientCanvas.style.position = 'absolute';
			gradientCanvas.attributes['ground_y'] = "0";
			
			// Color the gradientCanvas
			String top = _data['gradient']['top'];
			String bottom = _data['gradient']['bottom'];
			gradientCanvas.style.background = "-webkit-linear-gradient(top, #$top, #$bottom)";
			gradientCanvas.style.background = "-moz-linear-gradient(top, #$top, #$bottom)";
			gradientCanvas.style.background = "-ms-linear-gradient(#$top, #$bottom)";
			gradientCanvas.style.background = "-o-linear-gradient(#$top, #$bottom)";
			
			// Append it to the screen*/
			layers.append(gradientCanvas);
			layers.append(interactionCanvas);
		    
			/* //// Scenery Canvases //// */
			//For each layer on the street . . .
			for(Map layer in new Map.from(_data['dynamic']['layers']).values)
			{
				DivElement decoCanvas = new DivElement()
					..classes.add('streetcanvas');
				
				if(layer['name'] == null)
                	continue;
                				
				decoCanvas.id = layer['name'];
				
				decoCanvas.style.zIndex = layer['z'].toString();
				decoCanvas.style.width = layer['w'].toString() + 'px';
				decoCanvas.style.height = layer['h'].toString() + 'px';
				decoCanvas.style.position = 'absolute';
				decoCanvas.attributes['ground_y'] = _data['dynamic']['ground_y'].toString();
				
				List<String> filters = new List();
				new Map.from(layer['filters']).forEach((String filterName, int value)
				{
					if(filterName == "brightness")
					{
						if(value < 0) 
							filters.add('brightness(' + (1-(value/-100)).toString() +')');
						if (value > 0)
	                        filters.add('brightness(' + (1+(value/100)).toString() +')');
					}
					if(filterName == "contrast")
					{
						if (value < 0) 
							filters.add('contrast(' + (1-(value/-100)).toString() +')');
						if (value > 0)
							filters.add('contrast(' + (1+(value/100)).toString() +')');
					}
					if(filterName == "saturation")
					{
						if (value < 0) 
							filters.add('saturation(' + (1-(value/-100)).toString() +')');
						if (value > 0)
							filters.add('saturation(' + (1+(value/100)).toString() +')');
					}
				});
				decoCanvas.style.filter = filters.join(' ');
		      
				//For each decoration in the layer, give its attributes and draw
				for(Map deco in layer['decos'])
				{
					int x = deco['x'] - deco['w']~/2;
					int y = deco['y'] - deco['h'] + _data['dynamic']['ground_y'];
					if(layer['name'] == 'middleground')
					{
						//middleground has different layout needs
						y += layer['h'];
						x += layer['w']~/2;
					}
					int w = deco['w'];
					int h = deco['h'];
					int z = deco['z'];
		        
					// only draw if the image is loaded.
					if (ASSET[deco['filename']] != null)
					{
						ImageElement d = ASSET[deco['filename']].get();
						
						//resize the image now so that it doesn't have to be done each time
						//it comes into view by the browser's rendering engine
						//TODO maybe uncomment someday - looks terrible
						/*if(w != d.naturalWidth || h != d.naturalHeight)
						{
							print("need to resize ${deco['filename']} from ${d.naturalWidth}x${d.naturalHeight} to ${w}x${h}");
	                      	resizeImage(d,w,h);
	                      	print("new size is ${d.width}x${d.height}");
						}*/
						
						d.style.position = 'absolute';
						d.style.left = x.toString() + 'px';
						d.style.top = y.toString() + 'px';
						d.style.width = w.toString() + 'px';
						d.style.height = h.toString() + 'px';
						d.style.zIndex = z.toString();
						
						String transform = "";
						if(deco['r'] != null)
						{
							transform += "rotate("+deco['r'].toString()+"deg)";
							d.style.transformOrigin = "50% bottom 0";
						}
						if(deco['h_flip'] != null && deco['h_flip'] == true)
                        	transform += " scale(-1,1)";
						d.style.transform = transform;
						decoCanvas.append(d.clone(false));
					}
				}
				
				for(Map platformLine in layer['platformLines'])
  				{
					Point start, end;
					(platformLine['endpoints'] as List).forEach((Map endpoint)
					{
						if(endpoint["name"] == "start")
						{
							start = new Point(endpoint["x"],endpoint["y"]+_data['dynamic']['ground_y']);
							if(layer['name'] == 'middleground')
								start = new Point(endpoint["x"]+layer['w']~/2,endpoint["y"]+layer['h']+_data['dynamic']['ground_y']);
						}
						if(endpoint["name"] == "end")
						{
							end = new Point(endpoint["x"],endpoint["y"]+_data['dynamic']['ground_y']);
							if(layer['name'] == 'middleground')
								end = new Point(endpoint["x"]+layer['w']~/2,endpoint["y"]+layer['h']+_data['dynamic']['ground_y']);
						}
					});
  					platforms.add(new Platform(platformLine['id'],start,end));
  				}
				
				platforms.sort((x,y) => x.compareTo(y));
				
				//debug only: draw platforms
				/*platforms.forEach((Platform platform)
				{
					Element rect = new DivElement();
					rect.text = "(${platform.start.x},${platform.start.y}) - (${platform.end.x},${platform.end.y})";
					rect.style.width = (platform.end.x-platform.start.x).toString() + "px";
					rect.style.height = (platform.end.y-platform.start.y).toString() + "px";
					rect.style.left = platform.start.x.toString()+"px";
					rect.style.top = platform.start.y.toString()+"px";
					rect.style.border = "1px black solid";
					rect.style.position = "absolute";
					rect.style.zIndex = "100";
					decoCanvas.append(rect);
				});*/
				
				for(Map ladder in layer['ladders'])
  				{
					int x,y,width,height;
					String id;
					
					width = ladder['w'];
                    height = ladder['h'];
					x = ladder['x']+layer['w']~/2-width~/2;
					y = ladder['y']+layer['h']-height+_data['dynamic']['ground_y'];
					id = ladder['id'];
					
					Rectangle box = new Rectangle(x,y,width,height);
					ladders.add(new Ladder(id,box));
  				}
				
				//debug only: draw ladders
				/*for(Ladder ladder in ladders)
				{
					Element rect = new DivElement();
					rect.style.width = ladder.boundary.width.toString() + "px";
					rect.style.height = ladder.boundary.height.toString() + "px";
					rect.style.left = ladder.boundary.left.toString()+"px";
					rect.style.top = ladder.boundary.top.toString()+"px";
					rect.style.border = "1px black solid";
					rect.style.position = "absolute";
					rect.style.zIndex = "100";
					decoCanvas.append(rect);
				}*/
				
				for (Map signpost in layer['signposts'])
				{
					int h = 200, w = 100;
					if(signpost['h'] != null)
						h = signpost['h'];
					if(signpost['w'] != null)
						w = signpost['w'];
					int x = signpost['x'];
					int y = signpost['y'] - h + groundY;
					if(layer['name'] == 'middleground')
					{
						//middleground has different layout needs
						y += layer['h'];
						x += layer['w']~/2;
					}
					
					DivElement pole = new DivElement()
						..style.backgroundImage = "url('http://childrenofur.com/locodarto/scenery/sign_pole.png')"
						..style.backgroundRepeat = "no-repeat"
						..style.width = w.toString() + "px"
						..style.height = h.toString() + "px"
						..style.position = "absolute"
						..style.top = (y-groundY).toString() + "px"
						..style.left = (x-48).toString() + "px";
					interactionCanvas.append(pole);
					
					int i=0;
					List signposts = signpost['connects'] as List;
					for(Map<String,String> exit in signposts)
					{
						if(exit['label'] == playerTeleFrom || playerTeleFrom == "console")
						{
							if(playerTeleFrom == "console")
								print("setting x: $x, y: $y");
							CurrentPlayer.posX = x;
							CurrentPlayer.posY = y;
						}
						
						String tsid = exit['tsid'].replaceFirst("L", "G");
						SpanElement span = new SpanElement()
						        ..style.position = "absolute"
    							..style.top = (y+i*25+10-groundY).toString() + "px"
    							..style.left = x.toString() + "px"
    							..text = exit["label"]
    							..className = "ExitLabel"
                                ..attributes['url'] = 'http://RobertMcDermot.github.io/CAT422-glitch-location-viewer/locations/$tsid.callback.json'
                                ..attributes['tsid'] = tsid
								..attributes['from'] = currentStreet.label
                                ..style.transform = "rotate(-5deg)";
						
						if(i %2 != 0)
						{
							gradientCanvas.append(span);
							span.style.left = (x-span.clientWidth).toString() + "px";
							span.style.transform = "rotate(5deg)";
						}

						interactionCanvas.append(span);
						i++;
					}
				}
				
				// Append the canvas to the screen
				layers.append(decoCanvas);
				layers.append(interactionCanvas);
				layers.append(buttonCanvas);
			}
			
			//make sure to redraw the screen (in case of street switching)
			camera.dirty = true;
			showLineCanvas();
			c.complete(this);
		});
        // Done initializing street.
		return c.future;
	}
	
	void showLineCanvas()
    {	
		CheckboxInputElement collisions = querySelector("#collisionLines");
		if(!collisions.checked)
		{
			Element lineCanvas = querySelector("#lineCanvas");
			if(lineCanvas != null)
				lineCanvas.remove();
			return;
		}
		
    	CanvasElement lineCanvas = new CanvasElement()
    		..classes.add("streetcanvas")
    		..style.position = "absolute"
    		..style.width = currentStreet.streetBounds.width.toString()+"px"
    		..style.height = currentStreet.streetBounds.height.toString()+"px"
    		..width = currentStreet.streetBounds.width
    		..height = currentStreet.streetBounds.height
    		..attributes["ground_y"] = currentStreet._data['dynamic']['ground_y'].toString()
    		..id = "lineCanvas";
    	layers.append(lineCanvas);
    	
    	camera.dirty = true; //force a recalculation of any offset
    	
    	repaint(lineCanvas);
    }
	
	void repaint(CanvasElement lineCanvas, [Platform temporary])
    {
    	CanvasRenderingContext2D context = lineCanvas.context2D;
    	context.clearRect(0, 0, lineCanvas.width, lineCanvas.height);
    	context.lineWidth = 3;
    	context.strokeStyle = "#ffff00";
    	context.beginPath();
    	for(Platform platform in currentStreet.platforms)
    	{
    		context.moveTo(platform.start.x, platform.start.y-1.5);
    		context.lineTo(platform.end.x, platform.end.y-1.5);
    	}
    	context.stroke();
    	context.beginPath();
    	context.strokeStyle = "#ff0000";
    	for(Platform platform in currentStreet.platforms)
    	{
    		context.moveTo(platform.start.x, platform.start.y+1.5);
    		context.lineTo(platform.end.x, platform.end.y+1.5);
    	}    	
    	context.stroke();
    	context.beginPath();
    	context.strokeStyle = "#000000";
    	for(Platform platform in currentStreet.platforms)
    	{
    		context.moveTo(platform.end.x, platform.end.y+5);
    		context.lineTo(platform.end.x, platform.end.y-5);
    	}
    	context.stroke();
    }
	
	void resizeImage(ImageElement img, int newWidth, int newHeight) 
	{
		CanvasElement canvas = new CanvasElement();
        canvas.width = img.naturalWidth;
        canvas.height = img.naturalHeight;
        CanvasRenderingContext2D context = canvas.context2D;
        context.drawImage(img, 0, 0);
         
        new js.JsObject(js.context['resample_hermite'],[canvas, img.naturalWidth, img.naturalHeight, newWidth, newHeight]);
         
        CanvasElement copy = new CanvasElement();
        copy.width = newWidth;
        copy.height = newHeight;
        CanvasRenderingContext2D cctx = copy.context2D;
         
        cctx.putImageData( context.getImageData( 0, 0, newWidth, newHeight ), 0, 0 );
         
        img.src = copy.toDataUrl();
    }
 
	//Parallaxing: Adjust the position of each canvas in #GameScreen
	//based on the camera position and relative size of canvas to Street
	render()
	{
		//only update if camera x,y have changed since last render cycle
		if(camera.dirty)
		{
			num currentPercentX = camera.getX() / (streetBounds.width - ui.gameScreenWidth);
			num currentPercentY = camera.getY() / (streetBounds.height - ui.gameScreenHeight);
			
			//modify left and top for parallaxing
			Map<String,DivElement> transforms = new Map();
			for(Element canvas in gameScreen.querySelectorAll('.streetcanvas'))
			{
				int canvasWidth = num.parse(canvas.style.width.replaceAll('px', '')).toInt();
				int canvasHeight = num.parse(canvas.style.height.replaceAll('px', '')).toInt();
				double offsetX = (canvasWidth - ui.gameScreenWidth) * currentPercentX;
				double offsetY = (canvasHeight - ui.gameScreenHeight) * currentPercentY;
				
				int groundY = num.parse(canvas.attributes['ground_y']).toInt();
				offsetY += groundY;
				
				//translateZ(0) forces the gpu to render the transform
				transforms[canvas.id+"translateZ(0) translateX("+(-offsetX).toString()+"px) translateY("+(-offsetY).toString()+"px)"] = canvas;
			}
			//try to bundle DOM writes together for performance.
			transforms.forEach((String transform, Element canvas)
			{
				transform = transform.replaceAll(canvas.id, '');
				canvas.style.transform = transform;
			});			
			camera.dirty = false;
		}
	}
}