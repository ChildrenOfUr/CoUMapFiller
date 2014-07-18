part of CoUMapFiller;

num startX, startY, startWidth, startHeight;
StreamSubscription mousemove, mouseup;
Element resizeElement;

void addResizeListener(Element elementToResize, Element resizeHandle)
{
	resizeElement = elementToResize;
	resizeHandle.onMouseDown.listen((MouseEvent e)
	{
		e.stopPropagation();
		initDrag(e);
	});
}

void initDrag(MouseEvent e) 
{
	startX = e.client.x;
	startY = e.client.y;
	startWidth = num.parse(resizeElement.getComputedStyle().width.replaceAll("px", ""));
	startHeight = num.parse(resizeElement.getComputedStyle().height.replaceAll("px", ""));
	mousemove = document.body.onMouseMove.listen((MouseEvent e) => doDrag(e));
	mouseup = document.body.onMouseUp.listen((MouseEvent e) => stopDrag(e));
}

void doDrag(MouseEvent e) 
{
   resizeElement.style.width = (startWidth + e.client.x - startX).toString() + 'px';
   resizeElement.style.height = (startHeight + e.client.y - startY).toString() + 'px';
}

void stopDrag(MouseEvent e) 
{
    mousemove.cancel();
    mouseup.cancel();
}