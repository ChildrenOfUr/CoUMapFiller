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
part 'maps_data.dart';

String currentLayer = "EntityHolder", tsid, initialPopupWidth, initialPopupHeight;
String serverAddress = "http://localhost:8181";
int width = 3000 , height = 1000;
DivElement gameScreen, layers;
Rectangle bounds;
Random rand = new Random();
StreamSubscription moveListener, clickListener;
bool madeChanges = false;

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
    	saveToServer();
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
			tsid = JSON.decode(event.data)['tsid'];
			if(tsid.startsWith("G"))
				tsid = tsid.replaceFirst("G", "L");
			
			DivElement popup = querySelector("#PreviewWindow");
            popup.hidden = false;
            querySelector("#LoadingPreview").hidden = false;
			
            displayPreview(JSON.decode(event.data));
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

void displayPreview(Map streetData)
{
	String imageUrl = streetData['main_image']['url'];
	String hub = streetData['hub_id'];
	String tsid = streetData['tsid'];
	
	DataMaps map = new DataMaps();
	Map<String,String> hubInfo = map.data_maps_hubs[hub]();
	String region = hubInfo['name'];
	if(region == "Ix" || region == "Uralia" || region == "Chakra Phool")
	{
		if(region == "Chakra Phool")
			region = "Firebog";
		
		querySelector("#NormalShrines").style.display = "none";
		querySelector("#${region}Shrines").style.display = "block";
	}
	else
		querySelector("#NormalShrines").style.display = "block";
		
	num width,height;
	DivElement popup = querySelector("#PreviewWindow");
	ImageElement preview = querySelector("#Preview");
	popup.hidden = false;
	if(initialPopupWidth == null)
	{
		initialPopupWidth = (popup.clientWidth+15).toString()+"px";
    	initialPopupHeight = "calc("+popup.clientHeight.toString()+"px"+" - 2em)";
	}
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
		loadExistingEntities(JSON.decode(response));
	});
	
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
		
		popup.style.width = "initial";
		popup.style.height = "initial";
		
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
	});
}

void minimizePopup()
{
	DivElement popup = querySelector("#PreviewWindow");
   	ImageElement preview = querySelector("#Preview");
   	Element popupAction = querySelector("#PopupAction");
   	UListElement missing = querySelector("#MissingEntities");
   	
   	popupAction.classes.toggle("fa-chevron-down");
   	popupAction.classes.toggle("fa-chevron-up");
   	popupAction.onClick.first.then((_) => maximizePopup());
	preview.hidden = true;
	missing.style.display = "none";
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
    UListElement missing = querySelector("#MissingEntities");
   	
    num height = num.parse(preview.attributes['scaledHeight']);
    num width = num.parse(preview.attributes['scaledWidth']);
   	popupAction.classes.toggle("fa-chevron-down");
   	popupAction.classes.toggle("fa-chevron-up");
   	popupAction.onClick.first.then((_) => minimizePopup());
   	missing.style.display = "inline-block";
    preview.hidden = false;
    preview.height = height;
	popup.style.width = "initial";
	popup.style.height = "calc("+height.toString()+"px" + " + 2em)";
	popup.style.bottom = "initial";
	popup.style.right = "initial";
	popup.style.top = "25px";
	popup.style.left = "0px";
}

void saveToServer()
{
	if(!madeChanges)
		return;
	
	List<Map> entities = [];
	querySelectorAll(".placedEntity").forEach((Element element)
	{
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
		entities.add(entity);
	});
	
	Map data = {'tsid':tsid,'entities':JSON.encode(entities)};
	HttpRequest.postFormData("$serverAddress/entityUpload",data).then((HttpRequest request) => print(request.response));
}

void loadLocationJson()
{
	if(madeChanges)
	{
		Element saveDialog = querySelector("#SaveDialog");
		saveDialog.hidden = false;
		querySelector("#SaveYes").onClick.first.then((_)
		{
			saveDialog.hidden = true;
			saveToServer();
		});
		querySelector("#SaveNo").onClick.first.then((_) => saveDialog.hidden = true);
	}
	
	TextInputElement locationInput = querySelector("#LocationCodeInput");
	String location = locationInput.value;
	if(location != "")
	{
		locationInput.blur();
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
		
		clickListener = getClickListener(drag,event);
		moveListener = getMoveListener(drag);
	});
}

StreamSubscription getClickListener(DivElement drag, MouseEvent event)
{
	drag.style.top = (event.page.y-drag.client.height).toString()+"px";
	drag.style.left = event.page.x.toString()+"px";
	document.body.append(drag);
	Element layer = querySelector("#$currentLayer");
	clickListener = layer.onClick.listen((MouseEvent event)
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
        drag.classes.add("placedEntity");
        drag.classes.remove("dashedBorder");
        
        layer.append(drag);
        madeChanges = true;
        crossOff(drag);

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
		drag.style.top = (event.page.y-drag.clientHeight).toString()+"px";
        drag.style.left = (event.page.x+1).toString()+"px";
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
	String type = normalizeType(placed);
	
	//now check the list for an un-crossed-out instance of type
	bool found = false;
	missingEntities.children.forEach((Element listItem)
	{
		if(!found && listItem.text.contains(type) && !listItem.classes.contains("crossedOff"))
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
		if(listItem.text.contains(type) && listItem.classes.contains("crossedOff"))
		{
			numOnList++;
			if(found == null)
				found = listItem;
		}
	});
    
    //only uncross off an item if there are not enough left on screen after removal of this one
    if(numOnList > numOfType - 1)
    {
    	found.classes.remove("crossedOff");
        missingEntities.insertBefore(found, missingEntities.children.first);	
    }
}

String normalizeType(Element placed)
{
	String type = placed.attributes['type'];
	if(type == "Img" || type == "Mood" || type == "Energy" || type == "Currant"
    	|| type == "Mystery" || type == "Favor" || type == "Time" || type == "Quarazy")
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