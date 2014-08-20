part of CoUMapFiller;

class PreviewWindow
{
	static Element create()
	{
		DivElement previewWindow = new DivElement()..id="PreviewWindow"..className="PopWindow";
		
		DivElement header = new DivElement()..className="PopWindowHeader handle"..text="Street Preview (click and drag to move)";
		SpanElement action = new SpanElement()..id="PopupAction"..className="fa fa-chevron-down fa-lg"..attributes['style']="float:right";
		header.append(action);
		
		DivElement content = new DivElement()..className="PopupContent";
		SpanElement preview = new SpanElement()..id="LoadingPreview"..text="Loading Preview";
		DivElement holder = new DivElement()..id="PreviewHolder";
		ImageElement previewImg = new ImageElement()..id="Preview";
		DivElement progress = new DivElement()..id="ProgressIndicator"..className="progress";
		holder..append(previewImg)..append(progress);
		
		UListElement missing = new UListElement()..id="MissingEntities";
		
		content..append(preview)..append(holder)..append(missing);
		
		previewWindow..append(header)..append(content);
		
		return previewWindow;
	}
	
	static void destroy()
	{
		querySelector("#PreviewWindow").remove();
	}
}