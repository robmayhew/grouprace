# Race Game minimama vialbe

.1 A very basic car interface.
	- Car provides
		- character body 2d stats. Used by the pysics engine
		
	- Car will collide with other physics objects. Moving them, being effected etc
		- Most interaction will come from the pysics engine. The main will monitor.

.2 a very basic mao interface
	- mao will provide waypoint aresa. Track is complete when all aresa have been hit.


.3 Game have two Cameras. one for each player. Also handles the controls for both.
	- cars loaded by folder. Just look for the scene with the interface and load it.

Main engine -  Define a playable bounds. Don't allow a car outside of it
			-  Add a score
			- Support multiple joypads 
			- support damage when colliding. (Don't allow the user to define this?)
