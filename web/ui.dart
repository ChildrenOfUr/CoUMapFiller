part of CoUMapFiller;

UserInterface ui = new UserInterface();

class UserInterface 
{
	num gameScreenWidth, gameScreenHeight;
	
	init()
	{
		//Start listening for page resizes.
		resize();
		window.onResize.listen((_) => resize());
	}
	
	resize()
    {
    	Element gameScreen = querySelector('#GameScreen');
    	
    	ui.gameScreenWidth = gameScreen.clientWidth;
    	ui.gameScreenHeight = gameScreen.clientHeight;
    }
}