part of CoUMapFiller;

UserInterface ui = new UserInterface();

class UserInterface 
{
	num gameScreenWidth, gameScreenHeight, gameScreenTop;
	DivElement progressIndicator;
	ImageElement preview;
	
	init()
	{
		//Start listening for page resizes.
		resize();
		window.onResize.listen((_) => resize());
	}
	
	resize()
    {
    	Element gameScreen = querySelector('#GameScreen');
    	
    	gameScreenWidth = gameScreen.clientWidth;
    	gameScreenHeight = gameScreen.clientHeight;
    	gameScreenTop = gameScreen.getBoundingClientRect().top;
    }
}