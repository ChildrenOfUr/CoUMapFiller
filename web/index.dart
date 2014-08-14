library CoUMapFiller;

import "dart:html";
import "dart:math";
import "dart:async";
import "dart:convert";
import "dart:js" as js;

import 'package:libld/libld.dart'; // Nice and simple asset loading.

part 'loop.dart';
part 'render.dart';
part 'street.dart';
part 'player.dart';
part 'animation.dart';
part 'input.dart';
part 'ui.dart';
part 'divResizer.dart';

part 'preview_window.dart';

part 'shrines_and_vendors.dart';
part 'maps_data.dart';

String currentLayer = "EntityHolder", tsid, initialPopupWidth, initialPopupHeight;
String serverAddress = "http://robertmcdermot.com:8080";
int width = 3000 , height = 1000;
DivElement gameScreen, layers;
Rectangle bounds;
Random rand = new Random();
StreamSubscription moveListener, clickListener, stopListener;
bool madeChanges = false, popupMinimized = false;

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
	if(window.localStorage['showTut'] != "false")
	{
		querySelector("#motdWindow").hidden = false;
		(querySelector("#doNotShow") as CheckboxInputElement).checked = false;
	}
		
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
    	saveToServer();
		generateButton.classes.add("shadow");
	});
    
    querySelector('#LocationCodeForm').onSubmit.listen((Event e)
    {
    	e.preventDefault();
    	loadLocationJson();
    });
    
    querySelector("#LocationCodeButton").onClick.listen((_) => loadLocationJson());
    querySelector("#RandomStreet").onClick.listen((_)
	{
    	HttpRequest.getString("$serverAddress/getRandomStreet").then((String response)
    	{
    		(querySelector("#LocationCodeInput") as InputElement).value = response;
    		loadLocationJson();
    	});
	});
    
    window.onMessage.listen((MessageEvent event)
	{
    	showToast("Loading...",untilCanceled:true, immediate:true);
    	if(madeChanges && tsid != null)
    	{
    		showSaveWindow(()
			{
    			loadStreet(JSON.decode(event.data)).then((_)
        		{
        			//load a preview image of the street
        			tsid = JSON.decode(event.data)['tsid'];
        			if(tsid.startsWith("G"))
        				tsid = tsid.replaceFirst("G", "L");
        			
                    displayPreview(JSON.decode(event.data)).then((_) => cancelToast());
        		});
			});
    	}
    	else
    	{
    		loadStreet(JSON.decode(event.data)).then((_)
    		{
    			//load a preview image of the street
    			tsid = JSON.decode(event.data)['tsid'];
    			if(tsid.startsWith("G"))
    				tsid = tsid.replaceFirst("G", "L");
    			
                displayPreview(JSON.decode(event.data)).then((_) => cancelToast());;
    		});
    	}
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

Future displayPreview(Map streetData)
{
	Completer c = new Completer();
	
	Element existingPreview = querySelector("#PreviewWindow");
	if(existingPreview != null)
		existingPreview.remove();
	
	String imageUrl = streetData['main_image']['url'];
	String hub = streetData['hub_id'];
	String tsid = streetData['tsid'];
	
	DataMaps map = new DataMaps();
	Map<String,String> hubInfo = map.data_maps_hubs[hub]();
	String region = hubInfo['name'];
	if(region == "Ix" || region == "Uralia" || region == "Chakra Phool" || region == "Kalavana"
		|| region == "Shimla Mirch" || region.contains("Ilmenskie"))
	{
		if(region == "Chakra Phool" || region == "Kalavana" || region == "Shimla Mirch")
			region = "Firebog";
		
		if(region.contains("Ilmenskie"))
			region = "Uralia";
		
		querySelector("#NormalShrines").style.display = "none";
		querySelector("#${region}Shrines").style.display = "block";
	}
	else
		querySelector("#NormalShrines").style.display = "block";
		
	num width,height;
	document.body.append(PreviewWindow.create());
	DivElement popup = querySelector("#PreviewWindow");
	ImageElement preview = querySelector("#Preview");
	Element resizeHandle = querySelector("#ResizeHandle");
	//addResizeListener(popup,resizeHandle);
	ui.progressIndicator = querySelector("#ProgressIndicator");
	ui.preview = preview;
	popup.hidden = false;
	querySelector("#LoadingPreview").hidden = false;
    	
	if(popupMinimized)
		popup.style.opacity = "0";
	
	initialPopupWidth = (popup.clientWidth+15).toString()+"px";
	initialPopupHeight = "calc("+popup.clientHeight.toString()+"px"+" - 2em)";
	popup.attributes['initialWidth'] = initialPopupWidth;
	popup.attributes['initialHeight'] = initialPopupHeight;
	
	UListElement missingEntities = querySelector("#MissingEntities");
	missingEntities.children.clear();
	List<Map<String,String>> objrefs = streetData['objrefs'];
	objrefs.forEach((Map<String,String> entity)
	{
		LIElement missing = new LIElement();
		missing.text = "${entity['label']} (${entity['tsid']})";
		missingEntities.append(missing);
	});
	if(shrines.containsKey(tsid))
	{
		LIElement missing = new LIElement();
		missing.text = "A shrine to ${capitalizeFirstLetter(shrines[tsid])}";
		missingEntities.append(missing);
	}
	if(vendors.containsKey(tsid))
	{
		LIElement missing = new LIElement();
		missing.text = "${vendors[tsid]} Vendor";
		missingEntities.append(missing);
	}
	
	//and cross off (and display) ones that already exist
	HttpRequest.getString("$serverAddress/getEntities?tsid=$tsid").then((String response)
	{
		Map entities = JSON.decode(response);
		if(entities['entities'] != null)
			loadExistingEntities(entities);
	});
	
	Element popupAction = querySelector("#PopupAction");
	popupAction.onClick.first.then((_) => minimizePopup());
	
	preview.src = imageUrl;
	preview.onLoad.listen((_)
	{
		preview.hidden = false;
		height = preview.naturalHeight;
		width = preview.naturalWidth;
		num widthToHeight = width/height;
		if(height > width && height > window.innerHeight - 100)
		{
			height = window.innerHeight - 100;
			width = widthToHeight*height;
			preview.height = height;
			preview.width = width.toInt();
		}
		else if(width > height && width > window.innerWidth - 100)
		{
			width = window.innerWidth - 100;
			height = width/widthToHeight;
			preview.width = width;
			preview.height = height.toInt();
		}
				
		preview.attributes['scaledHeight'] = height.toString();
		preview.attributes['scaledWidth'] = width.toString();
		querySelector("#LoadingPreview").hidden = true;
		
		preview.onClick.listen((MouseEvent event)
		{
			num percentX = event.offset.x/width;
			num percentY = event.offset.y/height;
			CurrentPlayer.posX = percentX*currentStreet.streetBounds.width;
			CurrentPlayer.posY = percentY*currentStreet.streetBounds.height;
			event.stopPropagation();
		});
		
		missingEntities.style.maxHeight = height.toString()+"px";
		
		popup.onMouseDown.listen((MouseEvent event)
		{
			if(event.button != 0)
				return;
			
			num offsetX = event.layer.x;
			num offsetY = event.layer.y;
			
			StreamSubscription move = window.onMouseMove.listen((MouseEvent event)
			{
				popup.style.left = (event.client.x - offsetX).toString()+"px";
				popup.style.top = (event.client.y - offsetY).toString()+"px";
			});
			window.onMouseUp.first.then((_) => move.cancel());
		});
		
		if(popupMinimized)
		{
			minimizePopup();
			popup.style.opacity = "initial";
		}
		
		c.complete();
	});
	
	return c.future;
}

void minimizePopup()
{
	DivElement popup = querySelector("#PreviewWindow");
   	ImageElement preview = querySelector("#Preview");
   	Element popupAction = querySelector("#PopupAction");
   	UListElement missing = querySelector("#MissingEntities");
   	DivElement progress = querySelector("#ProgressIndicator");
   	
   	popupAction.classes.remove("fa-chevron-down");
    popupAction.classes.add("fa-chevron-up");
    popupAction.onClick.first.then((_) => maximizePopup());
	preview.hidden = true;
	progress.hidden = true;
	missing.style.display = "none";
	popup.style.bottom = "0px";
	popup.style.right = "0px";
	popup.style.top = "initial";
	popup.style.left = "initial";
	popup.style.width = popup.attributes['initialWidth'];
	popup.style.height = popup.attributes['initialHeight'];
	
	popupMinimized = true;
}

void maximizePopup()
{
	DivElement popup = querySelector("#PreviewWindow");
    ImageElement preview = querySelector("#Preview");
    Element popupAction = querySelector("#PopupAction");
    UListElement missing = querySelector("#MissingEntities");
    DivElement progress = querySelector("#ProgressIndicator");
   	
    num height = num.parse(preview.attributes['scaledHeight']);
    num width = num.parse(preview.attributes['scaledWidth']);
    popupAction.classes.add("fa-chevron-down");
    popupAction.classes.remove("fa-chevron-up");
    popupAction.onClick.first.then((_) => minimizePopup());
   	missing.style.display = "inline-block";
    preview.hidden = false;
    progress.hidden = false;
    preview.height = height;
	popup.style.width = "initial";
	popup.style.height = "calc("+height.toString()+"px" + " + 2em)";
	popup.style.bottom = "initial";
	popup.style.right = "initial";
	popup.style.top = "25px";
	popup.style.left = "0px";
	
	popupMinimized = false;
}

void showToast(String message, {bool untilCanceled: false, bool immediate: false})
{
	Element toastMessage = querySelector("#ToastMessage");
    Element toast = querySelector("#Toast");
    if(immediate)
    	toast.style.transition = "none";
    toastMessage.text = message;
    toast.style.opacity = "initial";
    
    if(!untilCanceled)
    	new Timer(new Duration(seconds:2), () => cancelToast());
}

void cancelToast()
{
	Element toast = querySelector("#Toast");
	toast.style.transition = "all 1s linear";
	toast.style.opacity = "0";
}

void saveToServer()
{    
	if(!madeChanges || tsid == null)
	{
		if(!madeChanges)
			showToast("No changes to save.");
		if(tsid == null)
			showToast("No street loaded.");
		
		return;
	}
	
	List<Map> entities = [];
	int complete = 0;
	querySelectorAll(".placedEntity").forEach((Element element)
	{
		complete++;
		Map entity = {};
		String url = element.getComputedStyle().backgroundImage.replaceAll("url(", "");
		url = url.substring(0,url.length-1);
		entity['type'] = element.attributes['type'];
		entity['url'] = url;
		entity['animationRows'] = int.parse(element.attributes['rows']);
		entity['animationColumns'] = int.parse(element.attributes['columns']);
		entity['animationNumFrames'] = int.parse(element.attributes['frames']);
		entity['x'] = num.parse(element.style.left.replaceAll("px", "")).toInt();
		entity['y'] = currentStreet.streetBounds.height-num.parse(element.style.top.replaceAll("px", "")).toInt()-element.client.height;
		if(element.attributes['flipped'] != null)
			entity['hflip'] = "true";
		if(element.attributes['rotation'] != null)
			entity['rotation'] = int.parse(element.attributes['rotation']);
		entities.add(entity);
	});
	
	int required = querySelector("#MissingEntities").children.length;
	Map data = {'tsid':tsid,'entities':JSON.encode(entities),'required':required,'complete':complete};
	HttpRequest.postFormData("$serverAddress/entityUpload",data).then((HttpRequest request)
	{
		if(request.response == "OK")
		{
			showToast("Entities Saved");
			madeChanges = false;
		}
		else
			showToast("There was a problem, try again later.");
	});
}

void showSaveWindow(Function onResponse)
{
	Element saveDialog = querySelector("#SaveDialog");
	saveDialog.hidden = false;
	querySelector("#SaveYes").onClick.first.then((_)
	{
		saveDialog.hidden = true;
		saveToServer();
		onResponse();
	});
	querySelector("#SaveNo").onClick.first.then((_)
	{
		saveDialog.hidden = true;
		madeChanges = false;
		onResponse();
	});
	
	return;
}

loadLocationJson()
{
	if(madeChanges && tsid != null)
		showSaveWindow(loadLocationJson);
		
	TextInputElement locationInput = querySelector("#LocationCodeInput");
	String location = locationInput.value;
	if(location != "")
	{
		String loc = location;
		locationInput.blur();
		if(location.startsWith("L"))
			location = location.replaceFirst("L", "G");
		String url = "http://RobertMcDermot.github.io/CAT422-glitch-location-viewer/locations/$location.callback.json";
		ScriptElement loadStreet = new ScriptElement();
		loadStreet.src = url;
		loadStreet.onError.first.then((Event e) => showToast("Failed to load $loc"));
        document.body.append(loadStreet);
	}
}

void setupListener(DivElement entityParent)
{	
	DivElement entity = entityParent.querySelector(".centerEntity");
	entityParent.onMouseDown.listen((MouseEvent event)
	{
		Element alreadyPickedUp = querySelector(".dashedBorder");
    	if(alreadyPickedUp != null)
    	{
    		if(alreadyPickedUp.classes.contains("placedEntity"))
    		{
    			stop(alreadyPickedUp);
    			return;
    		}
    		
    		alreadyPickedUp.remove();
    		if(clickListener != null)
    			clickListener.cancel();
    		if(moveListener != null)
    			moveListener.cancel();
    	}
        	
		DivElement drag = new DivElement();
		CssStyleDeclaration style = entity.getComputedStyle();
		int scale = 4;
		if(entity.attributes['scale'] != null)
			scale = int.parse(entity.attributes['scale']);
		num width = num.parse(style.width.replaceAll("px", "")) * scale;
		num height = num.parse(style.height.replaceAll("px", "")) * scale;
		drag.style.backgroundImage = style.backgroundImage;
		drag.style.backgroundPosition = style.backgroundPosition;
		drag.attributes['type'] = entity.id;
		drag.attributes['rows'] = entity.attributes['rows'];
		drag.attributes['columns'] = entity.attributes['columns'];
		drag.attributes['frames'] = entity.attributes['frames'];
		drag.style.position = "absolute";
		drag.style.width = width.toString()+"px";
		drag.style.height = height.toString()+"px";
		drag.style.top = (event.client.y-height).toString()+"px";
		drag.style.left = event.client.x.toString()+"px";
		drag.classes.add("dashedBorder");
		document.body.append(drag);
		
		Element layer = querySelector("#$currentLayer");
		Element toolbox = querySelector("#ToolBox");
		layer.classes.add("moveCursor");
		toolbox.classes.add("moveCursor");
		layer.classes.remove("stillCursor");
		toolbox.classes.remove("stillCursor");
		
		stopListener = querySelector("#ToolBox").onMouseUp.listen((_) => stop(drag));
		clickListener = getClickListener(drag,event);
		moveListener = getMoveListener(drag);
		
		event.stopPropagation();
	});
}

void stop(Element drag)
{
	Element layer = querySelector("#$currentLayer");
	Element toolbox = querySelector("#ToolBox");
	layer.classes.remove("moveCursor");
	toolbox.classes.remove("moveCursor");
	layer.classes.add("stillCursor");
	toolbox.classes.add("stillCursor");
	drag.remove();
	moveListener.cancel();
	clickListener.cancel();
	stopListener.cancel();
}

StreamSubscription getClickListener(DivElement drag, MouseEvent event)
{
	num percentX = event.page.x/ui.gameScreenWidth;
	num percentY = (event.page.y-ui.gameScreenTop)/ui.gameScreenHeight;
	if(percentX > 1)
		percentX = 1;
	if(percentY > 1)
		percentY = 1;
	num dragX = percentX*drag.client.width-drag.client.width;
	num dragY = percentY*drag.client.height;
	
	drag.style.top = (event.page.y-drag.client.height+dragY).toString()+"px";
	drag.style.left = (event.page.x+dragX).toString()+"px";
	document.body.append(drag);
	Element layer = querySelector("#$currentLayer");
	clickListener = layer.onMouseUp.listen((MouseEvent event)
	{		
		num percentX = event.page.x/ui.gameScreenWidth;
		num percentY = (event.page.y-ui.gameScreenTop)/ui.gameScreenHeight;
		if(percentX > 1)
			percentX = 1;
		if(percentY > 1)
			percentY = 1;
		num dragX = percentX*drag.client.width-drag.client.width;
		num dragY = percentY*drag.client.height;
		
		num x,y;
		//if we clicked on another deco inside the target layer
		if((event.target as Element).id != layer.id)
		{
			y = (event.target as Element).offset.top+event.offset.y;
			x = (event.target as Element).offset.left+event.offset.x;
		}
		//else we clicked on empty space in the layer
		else
		{
			y = event.offset.y;
			x = event.offset.x;
		}
		drag.style.top = (y-drag.clientHeight+dragY).toString()+"px";
        drag.style.left = (x+dragX).toString()+"px";
        drag.classes.add("placedEntity");
        drag.classes.remove("dashedBorder");
        
        layer.append(drag);
		Element toolbox = querySelector("#ToolBox");
		layer.classes.remove("moveCursor");
		toolbox.classes.remove("moveCursor");
		layer.classes.add("stillCursor");
		toolbox.classes.add("stillCursor");
        madeChanges = true;
        crossOff(drag);

        stopListener.cancel();
        moveListener.cancel();
        clickListener.cancel();
	});
	
	return clickListener;
}

StreamSubscription getMoveListener(DivElement drag)
{
	drag.classes.add("dashedBorder");
	document.body.append(drag);
	moveListener = document.body.onMouseMove.listen((MouseEvent event)
	{
		num percentX = event.page.x/ui.gameScreenWidth;
		num percentY = (event.page.y-ui.gameScreenTop)/ui.gameScreenHeight;
		if(percentX > 1)
			percentX = 1;
		if(percentY > 1)
			percentY = 1;
		num dragX = percentX*drag.client.width-drag.client.width;
		num dragY = percentY*drag.client.height;
		
		num height = num.parse(drag.style.height.replaceAll("px", ""));
		drag.style.top = (event.page.y-height+dragY).toString()+"px";
        drag.style.left = (event.page.x+dragX).toString()+"px";
	});
	
	return moveListener;
}

void loadExistingEntities(Map entities)
{
	entities['entities'].forEach((Map ent)
	{
		String type = ent['type'];
		Element entity = querySelector("#$type");
		
		DivElement drag = new DivElement();
		CssStyleDeclaration style = entity.getComputedStyle();
		int scale = 4;
		if(entity.attributes['scale'] != null)
			scale = int.parse(entity.attributes['scale']);
		num width = num.parse(style.width.replaceAll("px", "")) * scale;
		num height = num.parse(style.height.replaceAll("px", "")) * scale;
		
		num x = ent['x'];
        num y = currentStreet.streetBounds.height-ent['y']-height;
        		
		drag.style.backgroundImage = style.backgroundImage;
		drag.style.backgroundPosition = style.backgroundPosition;
		drag.attributes['type'] = entity.id;
		drag.attributes['rows'] = entity.attributes['rows'];
		drag.attributes['columns'] = entity.attributes['columns'];
		drag.attributes['frames'] = entity.attributes['frames'];
		drag.style.position = "absolute";
		drag.style.width = width.toString()+"px";
		drag.style.height = height.toString()+"px";
		drag.style.top = y.toString()+"px";
		drag.style.left = x.toString()+"px";
		drag.classes.add("placedEntity");
		querySelector("#$currentLayer").append(drag);
		
		crossOff(drag);
	});
}

void crossOff(Element placed)
{
	UListElement missingEntities = querySelector("#MissingEntities");
	if(missingEntities == null)
		return;
	
	String type = normalizeType(placed);
	
	//now check the list for an un-crossed-out instance of type
	bool found = false;
	missingEntities.children.forEach((Element listItem)
	{
		String listText = listItem.text.replaceAll("Coin", "Quoin").replaceAll("Qurazy", "Quarazy");
		if(!found && listText.toLowerCase().contains(type.toLowerCase()) && !listItem.classes.contains("crossedOff"))
		{
			listItem.classes.add("crossedOff");
			missingEntities.append(listItem);
			found = true;
		}
	});
}

void unCrossOff(Element removed)
{
	UListElement missingEntities = querySelector("#MissingEntities");
	if(missingEntities == null)
		return;
	
	String type = normalizeType(removed);
    int numOfType = 0;
    querySelectorAll(".placedEntity").forEach((Element placedEntity)
	{
		if(normalizeType(placedEntity) == type)
			numOfType++;
	});
	    
    //now check the list for a crossed-out instance of type
    Element found = null;
    int numOnList = 0;
    missingEntities.children.forEach((Element listItem)
	{
    	String listText = listItem.text.replaceAll("Coin", "Quoin").replaceAll("Qurazy", "Quarazy");
		if(listText.toLowerCase().contains(type.toLowerCase()) && listItem.classes.contains("crossedOff"))
		{
			numOnList++;
			if(found == null)
				found = listItem;
		}
	});
    
    //only uncross off an item if there are not enough left on screen after removal of this one
    if(numOnList > numOfType - 1)
    {
    	if(found != null)
    	{
    		found.classes.remove("crossedOff");
        	missingEntities.insertBefore(found, missingEntities.children.first);	
     	}
    }
}

String normalizeType(Element placed)
{
	String type = placed.attributes['type'];
	if(type == "Img" || type == "Mood" || type == "Energy" || type == "Currant"
    	|| type == "Mystery" || type == "Favor" || type == "Time")
	{
        	type = "Quoin";
	}
	
	//check for camel case and insert a space if so
	for(int i=1; i<type.length; i++)
	{
		String char = type[i];
		if(char == char.toUpperCase())
		{
			type = type.substring(0,i) + " " + type.substring(i,type.length);
			i++; //skip past the space
		}
	}
	
	type = type.replaceAll(" Ix",""); type = type.replaceAll(" Firebog",""); 
	type = type.replaceAll(" Uralia",""); type = type.replaceAll(" Groddle",""); 
	type = type.replaceAll(" Zutto","");
	
	return type;
}

Future loadStreet(Map streetData)
{
	Completer c = new Completer();
	layers.children.clear();
        	
	CurrentPlayer.doPhysicsApply = false;
	currentStreet = new Street(streetData);
	currentStreet.load().then((_)
	{
		width = currentStreet.streetBounds.width;
    	height = currentStreet.streetBounds.height;
    	updateBounds(0,0,width,height);
    	querySelector("#Location").text = currentStreet.label;
    	c.complete();
   	});
	return c.future;
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

String capitalizeFirstLetter(String string)
{
    return string[0].toUpperCase() + string.substring(1);
}

void rotate(Element element, int degrees)
{
	int rotation = degrees;
	if(element.attributes['rotation'] != null)
		rotation += int.parse(element.attributes['rotation']);
	
	element.attributes['rotation'] = rotation.toString();
	element.style.transform = "rotate(${rotation}deg)";
	
	if(element.attributes['flipped'] != null)
		element.style.transform += " scale(-1,1)";
}

void flip(Element element)
{
	if(element.attributes['flipped'] != null)
	{
		element.attributes.remove('flipped');
		if(element.attributes['rotation'] != null)
			element.style.transform = "rotate(${element.attributes['rotation']}deg)";
		else
			element.style.transform = "scale(1,1)";
	}
	else
	{
		element.attributes['flipped'] = "true";
		if(element.attributes['rotation'] != null)
        	element.style.transform = "rotate(${element.attributes['rotation']}deg) scale(-1,1)";
        else
        	element.style.transform = "scale(-1,1)";	
	}
}

void delete([Element element])
{
	if(element != null)
		element.classes.add("dashedBorder");
	
	clickListener.cancel();
	moveListener.cancel();
	querySelectorAll(".dashedBorder").forEach((Element element)
	{
		unCrossOff(element);
		element.remove();
		madeChanges = true;
	});
}