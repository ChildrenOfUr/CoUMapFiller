library CoUMapFiller;

import "dart:html";
import "dart:math";
import "dart:async";
import "dart:convert";

import 'package:libld/libld.dart'; // Nice and simple asset loading.

part 'loop.dart';
part 'render.dart';
part 'street.dart';
part 'player.dart';
part 'animation.dart';
part 'input.dart';
part 'ui.dart';
part 'shrines_and_vendors.dart';

String currentLayer = "EntityHolder";
int width = 3000 , height = 1000;
DivElement gameScreen, layers;
Rectangle bounds;
Random rand = new Random();

// Declare our game_loop
double lastTime = 0.0;
DateTime startTime = new DateTime.now();

gameLoop(num delta)
{
	double dt = (delta-lastTime)/1000;
	loop(dt);
	render();
	lastTime = delta;
	window.animationFrame.then(gameLoop);
}

main()
{
	gameScreen = querySelector("#GameScreen");
	
	layers = new DivElement()
		..id = "layers"
		..style.position = "absolute";
			
	gameScreen.append(layers);
    
    DivElement generateButton = querySelector("#Generate");
    generateButton.onMouseDown.listen((_)
	{
		generateButton.classes.remove("shadow");
	});
    generateButton.onMouseUp.listen((_)
	{
    	generate();
		generateButton.classes.add("shadow");
	});
    
    InputElement fileLoad = querySelector("#fileLoad") as InputElement;
    fileLoad.onChange.listen((_)
	{
    	//the user hit cancel
    	if(fileLoad.files.length == 0)
    		return;
    	
		File file = fileLoad.files.first;
		FileReader reader = new FileReader();
		reader.onLoad.listen((_)
		{
			loadStreet(JSON.decode(reader.result));
		});
		reader.readAsText(file);
		fileLoad.blur();
	});
    
    querySelector('#LocationCodeForm').onSubmit.listen((Event e)
    {
    	e.preventDefault();
    	loadLocationJson();
    });
    
    querySelector("#LocationCodeButton").onClick.listen((_) => loadLocationJson());
    
    window.onMessage.listen((MessageEvent event)
	{
		loadStreet(JSON.decode(event.data)).then((_)
		{
			//load a preview image of the street
			String tsid = JSON.decode(event.data)['tsid'];
			if(tsid.startsWith("G"))
				tsid = tsid.replaceFirst("G", "L");
			
			DivElement popup = querySelector("#PreviewWindow");
            popup.hidden = false;
            querySelector("#LoadingPreview").hidden = false;
			
            HttpRequest.getString('http://robertmcdermot.com:8080/streetPreview?tsid=$tsid').then((String response)
			{
				displayPreview(JSON.decode(response));
			});
		});
	});
    
    querySelectorAll(".entity").forEach((Element treeDiv)
	{
		setupListener(treeDiv);
	});
      
    ui.init();
    playerInput = new Input();
    playerInput.init();
    currentStreet = new Street(generate());
    currentStreet.load().then((_)
    {
    	CurrentPlayer = new Player();
    	CurrentPlayer.doPhysicsApply = false;
		CurrentPlayer.loadAnimations().then((_) => gameLoop(0.0));
    });
}

void displayPreview(Map response)
{
	String imageUrl = response['previewUrl'];
	String region = response['region'];
	if(region == "Ix" || region == "Uralia" || region == "Chakra Phool")
	{
		if(region == "Chakra Phool")
			region = "Firebog";
		
		querySelector("#NormalShrines").style.display = "none";
		querySelector("#${region}Shrines").style.display = "block";
	}
	else
		querySelector("#NormalShrines").style.display = "block";
	
	displayMissingStuff(response);
	
	num width,height;
	DivElement popup = querySelector("#PreviewWindow");
	ImageElement preview = querySelector("#Preview");
	popup.hidden = false;
	String initialWidth = popup.clientWidth.toString()+"px";
	String initialHeight = "calc("+popup.clientHeight.toString()+"px"+" - 2em)";
	popup.attributes['initialWidth'] = initialWidth;
	popup.attributes['initialHeight'] = initialHeight;
	
	Element popupAction = querySelector("#PopupAction");
	popupAction.onClick.first.then((_) => minimizePopup());
	popupAction.classes.add("fa-chevron-down");
    popupAction.classes.remove("fa-chevron-up");
	
	preview.src = imageUrl;
	preview.onLoad.listen((_)
	{
		preview.hidden = false;
		height = preview.naturalHeight;
		width = preview.naturalWidth;
		if(height > window.innerHeight - 100)
		{
			height = window.innerHeight - 100;
			preview.height = height;
		}
		if(width > window.innerWidth - 100)
		{
			width = window.innerWidth - 100;
			preview.width = width;
		}
		
		preview.attributes['scaledHeight'] = height.toString();
		preview.attributes['scaledWidth'] = width.toString();
		querySelector("#LoadingPreview").hidden = true;
		popup.style.width = width.toString()+'px';
		popup.style.height = "calc("+height.toString()+"px" + " + 2em)";
		popup.onMouseDown.listen((MouseEvent event)
		{
			StreamSubscription move = window.onMouseMove.listen((MouseEvent event)
			{
				popup.style.left = event.client.x.toString()+"px";
				popup.style.top = event.client.y.toString()+"px";
			});
			window.onMouseUp.first.then((_) => move.cancel());
		});
	});
}

void displayMissingStuff(Map response)
{
	
}

void minimizePopup()
{
	DivElement popup = querySelector("#PreviewWindow");
   	ImageElement preview = querySelector("#Preview");
   	Element popupAction = querySelector("#PopupAction");
   	
   	popupAction.classes.toggle("fa-chevron-down");
   	popupAction.classes.toggle("fa-chevron-up");
   	popupAction.onClick.first.then((_) => maximizePopup());
	preview.hidden = true;
	popup.style.bottom = "0px";
	popup.style.right = "0px";
	popup.style.top = "initial";
	popup.style.left = "initial";
	popup.style.width = popup.attributes['initialWidth'];
	popup.style.height = popup.attributes['initialHeight'];
}

void maximizePopup()
{
	DivElement popup = querySelector("#PreviewWindow");
    ImageElement preview = querySelector("#Preview");
    Element popupAction = querySelector("#PopupAction");
   	
    num height = num.parse(preview.attributes['scaledHeight']);
    num width = num.parse(preview.attributes['scaledWidth']);
   	popupAction.classes.toggle("fa-chevron-down");
   	popupAction.classes.toggle("fa-chevron-up");
   	popupAction.onClick.first.then((_) => minimizePopup());
    preview.hidden = false;
    preview.height = height;
	popup.style.width = width.toString()+'px';
	popup.style.height = "calc("+height.toString()+"px" + " + 2em)";
	popup.style.bottom = "0px";
	popup.style.right = "0px";
	popup.style.top = "initial";
	popup.style.left = "initial";
}

void loadLocationJson()
{
	String location = (querySelector("#LocationCodeInput") as TextInputElement).value;
	if(location != "")
	{
		if(location.startsWith("L"))
			location = location.replaceFirst("L", "G");
		String url = "http://RobertMcDermot.github.io/CAT422-glitch-location-viewer/locations/$location.callback.json";
		ScriptElement loadStreet = new ScriptElement();
		loadStreet.src = url;
        document.body.append(loadStreet);
	}
}

void setupListener(DivElement entityParent)
{
	DivElement entity = entityParent.querySelector(".centerEntity");
	entityParent.onClick.listen((MouseEvent event)
	{
		StreamSubscription moveListener, clickListener;
		
		DivElement drag = new DivElement();
		CssStyleDeclaration style = entity.getComputedStyle();
		int scale = 4;
		if(entity.attributes['scale'] != null)
			scale = int.parse(entity.attributes['scale']);
		num width = num.parse(style.width.replaceAll("px", "")) * scale;
		num height = num.parse(style.height.replaceAll("px", "")) * scale;
		drag.style.backgroundImage = style.backgroundImage;
		drag.style.backgroundPosition = style.backgroundPosition;
		drag.style.position = "absolute";
		drag.style.width = width.toString()+"px";
		drag.style.height = height.toString()+"px";
		drag.style.top = (event.client.y-height).toString()+"px";
		drag.style.left = event.client.x.toString()+"px";
		drag.classes.add("dashedBorder");
		document.body.append(drag);
		
		Element layer = querySelector("#$currentLayer");
		clickListener = layers.onClick.listen((MouseEvent event)
    	{			
			num x,y;
			//if we clicked on another deco inside the target layer
    		if((event.target as Element).id != layer.id)
    		{
    			y = (event.target as Element).offset.top+event.layer.y+currentStreet.offsetY[currentLayer];
    			x = (event.target as Element).offset.left+event.layer.x+currentStreet.offsetX[currentLayer];
    		}
    		//else we clicked on empty space in the layer
    		else
    		{
    			y = event.layer.y+currentStreet.offsetY[currentLayer];
    			x = event.layer.x+currentStreet.offsetX[currentLayer];
    		}
    		drag.style.top = (y-drag.clientHeight).toString()+"px";
            drag.style.left = x.toString()+"px";
            drag.classes.add("deco");
            drag.classes.remove("dashedBorder");
            //drag.onClick.listen((_) => editDetails(drag));
            
            layer.append(drag);
            //editDetails(drag);

            moveListener.cancel();
            clickListener.cancel();
    	});
		
		moveListener = document.body.onMouseMove.listen((MouseEvent event)
    	{
    		drag.style.top = (event.page.y-drag.clientHeight).toString()+"px";
            drag.style.left = (event.page.x+1).toString()+"px";
    	});
	});
}

StreamSubscription xInputListener,yInputListener,zInputListener,wInputListener,hInputListener,rotateInputListener;

void editDetails(ImageElement clone)
{	
	//delete previous listeners so only one deco moves around
	if(xInputListener != null)
		xInputListener.cancel();
	if(yInputListener != null)
    	yInputListener.cancel();
	if(zInputListener != null)
    	zInputListener.cancel();
	if(wInputListener != null)
    	wInputListener.cancel();
	if(hInputListener != null)
    	hInputListener.cancel();
	if(rotateInputListener != null)
		rotateInputListener.cancel();
	
	querySelectorAll(".deco").forEach((Element e) 
	{
		if(e != clone)
			e.classes.remove("dashedBorder");
	});
	clone.classes.toggle("dashedBorder");
	Element decoDetails = querySelector("#DecoDetails");
	
	//if we just selected it
	if(clone.classes.contains("dashedBorder"))
	{
		decoDetails.hidden = false;
		
		InputElement xInput = (querySelector("#DecoX") as InputElement);
		xInput.value = clone.style.left.replaceAll("px", "");
		xInputListener = xInput.onInput.listen((_) => clone.style.left = xInput.value +"px");
		InputElement yInput = (querySelector("#DecoY") as InputElement);
		yInput.value = clone.style.top.replaceAll("px", "");
		yInputListener = yInput.onInput.listen((_) => clone.style.top = yInput.value +"px");
		InputElement zInput = (querySelector("#DecoZ") as InputElement);
		zInput.value = clone.style.zIndex;
		zInputListener = zInput.onInput.listen((_) => clone.style.zIndex = zInput.value);
		
		InputElement wInput = (querySelector("#DecoW") as InputElement);
        wInput.value = clone.style.maxWidth.replaceAll("px", "");
        wInput.placeholder = "default: " + clone.naturalWidth.toString();
        wInputListener = wInput.onInput.listen((_)
        {
        	if(wInput.value == "")
        		clone.style.maxWidth = clone.naturalWidth.toString() + "px";
        	else
        		clone.style.maxWidth = wInput.value +"px";
        });
        InputElement hInput = (querySelector("#DecoH") as InputElement);
        hInput.value = clone.style.maxHeight.replaceAll("px", "");
        hInput.placeholder = "default: " + clone.naturalHeight.toString();
        hInputListener = hInput.onInput.listen((_)
        {
        	if(hInput.value == "")
        		clone.style.maxHeight = clone.naturalHeight.toString() + "px";
        	else
        		clone.style.maxHeight = hInput.value +"px";
        });
        
        InputElement rotateInput = (querySelector("#DecoRotate") as InputElement);
        rotateInput.value = getTransformAngle(clone.getComputedStyle().transform).toString();
        rotateInputListener = rotateInput.onInput.listen((_) => clone.style.transform = "rotate("+rotateInput.value +"deg)");	
		
        (querySelector("#FlipDeco") as CheckboxInputElement).checked = clone.classes.contains("flip");
		//special case for rotated deco which needs to also be flipped...
        if(clone.style.transform.contains("rotate") && clone.classes.contains("flip"))
        	clone.style.transform += " scale(-1,1)";        	
	}
	//else we deselected it
	else
	{
		decoDetails.hidden = true;
	}
}

num getTransformAngle(String tr)
{
	if(tr == "none")
		return 0;
	
	List<String> values = tr.split('(')[1].split(')')[0].split(',');
    num a = num.parse(values[0]);
    num b = num.parse(values[1]);
    num angle = (atan2(b, a) * (180/PI));
    return angle;
}

Future loadStreet(Map streetData)
{
	Completer c = new Completer();
	layers.children.clear();
    //querySelector("#layerList").children.clear();
        	
	CurrentPlayer.doPhysicsApply = false;
	currentStreet = new Street(streetData);
	currentStreet.load().then((_)
	{
		width = currentStreet.streetBounds.width;
    	height = currentStreet.streetBounds.height;
    	updateBounds(0,0,width,height);
    	c.complete();
   	});
	return c.future;
}

void showLineCanvas()
{	
	CanvasElement lineCanvas = new CanvasElement()
		..classes.add("streetcanvas")
		..style.position = "absolute"
		..width = bounds.width
		..height = bounds.height
		..attributes["ground_y"] = currentStreet._data['dynamic']['ground_y'].toString()
		..id = "lineCanvas";
	layers.append(lineCanvas);
	
	camera.dirty = true; //force a recalculation of any offset
	
	repaint(lineCanvas);
	
	int startX = -1, startY = -1;

	lineCanvas.onMouseDown.listen((MouseEvent event)
	{
		startX = event.layer.x+currentStreet.offsetX["lineCanvas"].toInt();
		startY = event.layer.y+currentStreet.offsetY["lineCanvas"].toInt();
	});
	lineCanvas.onMouseMove.listen((MouseEvent event)
	{
		if(startX == -1)
			return;
		
		Point start = new Point(startX,startY);
		Point end = new Point(event.layer.x+currentStreet.offsetX["lineCanvas"].toInt(),event.layer.y+currentStreet.offsetY["lineCanvas"].toInt());
		Platform temporary = new Platform("temp",start,end);
		repaint(lineCanvas,temporary);
	});
	lineCanvas.onMouseUp.listen((MouseEvent event)
	{
		if(startX == -1)
			return;
		
		int endX = event.layer.x+currentStreet.offsetX["lineCanvas"].toInt();
		int endY = event.layer.y+currentStreet.offsetY["lineCanvas"].toInt();
		//make sure the startX is < endX
		if(endX < startX)
		{
			int tempX = endX;
			int tempY = endY;
			endX = startX;
			startX = tempX;
			endY = startY;
			startY = tempY;
		}
		Point start = new Point(startX,startY);
		Point end = new Point(endX,endY);
		Platform newPlat = new Platform("plat_"+rand.nextInt(10000000).toString(),start,end);
		currentStreet.platforms.add(newPlat);
		currentStreet.platforms.sort((x,y) => x.compareTo(y));
		repaint(lineCanvas);
		
		startX = -1;
	});
}

void repaint(CanvasElement lineCanvas, [Platform temporary])
{
	CanvasRenderingContext2D context = lineCanvas.context2D;
	context.clearRect(0, 0, lineCanvas.width, lineCanvas.height);
	context.beginPath();
	for(Platform platform in currentStreet.platforms)
	{
		context.moveTo(platform.start.x, platform.start.y);
		context.lineTo(platform.end.x, platform.end.y);
	}
	if(temporary != null)
	{
		context.moveTo(temporary.start.x, temporary.start.y);
        context.lineTo(temporary.end.x, temporary.end.y);
	}
	context.stroke();
}

void newExit([String exitName])
{
	Element exitList = querySelector("#exitList");
	
	LIElement item = new LIElement();
	ImageElement deleteButton = new ImageElement(src:"assets/images/delete.png")
		..classes.add("deleteButton");
	TextInputElement titleInput = new TextInputElement()
		..classes.add("exitTitle")
		..placeholder = "street name";
	TextInputElement tsidInput = new TextInputElement()
		..classes.add("exitTsid")
		..placeholder = "tsid";
	
	deleteButton.onClick.first.then((_) => item.remove());
	
	item.append(deleteButton);
	item.append(titleInput);
	item.append(tsidInput);
	exitList.append(item);
}

Map generate()
{
	Map streetMap = {};
	Map dynamicMap = {};
	streetMap["tsid"] = "sample_tsid_"+rand.nextInt(10000000).toString();
	streetMap["label"] = "no label";
	streetMap["gradient"] = {"top":"ffffff","bottom":"ffffff"};
	streetMap["dynamic"] = dynamicMap;
	
	dynamicMap["l"] = -1000;
	dynamicMap["r"] = 1000;
	dynamicMap["t"] = 2000;
	dynamicMap["b"] = 0;
	dynamicMap["rookable_type"] = 0;
	dynamicMap["ground_y"] = 0;
	
	int count = 0;
	Map layerMap = {};
	querySelectorAll("#layerList li").forEach((Element child)
	{
		Map layer = {};
		layer["name"] = child.querySelector("#title").text;		
		layer["w"] = int.parse(child.querySelector("#width").text.replaceAll("px", ""));
		layer["h"] = int.parse(child.querySelector("#height").text.replaceAll("px", ""));
		layer["z"] = count;
		count--;
		layer["filters"] = {};
		
		List<Map> decosList = [];
		layers.querySelector("#${layer["name"]}").children.forEach((ImageElement deco)
		{
			String filename = deco.src.substring(deco.src.lastIndexOf("/")+1,deco.src.lastIndexOf("."));
            num decoX = int.parse(deco.style.left.replaceAll("px", ""))+deco.clientWidth~/2;
            num decoY = int.parse(deco.style.top.replaceAll("px", ""))+deco.clientHeight;
            if(layer["name"] == "middleground")
            {
            	decoX -= bounds.width~/2;
            	decoY -= bounds.height;
            }
			Map decoMap = {"filename":filename,"w":deco.clientWidth,"h":deco.clientHeight,"z":0,"x":decoX.toInt(),"y":decoY.toInt()};
			int rotation = getTransformAngle(deco.getComputedStyle().transform).toInt();
			if(rotation != 0)
				decoMap["r"] = rotation;
			if(deco.classes.contains("flip"))
				decoMap["h_flip"] = true;
			decosList.add(decoMap);
		});
		layer["decos"] = decosList;
		
		List<Map> signposts = [];
		querySelector("#exitList").children.forEach((Element element)
		{
			TextInputElement exitTitle = element.querySelector(".exitTitle");
			TextInputElement exitTsid = element.querySelector(".exitTsid");
        	signposts.add({"connects":[{"label":exitTitle.value,"tsid":exitTsid.value}]});
		});
		layer["signposts"] = signposts;
		
		List platforms = [];
		if(currentStreet != null)
		{
			for(Platform platform in currentStreet.platforms)
    		{
    			Map platformMap = {};
    			platformMap["id"] = platform.id;
        		platformMap["platform_item_perm"] = -1;
        		platformMap["platform_pc_perm"] = -1;
        		List<Map> endpoints = [];
    			Map start = {"name":"start","x":platform.start.x+bounds.width~/2-bounds.width,"y":platform.start.y-bounds.height};
    			Map end = {"name":"end","x":platform.end.x+bounds.width~/2-bounds.width,"y":platform.end.y-bounds.height};
    			endpoints.add(start);
    			endpoints.add(end);
    			platformMap["endpoints"] = endpoints;
    			platforms.add(platformMap);
    		}
			layer["platformLines"] = platforms;
		}
		else if(currentStreet == null)
		{
			Map defaultPlatform = {};
    		defaultPlatform["id"] = "plat_default";
    		defaultPlatform["platform_item_perm"] = -1;
    		defaultPlatform["platform_pc_perm"] = -1;
    		defaultPlatform["endpoints"] = [{"name":"start","x":-bounds.width~/2,"y":0},{"name":"end","x":bounds.width-bounds.width~/2,"y":0}];
    		layer["platformLines"] = [defaultPlatform];	
		}
		layer["ladders"] = [];
		layer["walls"] = [];
		layerMap[layer["name"]] = layer;
	});
	
	dynamicMap["layers"] = layerMap;
	
	if(currentStreet != null)
	{
		//download file
		var pom = document.createElement('a');
        pom.setAttribute('href', 'data:application/json;charset=utf-8,' + Uri.encodeComponent(JSON.encode(streetMap)));
        pom.setAttribute('download', streetMap["label"]+".street");
        pom.click();	
	}
        
	return streetMap;
}

void updateBounds(num left, num top, num width, num height)
{
	bounds = new Rectangle(left,top,width,height);
}