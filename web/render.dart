part of CoUMapFiller;

DateTime now, lastUpdate = new DateTime.now();

// Our renderloop
render() 
{		
	//Draw Street
	if (currentStreet is Street)
		currentStreet.render();
	//Draw Player
	if(CurrentPlayer is Player)
		CurrentPlayer.render();
}