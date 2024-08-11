#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\gametypes_zm\_hud_message;
#include maps\mp\zombies\_zm;

init()
{
    precacheshader("waypoint_revive");
    precacheshader("scorebar_zom_1");
    setExfillocation();
    if (level.radiomodel != "")
    {
    	precachemodel(level.radiomodel);
    }
    level thread createExfilIcon();
    level.roundincrease = 5;
    level.canexfil = 0;
    level.nextexfilround = 11;
    level.exfilstarted = 0;
    level.successfulexfil = 0;
    level.gameisending = 0;
    level.exfilplayervotes = 0;
    level thread spawnExfil();
    level thread enableExfil();
    level thread checkForRound();
	
	level.round_wait_func = ::round_wait_exfil;
    
    level thread onPlayerConnect();
}

onPlayerConnect()
{
    for(;;)
    {
        level waittill("connected", player);
        player thread onPlayerSpawned();
    }
}

onPlayerSpawned()
{
    self endon("disconnect");
	level endon("game_ended");
    for(;;)
    {
        self waittill("spawned_player");

		self thread exfilHUD();
		self thread downOnExfil();
		self thread showscoreboardtext();
		self iprintln("^4Exfil ^7created by ^1techboy04gaming");
    }
}

createExfilIcon()
{
	exfil_icon = newHudElem();
    exfil_icon.x = level.iconlocation[ 0 ];
    exfil_icon.y = level.iconlocation[ 1 ];
	exfil_icon.z = level.iconlocation[ 2 ] + 80;
	exfil_icon.color = (1,1,1);
    exfil_icon.isshown = 1;
    exfil_icon.archived = 0;
    exfil_icon setshader( "waypoint_revive_zm", 6, 6 );
    exfil_icon setwaypoint( 1 );
    
    while(1)
    {
    	if (level.canexfil == 1 && level.exfilstarted == 0)
    	{
    		exfil_icon.alpha = 1;
    	}
    	else if (level.canexfil == 1 && level.exfilstarted == 1)
    	{
    		exfil_icon.alpha = 1;
    		exfil_icon.x = level.exfillocation[ 0 ];
    		exfil_icon.y = level.exfillocation[ 1 ];
 			exfil_icon.z = level.exfillocation[ 2 ] + 80;
			exfil_icon setshader( "waypoint_revive_zm", 0, 0 );
			exfil_icon setwaypoint( 1, "waypoint_revive_zm", 1 );
    	}
    	else if (level.canexfil == 0 && level.exfilstarted == 0)
    	{
    		exfil_icon.alpha = 0;
    	}
    	if (level.gameisending == 1)
    	{
    		exfil_icon.alpha = 0;
    	}
    	wait 0.1;
    }
}

checkForRound()
{
	while(1)
	{
		if(level.round_number == level.nextexfilround)
		{
			level.nextexfilround += level.roundincrease;
			level notify ("can_exfil");
		}
		wait 0.5;
	}
}

enableExfil()
{
	while(1)
	{
		level waittill ("can_exfil");
		level endon ("exfil_started");
		level.canexfil = 1;
		
		foreach ( player in get_players() )
	       	player thread showExfilMessage();

		wait 120;
		level.canexfil = 0;

		foreach ( player in get_players() )
        	player thread showExfilMessage();
	}
}

spawnExfil()
{
	exfilTrigger = spawn( "trigger_radius", (level.iconlocation), 1, 50, 50 );
	exfilTrigger setHintString("");
	exfilTrigger setcursorhint( "HINT_NOICON" );
	if (level.radiomodel != "")
	{
		exfilModel = spawn( "script_model", (level.iconlocation));
		exfilModel setmodel ("p6_zm_buildable_sq_transceiver");
		exfilModel rotateTo(level.radioangle,.1);
	}
	
	while(1)
	{
		exfilTrigger waittill( "trigger", i );
		if (level.exfilstarted == 0 && level.canexfil == 1)
		{
			if ( i usebuttonpressed() )
			{
				
				if (level.exfilvoting == 0)
				{
					level.exfilplayervotes = 0;
					level.exfilvoting = 1;

					level.exfilplayervotes += 1;
					self.exfilvoted = 1;
					if (level.exfilplayervotes >= level.players.size)
					{
						level.votingsuccess = 1;
						level notify ("voting_finished");
					}

					level thread exfilVoteTimer();
					foreach ( player in get_players() )
					{
						player thread showvoting(i);
						player thread checkVotingInput();
						player.canrespawn = 0;
					}
					
					if (level.votingsuccess != 1)
					{
						level waittill_any ("voting_finished","voting_expired");
					}

					if (level.votingsuccess == 1)
						{
						level.exfilvoting = 0;
						earthquake( 0.5, 0.5, self.origin, 800 );
						foreach ( player in get_players() )
						{
							player playsound( "evt_nuke_flash" );
						}
						fadetowhite = newhudelem();
						fadetowhite.x = 0;
						fadetowhite.y = 0;
						fadetowhite.alpha = 0;
						fadetowhite.horzalign = "fullscreen";
						fadetowhite.vertalign = "fullscreen";
						fadetowhite.foreground = 1;
						fadetowhite setshader( "white", 640, 480 );
						fadetowhite fadeovertime( 0.2 );
						fadetowhite.alpha = 1;
						wait 1;
					
						level.exfilstarted = 1;
						level thread fixZombieTotal();
						level thread change_zombies_speed("sprint");
						level.zombie_vars[ "zombie_spawn_delay" ] = 0.1;
						playfx( level._effect[ "powerup_on" ], level.exfillocation + (0,0,30) );
						playfx( level._effect[ "lght_marker" ], level.exfillocation );
						level thread spawnExit();
						level thread spawnMiniBoss();
						level notify ("exfil_started");
						level thread sendsubtitletext(chooseAnnouncer(), 1, "The portal has opened at " + level.escapezone + "", 5);
					
						fadetowhite fadeovertime( 1 );
						fadetowhite.alpha = 0;
						wait 1.1;
						fadetowhite destroy();
						
						startCountdown(level.starttimer);
					}
				}
			}
			exfilTrigger setHintString("^7Press ^3&&1 ^7to call an exfil");
		}
		else
		{
			exfilTrigger setHintString("");
		}

		wait 0.5;
	}
}

exfilHUD()
{
//	level endon("end_game");
	self endon( "disconnect" );

	exfil_bg = newClientHudElem(self);
	exfil_bg.alignx = "left";
	exfil_bg.aligny = "middle";
	exfil_bg.horzalign = "user_left";
	exfil_bg.vertalign = "user_center";
	exfil_bg.x -= 0;
	exfil_bg.y += 0;
	exfil_bg.fontscale = 2;
	exfil_bg.alpha = 1;
	exfil_bg.color = ( 0, 0, 1 );
	exfil_bg.hidewheninmenu = 1;
	exfil_bg.foreground = 1;
	exfil_bg setShader("scorebar_zom_1", 124, 32);
	
	
	exfil_text = newClientHudElem(self);
	exfil_text.alignx = "left";
	exfil_text.aligny = "middle";
	exfil_text.horzalign = "user_left";
	exfil_text.vertalign = "user_center";
	exfil_text.x += 20;
	exfil_text.y += 5;
	exfil_text.fontscale = 1;
	exfil_text.alpha = 1;
	exfil_text.color = ( 1, 1, 1 );
	exfil_text.hidewheninmenu = 1;
	exfil_text.foreground = 1;
	exfil_text.label = &"Exfil Timer: ^2";
	
	exfil_target = newClientHudElem(self);
	exfil_target.alignx = "left";
	exfil_target.aligny = "middle";
	exfil_target.horzalign = "user_left";
	exfil_target.vertalign = "user_center";
	exfil_target.x += 20;
	exfil_target.y -= 5;
	exfil_target.fontscale = 1;
	exfil_target.alpha = 0;
	exfil_target.color = ( 1, 1, 1 );
	exfil_target.hidewheninmenu = 1;
	exfil_target.foreground = 1;
	exfil_target settext ("Go to the ^2" + level.escapezone);
	
	exfil_kills = newClientHudElem(self);
	exfil_kills.alignx = "left";
	exfil_kills.aligny = "middle";
	exfil_kills.horzalign = "user_left";
	exfil_kills.vertalign = "user_center";
	exfil_kills.x += 20;
	exfil_kills.y -= 5;
	exfil_kills.fontscale = 1;
	exfil_kills.alpha = 0;
	exfil_kills.color = ( 1, 1, 1 );
	exfil_kills.hidewheninmenu = 1;
	exfil_kills.foreground = 1;
	exfil_kills.label = &"Zombie Kills Left: ^2";
	
	thread activateTimer(exfil_text);
	
	while(1)
	{
		exfil_kills setValue (get_round_enemy_array().size + level.zombie_total);
		if ((level.exfilstarted == 1) && (level.gameisending == 0))
		{
			exfil_bg.alpha = 1;
			exfil_target.alpha = 0;
			exfil_text.alpha = 1;
			exfil_kills.alpha = 1;
//			exfil_text setValue (level.timer);
//			exfil_text setTimer(level.timer);
			exfil_target setValue (level.escapezone);
			if ( distance( level.exfillocation, self.origin ) <= 300 )
			{
				exfil_bg.color = ( 0, 1, 0 );
			}
			else
			{
				exfil_bg.color = ( 0, 0, 1 );
			}
			
			if(get_round_enemy_array().size + level.zombie_total == 0)
			{
				exfil_target.alpha = 1;
				exfil_kills.alpha = 0;
			}
			
		}
		else
		{
			exfil_bg.alpha = 0;
			exfil_target.alpha = 0;
			exfil_text.alpha = 0;
			exfil_kills.alpha = 0;
		}
		
		wait 0.5;
	}
}

activateTimer(hud)
{
	level waittill("exfil_started");
	hud setTimer(120);
}

getTimerText(seconds)
{
	
	text = (seconds);
	return text;
}

startCountdown(numtoset)
{
	level endon("game_ended");
	level endon("end_game");
	level.timer = numtoset;
	while(level.timer > 0)
	{
		level.timer -= 1;
		wait 1;
	}
	level notify ("exfil_end");
}

setExfillocation()
{
	if ( getDvar( "g_gametype" ) == "zgrief" || getDvar( "g_gametype" ) == "zstandard" )
	{
		if(getDvar("mapname") == "zm_prison") //mob of the dead grief
		{
			level.iconlocation = (-769,8671,1374);
			level.escapezone = ("Roof");
			level.radiomodel = ("");
			level.radioangle = (0,90,0);
			level.exfillocation = (2496,9433,1704);
			level.starttimer = 120;
			level.requirezombiekills = 0;
		}
		else if(getDvar("mapname") == "zm_buried") //buried grief
		{
			level.iconlocation = (0,0,0);
			level.escapezone = ("Roof");
			level.radiomodel = ("");
			level.radioangle = (0,0,0);
			level.exfillocation = (0,0,0);
			level.starttimer = 120;
			level.requirezombiekills = 0;
		}
		else if(getDvar("mapname") == "zm_nuked") //nuketown
		{
			level.iconlocation = (-1349,994,-63);
			level.escapezone = ("Bunker");
			level.radiomodel = ("");
			level.radioangle = (0,0,0);
			level.exfillocation = (-581,375,80);
			level.starttimer = 120;
			level.requirezombiekills = 0;
		}
		else if(getDvar("mapname") == "zm_transit") //transit grief and survival
		{
			if(getDvar("ui_zm_mapstartlocation") == "town") //town
			{
				level.iconlocation = (1936,646,-55);
				level.escapezone = ("Barber");
				level.radiomodel = ("");
				level.radioangle = (0,0,0);
				level.exfillocation = (744,-1456,128);
				level.starttimer = 120;
				level.requirezombiekills = 1;
			}
			else if (getDvar("ui_zm_mapstartlocation") == "transit") //busdepot
			{
				level.iconlocation = (-6483,5297,-55);
				level.escapezone = ("Exfil Point");
				level.radiomodel = ("");
				level.radioangle = (0,126,0);
				level.exfillocation = (-7388,4239,-63);
				level.starttimer = 120;
				level.requirezombiekills = 1;
			}
			else if (getDvar("ui_zm_mapstartlocation") == "farm") //farm
			{
				level.iconlocation = (7995,-6627,117);
				level.escapezone = ("Barn");
				level.radiomodel = ("");
				level.radioangle = (0,0,0);
				level.exfillocation = (8111,-4787,48);
				level.starttimer = 120;
				level.requirezombiekills = 1;
			}
		}
	}
	else
	{
		if(getDvar("mapname") == "zm_prison") //mob of the dead
		{
			level.iconlocation = (-1006,8804,1336);
			level.escapezone = ("Roof");
			level.radiomodel = ("");
			level.radioangle = (0,90,0);
			level.exfillocation = (2496,9433,1704);
			level.starttimer = 120;
			level.requirezombiekills = 0;
		}
		else if(getDvar("mapname") == "zm_buried") //buried
		{
			level.iconlocation = (1005,-1572,50);
			level.escapezone = ("Tunnel");
			level.radiomodel = ("");
			level.radioangle = (0,0,0);
			level.exfillocation = (-131,250,358);
			level.starttimer = 120;
			level.requirezombiekills = 0;
		}
		else if(getDvar("mapname") == "zm_transit") //transit
		{
			level.iconlocation = (-6201,4108,-7);
			level.escapezone = ("Diner");
			level.radiomodel = ("p6_zm_buildable_sq_transceiver");
			level.radioangle = (0,126,0);
			level.exfillocation = (-4415,-7063,-65);
			level.starttimer = 120;
			level.requirezombiekills = 0;
			
		}
		else if(getDvar("mapname") == "zm_tomb") //origins
		{
			level.iconlocation = (2899,5083,-375);
			level.escapezone = ("No Mans Land");
			level.radiomodel = ("");
			level.radioangle = (0,90,0);
			level.exfillocation = (137,-299,320);
			level.starttimer = 120;
			level.requirezombiekills = 0;
		}
		else if(getDvar("mapname") == "zm_highrise")
		{
			level.iconlocation = (1472,1142,3401);
			level.escapezone = ("Roof");
			level.radiomodel = ("");
			level.radioangle = (0,0,0);
			level.exfillocation = (2036,305,2880);
			level.starttimer = 120;
			level.requirezombiekills = 0;
		}
	}
}

spawnExit()
{
	exfilExit = spawn( "trigger_radius", (level.exfillocation), 10, 200, 200 );
	exfilExit setHintString("^7Kill all the Zombies");
	exfilExit setcursorhint( "HINT_NOICON" );
	
	foreach (player in get_players())
	{
		player show_big_message("Kill all the Zombies to open the portal!", "");
	}
	
	waitTillNoZombies();
	
	foreach (player in get_players())
	{
		player show_big_message("All Enemies Eliminated! You can now Escape!", "");
	}
	
	exfilExit setHintString("^7Press ^3&&1 ^7escape");
	
	while(1)
	{
		exfilExit waittill( "trigger", i );
		if ( i usebuttonpressed())
		{
			i enableinvulnerability();
			level.successfulexfil = 1;
			escapetransition = newClientHudElem(i);
			escapetransition.x = 0;
			escapetransition.y = 0;
			escapetransition.alpha = 0;
			escapetransition.horzalign = "fullscreen";
			escapetransition.vertalign = "fullscreen";
			escapetransition.foreground = 0;
			escapetransition setshader( "white", 640, 480 );
			escapetransition.color = (0,0,0);
			escapetransition fadeovertime( 0.5 );
			escapetransition.alpha = 1;
			wait 3;
			
			escapetransition.foreground = 0;
			escapetransition fadeovertime( 0.2 );
			escapetransition.alpha = 0;
			i disableinvulnerability();
			if (level.players.size == 1)
			{
				level thread sendsubtitletext(chooseAnnouncer(), 1, "Everyone has successfully escaped!", 5);
				level notify( "end_game" );
			}
			else
			{
				escapetransition.alpha = 0;
				i thread maps\mp\gametypes_zm\_spectating::setspectatepermissions();
    			i.sessionstate = "spectator";
				escapetransition destroy();
				if (checkAmountPlayers())
				{
					level thread sendsubtitletext(chooseAnnouncer(), 1, "Everyone has successfully escaped!", 5);
					level notify( "end_game" );
				}
				else
				{
					level thread sendsubtitletext(chooseAnnouncer(), 1, i + " has escaped!", 2);
				}
				
			}
			level waittill ("end_game");
			exfilExit setHintString("");
		}
	
	}
}

waitTillNoZombies()
{
	while(get_round_enemy_array().size + level.zombie_total > 0)
	{
		wait 0.1;
	}
}

downOnExfil()
{
	level waittill ("exfil_end");
	if ( distance( level.exfillocation, self.origin ) > 300 )
	{
		
		deathtransition = newClientHudElem(self);
		deathtransition.x = 0;
		deathtransition.y = 0;
		deathtransition.alpha = 0;
		deathtransition.horzalign = "fullscreen";
		deathtransition.vertalign = "fullscreen";
		deathtransition.foreground = 1;
		deathtransition setshader( "white", 640, 480 );
		deathtransition.color = (1,0,0);
		deathtransition fadeovertime( 0.2 );
		deathtransition.alpha = 1;
		wait 1;
		self unsetperk("specialty_quickrevive");
		self.lives = 0;
		self thread show_big_message("You were consumed by the Aether!","");
		self dodamage(self.health, self.origin);
		deathtransition fadeovertime( 1 );
		deathtransition.alpha = 0;
		wait 1.1;
		
		deathtransition.foreground = 0;
		level notify( "end_game" );
	}
	else
	{
		self thread forcePlayersToExfil();
	}
}

showscoreboardtext()
{
	level waittill("end_game");
	level.gameisending = 1;
	wait 8;
	
	scoreboardText = newclienthudelem( self );
    scoreboardText.alignx = "center";
    scoreboardText.aligny = "middle";
    scoreboardText.horzalign = "center";
    scoreboardText.vertalign = "middle";
    scoreboardText.y -= 100;

    if ( self issplitscreen() )
        scoreboardText.y += 70;

    scoreboardText.foreground = 1;
    scoreboardText.fontscale = 8;
    scoreboardText.alpha = 0;
    scoreboardText.color = ( 0, 1, 0 );
    scoreboardText.hidewheninmenu = 1;
    scoreboardText.font = "default";

	if ((level.successfulexfil == 1) && (level.exfilstarted == 1))
	{
		scoreboardText.color = ( 0, 1, 0 );
		scoreboardText settext( "Exfil Successful" );
	}
	else if ((level.successfulexfil == 0) && (level.exfilstarted == 1))
	{
		scoreboardText.color = ( 1, 0, 0 );
		scoreboardText settext( "Exfil Failed" );
	}

    scoreboardText changefontscaleovertime( 0.25 );
    scoreboardText fadeovertime( 0.25 );
    scoreboardText.alpha = 1;
    scoreboardText.fontscale = 4;
}

fixZombieTotal()
{
	level.zombie_total = 40;
//	while(1)
//		{
//			if (level.exfilstarted == 1)
//			{
//				level.zombie_total = 20;
//			}
//			wait(1);
//		}
}

showExfilMessage()
{	
	belowMSG = newclienthudelem( self );
    belowMSG.alignx = "center";
    belowMSG.aligny = "bottom";
    belowMSG.horzalign = "center";
    belowMSG.vertalign = "bottom";
    belowMSG.y -= 10;
    
    belowMSG.foreground = 1;
    belowMSG.fontscale = 4;
    belowMSG.alpha = 0;
    belowMSG.hidewheninmenu = 1;
    belowMSG.font = "default";

	if (level.canexfil == 0)
	{
		belowMSG settext( "Exfil window gone!" );
		belowMSG.color = ( 1, 0, 0 );
	}
	else if (level.canexfil == 1)
	{
		belowMSG settext( "Exfil is available!" );
		belowMSG.color = ( 0, 1, 0 );
	}

    belowMSG changefontscaleovertime( 0.25 );
    belowMSG fadeovertime( 0.25 );
    belowMSG.alpha = 1;
    belowMSG.fontscale = 2;
    
    wait 8;
    
    belowMSG changefontscaleovertime( 0.25 );
    belowMSG fadeovertime( 0.25 );
    belowMSG.alpha = 0;
    belowMSG.fontscale = 4;
    wait 1.1;
    belowMSG destroy();
}

checkAmountPlayers()
{
	if (level.players.size == 1)
	{
		return true;
	}
	else
	{
		count = 0;
		foreach ( player in level.players )
		{
		if( distance( level.iconlocation, player.origin ) <= 10 )
		    {
	   			count += 1;
	   		}
		}
		if (level.players.size <= count)
		{
			return true;
		}
		else
		{
			return false;
		}
	}
}

forcePlayersToExfil()
{
	self enableinvulnerability();
	level.successfulexfil = 1;
	escapetransition = newClientHudElem(self);
	escapetransition.x = 0;
	escapetransition.y = 0;
	escapetransition.alpha = 0;
	escapetransition.horzalign = "fullscreen";
	escapetransition.vertalign = "fullscreen";
	escapetransition.foreground = 1;
	escapetransition setshader( "white", 640, 480 );
	escapetransition.color = (0,0,0);
	escapetransition fadeovertime( 0.5 );
	escapetransition.alpha = 1;
	wait 3;
			
	escapetransition.foreground = 0;
	self disableinvulnerability();
	if (level.players.size == 1)
	{
		level notify( "end_game" );
	}
	else
	{
		escapetransition.alpha = 0;
		self thread maps\mp\gametypes_zm\_spectating::setspectatepermissions();
    	self.sessionstate = "spectator";
		escapetransition destroy();
		if (checkAmountPlayers())
		{
			level notify( "end_game" );
		}
				
	}
}

showVoting(execPlayer)
{
	self endon( "disconnect" );
	
	level.exfilvoteexec = execPlayer;
	
	hudy = -100;
	
	voting_bg = newClientHudElem(self);
	voting_bg.alignx = "left";
	voting_bg.aligny = "middle";
	voting_bg.horzalign = "user_left";
	voting_bg.vertalign = "user_center";
	voting_bg.x -= 0;
	voting_bg.y = hudy;
	voting_bg.fontscale = 2;
	voting_bg.alpha = 1;
	voting_bg.color = ( 1, 1, 1 );
	voting_bg.hidewheninmenu = 1;
	voting_bg.foreground = 1;
	voting_bg setShader("scorebar_zom_1", 124, 32);
	
	
	voting_text = newClientHudElem(self);
	voting_text.alignx = "left";
	voting_text.aligny = "middle";
	voting_text.horzalign = "user_left";
	voting_text.vertalign = "user_center";
	voting_text.x += 20;
	voting_text.y = hudy + 5;
	voting_text.fontscale = 1;
	voting_text.alpha = 1;
	voting_text.color = ( 1, 1, 1 );
	voting_text.hidewheninmenu = 1;
	voting_text.foreground = 1;
	voting_text.label = &"Timer: ";
	
	voting_target = newClientHudElem(self);
	voting_target.alignx = "left";
	voting_target.aligny = "middle";
	voting_target.horzalign = "user_left";
	voting_target.vertalign = "user_center";
	voting_target.x += 20;
	voting_target.y = hudy - 5;
	voting_target.fontscale = 1;
	voting_target.alpha = 1;
	voting_target.color = ( 1, 1, 1 );
	voting_target.hidewheninmenu = 1;
	voting_target.foreground = 1;
//	voting_target setText ("Press [{+actionslot 4}] to agree on Exfil");
	voting_target setText (execPlayer.name + " wants to Exfil - [{+actionslot 4}] to accept");
//[{+actionslot 4}]
	
	voting_votes = newClientHudElem(self);
	voting_votes.alignx = "left";
	voting_votes.aligny = "middle";
	voting_votes.horzalign = "user_left";
	voting_votes.vertalign = "user_center";
	voting_votes.x += 20;
	voting_votes.y = hudy + 15;
	voting_votes.fontscale = 1;
	voting_votes.alpha = 1;
	voting_votes.color = ( 1, 1, 1 );
	voting_votes.hidewheninmenu = 1;
	voting_votes.foreground = 1;
	voting_votes.label = &"Votes left: ";
	
	while(1)
	{
		voting_text setValue (level.votingtimer);
		votesLeft = level.players.size - level.exfilplayervotes;
		voting_votes setValue (votesLeft);
		if (self.exfilvoted == 0)
		{
			voting_bg.color = ( 0, 0, 1 );
		}
		else if (self.exfilvoted == 1)
		{
			voting_bg.color = ( 0, 1, 0 );
		}
		
		if (level.exfilvoting == 0)
		{
			voting_target destroy();
			voting_bg destroy();
			voting_text destroy();
			voting_votes destroy();
		}
		wait 0.1;
	}
}

checkVotingInput()
{
	level endon ("voting_finished");
	level endon ("voting_expired");
	while(level.exfilvoting == 1 && self.exfilvoted == 0)
	{
		if(self actionslotfourbuttonpressed() || (isDefined(self.bot)))
		{
			level.exfilplayervotes += 1;
			self.exfilvoted = 1;
			if (level.exfilplayervotes >= level.players.size)
			{
				level.votingsuccess = 1;
				level notify ("voting_finished");
			}
		}
		wait 0.1;
	}
}

checkIfPlayersVoted()
{
	level endon ("voting_finished");
	level endon ("voting_expired");
	while(1)
	{
		if (level.exfilplayervotes >= level.players.size)
		{
			level.votingsuccess = 1;
			level notify ("voting_finished");
		}
	}
	wait 0.1;
}

exfilVoteTimer()
{
	level endon ("voting_finished");
	level endon ("voting_expired");
	level.votingtimer = 15;
	while(1)
	{
		level.votingtimer -= 1;
		if (level.votingtimer < 0)
		{
			level.exfilplayervotes = 0;
			foreach (player in getPlayers())
				player.exfilvoted = 0;
			level.exfilvoting = 0;
			level.votingsuccess = 0;
			level notify ("voting_expired");
		}
		wait 1;
	}
}

getRequirement()
{
	return level.players.size;
}

spawnMiniBoss()
{
	if(getDvar("mapname") == "zm_prison")
	{
		level notify( "spawn_brutus", 4 );
	}
	else if(getDvar("mapname") == "zm_tomb")
	{
		level.mechz_left_to_spawn++;
		level notify( "spawn_mechz" );
	}
}

change_zombies_speed(speedtoset){
	level endon("end_game");
	sprint = speedtoset;
	can_sprint = false;
 	while(true){
 		if (level.ragestarted == 1)
 		{
 			can_sprint = false;
    		zombies = getAiArray(level.zombie_team);
    		foreach(zombie in zombies)
    		if(!isDefined(zombie.cloned_distance))
    			zombie.cloned_distance = zombie.origin;
    		else if(distance(zombie.cloned_distance, zombie.origin) > 15){
    			can_sprint = true;
    			zombie.cloned_distance = zombie.origin;
    			if(zombie.zombie_move_speed == "run" || zombie.zombie_move_speed != sprint)
    				zombie maps\mp\zombies\_zm_utility::set_zombie_run_cycle(sprint);
    		}else if(distance(zombie.cloned_distance, zombie.origin) <= 15){
    			can_sprint = false;
    			zombie.cloned_distance = zombie.origin;
    			zombie maps\mp\zombies\_zm_utility::set_zombie_run_cycle("run");
    		}
    	}
    	wait 0.25;
    }
}

chooseAnnouncer()
{
	if (getDvar("mapname") == "zm_transit")
		return "Richtofen";
	else if (getDvar("mapname") == "zm_nuked")
		return "Richtofen";
	else if (getDvar("mapname") == "zm_tomb")
		return "Samantha Maxis";
	else if (getDvar("mapname") == "zm_prison")
		return "Afterlife Spirit";
	else if (getDvar("mapname") == "zm_buried")
		return "Richtofen";
	else if (getDvar("mapname") == "zm_highrise")
		return "Richtofen";
}

sendsubtitletext(charactername, team, text, time)
{
	if(getDvarInt("enable_custom_subtitles") == 1)
	{	
		if(isDefined(self.subtitleText))
		{
			self waittill ("subtitle_done");
			self.subtitleText destroy();
		}
	
	
		if (team == 1)
		{
			teamcolor = "^4";
		}
		else if (team == 2)
		{
			teamcolor = "^1";
		}
		else
		{
			teamcolor = "^3";
		}
	
	
		self.subtitleText = newclienthudelem( self );
    	self.subtitleText.alignx = "center";
    	self.subtitleText.aligny = "bottom";
    	self.subtitleText.horzalign = "center";
    	self.subtitleText.vertalign = "bottom";
    	self.subtitleText.fontscale = 1.5;
    	self.subtitleText.y = 0;
    
    	self.subtitleText.foreground = 1;
    	self.subtitleText.alpha = 0;
    	self.subtitleText.hidewheninmenu = 1;
    	self.subtitleText.font = "default";

		self.subtitleText settext( teamcolor + charactername + "^7: " + text );
		self.subtitleText.color = ( 1, 1, 1 );

    	self.subtitleText moveovertime( 0.25 );
    	self.subtitleText fadeovertime( 0.25 );
    	self.subtitleText.alpha = 1;
    	self.subtitleText.y = -10;
    
    	wait time;
    
    	self.subtitleText moveovertime( 0.25 );
    	self.subtitleText fadeovertime( 0.25 );
    	self.subtitleText.alpha = 0;
    	self.subtitleText.y = -20;
    	wait 1.1;
    	self.subtitleText destroy();
    	self notify ("subtitle_done");
    }
}

show_big_message(setmsg, sound)
{
    msg = setmsg;
    players = get_players();

    if ( isdefined( level.hostmigrationtimer ) )
    {
        while ( isdefined( level.hostmigrationtimer ) )
            wait 0.05;

        wait 4;
    }

    foreach ( player in players )
        player thread show_big_hud_msg( msg );
        player playsound(sound);

}

show_big_hud_msg( msg, msg_parm, offset, cleanup_end_game )
{
    self endon( "disconnect" );

    while ( isdefined( level.hostmigrationtimer ) )
        wait 0.05;

    large_hudmsg = newclienthudelem( self );
    large_hudmsg.alignx = "center";
    large_hudmsg.aligny = "middle";
    large_hudmsg.horzalign = "center";
    large_hudmsg.vertalign = "middle";
    large_hudmsg.y -= 130;

    if ( self issplitscreen() )
        large_hudmsg.y += 70;

    if ( isdefined( offset ) )
        large_hudmsg.y += offset;

    large_hudmsg.foreground = 1;
    large_hudmsg.fontscale = 5;
    large_hudmsg.alpha = 0;
    large_hudmsg.color = ( 1, 1, 1 );
    large_hudmsg.hidewheninmenu = 1;
    large_hudmsg.font = "default";

    if ( isdefined( cleanup_end_game ) && cleanup_end_game )
    {
        level endon( "end_game" );
        large_hudmsg thread show_big_hud_msg_cleanup();
    }

    if ( isdefined( msg_parm ) )
        large_hudmsg settext( msg, msg_parm );
    else
        large_hudmsg settext( msg );

    large_hudmsg changefontscaleovertime( 0.25 );
    large_hudmsg fadeovertime( 0.25 );
    large_hudmsg.alpha = 1;
    large_hudmsg.fontscale = 2;
    wait 3.25;
    large_hudmsg changefontscaleovertime( 1 );
    large_hudmsg fadeovertime( 1 );
    large_hudmsg.alpha = 0;
    large_hudmsg.fontscale = 5;
    wait 1;
    large_hudmsg notify( "death" );

    if ( isdefined( large_hudmsg ) )
        large_hudmsg destroy();
}

show_big_hud_msg_cleanup()
{
    self endon( "death" );

    level waittill( "end_game" );

    if ( isdefined( self ) )
        self destroy();
}

round_wait_exfil()
{
    level endon( "restart_round" );
/#
    if ( getdvarint( #"zombie_rise_test" ) )
        level waittill( "forever" );
#/
/#
    if ( getdvarint( #"zombie_cheat" ) == 2 || getdvarint( #"zombie_cheat" ) >= 4 )
        level waittill( "forever" );
#/
    wait 1;

    if ( flag( "dog_round" ) )
    {
        wait 7;

        while ( level.dog_intermission )
            wait 0.5;

        increment_dog_round_stat( "finished" );
    }
    else
    {
        while ( true )
        {
            should_wait = 0;

			if (level.exfilstarted == 0)
			{
				if ( isdefined( level.is_ghost_round_started ) && [[ level.is_ghost_round_started ]]() )
					should_wait = 1;
				else
					should_wait = get_current_zombie_count() > 0 || level.zombie_total > 0 || level.intermission;

				if ( !should_wait )
					return;

				if ( flag( "end_round_wait" ) )
					return;
			}

            wait 1.0;
        }
    }
}