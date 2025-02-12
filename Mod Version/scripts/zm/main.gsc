#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\gametypes_zm\_hud_message;
#include maps\mp\zombies\_zm;
#include maps\mp\zombies\_zm_laststand;

main()
{
	replacefunc(maps\mp\zombies\_zm::end_game, ::end_game_new);
}

init()
{
	level.player_out_of_playable_area_monitor = 0;
	precacheshader("hud_icon_exfil");
	precacheshader("hud_icon_rampage");
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
//		self iprintln("^4Exfil ^7created by ^1techboy04gaming");
    }
}

createExfilIcon()
{
	exfil_icon = newHudElem();
	exfil_icon thread removeHUDEndGame();
    exfil_icon.x = level.iconlocation[ 0 ];
    exfil_icon.y = level.iconlocation[ 1 ];
	exfil_icon.z = level.iconlocation[ 2 ] + 20;
	exfil_icon.color = (1,1,1);
    exfil_icon.isshown = 1;
    exfil_icon.archived = 0;
    exfil_icon setshader( "hud_icon_exfil", 6, 6 );
    exfil_icon setwaypoint( 1 );
    
    for(;;)
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
			exfil_icon setshader( "hud_icon_exfil", 0, 0 );
			exfil_icon setwaypoint( 1, "hud_icon_exfil", 1 );
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
	for(;;)
	{
		level waittill ("can_exfil");
		level endon ("exfil_started");
		level.canexfil = 1;
		
		level thread do_vox("exfil_available");

		wait 120;
		level.canexfil = 0;

		level thread do_vox("exfil_unavailable");
	}
}

spawnExfil()
{
	exfilTrigger = spawn( "trigger_radius", (level.iconlocation), 1, 50, 50 );
	exfilTrigger setHintString("");
	exfilTrigger setcursorhint( "HINT_NOICON" );
	exfilModel = spawn( "script_model", (level.iconlocation));
	exfilModel setmodel ("p6_zm_buildable_sq_transceiver");
	exfilModel rotateTo(level.radioangle,.1);
	
	for(;;)
	{
		exfilTrigger waittill( "trigger", i );
		if (level.exfilstarted == 0 && level.canexfil == 1 && level.infinalphase != true && level.defensemode != true)
		{
			if ( i usebuttonpressed() )
			{
				
				if (level.exfilvoting == 0)
				{
					level.exfilplayervotes = 0;
					level.exfilvoting = 1;

					level.exfilplayervotes += 1;
					i.exfilvoted = 1;
					if (level.exfilplayervotes >= level.players.size)
					{
						level.votingsuccess = 1;
						level notify ("voting_finished");
					}

					if (level.players.size > 1)
					{
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
					}
					else
					{
						level.votingsuccess = 1;
					}

					if (level.votingsuccess == 1)
					{
						level.exfilvoting = 0;
						earthquake( 0.5, 0.5, self.origin, 800 );
						foreach ( player in get_players() )
						{
							player playlocalsound( "evt_nuke_flash" );
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
						fadetowhite.alpha = 0.8;
						wait 1;
					
						kill_current_zombies();
						level.exfilstarted = 1;
						level thread fixZombieTotal();
						if(level.ragestarted != 1)
						{
							level thread change_zombies_speed("sprint");
						}
						level.zombie_vars[ "zombie_spawn_delay" ] = 0.1;
						playfx( level._effect[ "powerup_on" ], level.exfillocation + (0,0,30) );
						playfx( level._effect[ "lght_marker" ], level.exfillocation );
						level thread spawnExit();
						level thread spawnMiniBoss();
						level thread maintain_exfil_zombie_count();
						level notify ("exfil_started");
//						playsound(do_vox("exfil_during"));
					
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

kill_current_zombies()
{
	zombies = getaiarray( level.zombie_team );
	
	foreach (i in zombies)
	{
		i dodamage(i.health,i.origin);
		wait 0.05;
	}
}

getTimerText(seconds)
{
	
	text = (seconds);
	return text;
}

startCountdown(numtoset)
{
	level endon("game_ended");
	level endon("exfil_everyone_escapes");
	level endon("end_game");
	level.timer = numtoset;
	while(level.timer > 0)
	{
		level.timer -= 1;
		wait 1;
	}
	level thread do_vox("exfil_failed");
	wait 4;
	level notify ("exfil_end");
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
	exfil_bg thread removeHUDEndGame();
	
	
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
	exfil_text thread removeHUDEndGame();
	
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
	exfil_target thread removeHUDEndGame();
	
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
	exfil_kills thread removeHUDEndGame();
	
	thread activateTimer(exfil_text);
	
	for(;;)
	{
		exfil_kills setValue (get_round_enemy_array().size + level.zombie_total);
		if ((level.exfilstarted == 1) && (self.hasescaped != true))
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
			level.iconlocation = (-1248.3, 1021, -30.2336);
			level.escapezone = ("Bunker");
			level.radiomodel = ("");
			level.radioangle = (0,-11.1188,0);
			level.exfillocation = (-581,375,80);
			level.starttimer = 120;
			level.requirezombiekills = 0;
		}
		else if(getDvar("mapname") == "zm_transit") //transit grief and survival
		{
			if(getDvar("ui_zm_mapstartlocation") == "town") //town
			{
//				level.iconlocation = (1936,646,-55); //Old Location
				level.iconlocation = (1935.56, 666.431, -12.891);
				level.escapezone = ("Barber");
				level.radiomodel = ("");
				level.radioangle = (0,0,0);
				level.exfillocation = (744,-1456,128);
				level.starttimer = 120;
				level.requirezombiekills = 1;
			}
			else if (getDvar("ui_zm_mapstartlocation") == "transit") //busdepot
			{
				level.iconlocation = (-6195.53, 4112.26, -8.70799);
				level.escapezone = ("Exfil Point");
				level.radiomodel = ("");
				level.radioangle = (0,171.712,0);
				level.exfillocation = (-7388,4239,-63);
				level.starttimer = 120;
				level.requirezombiekills = 1;
			}
			else if (getDvar("ui_zm_mapstartlocation") == "farm") //farm
			{
				level.iconlocation = (8273.89, -6681.13, 156.045);
				level.escapezone = ("Barn");
				level.radiomodel = ("");
				level.radioangle = (0,-60,0);
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
			level.iconlocation = (-1026.25, 8887, 1366.71);
			level.escapezone = ("Roof");
			level.radiomodel = ("p6_zm_buildable_sq_transceiver");
			level.radioangle = (0,131.127,0);
			level.exfillocation = (2496,9433,1704);
			level.starttimer = 120;
			level.requirezombiekills = 0;
		}
		else if(getDvar("mapname") == "zm_buried") //buried
		{
			level.iconlocation = (558.558, -1756.4, 85.4065);
			level.escapezone = ("Tunnel");
			level.radiomodel = ("p6_zm_buildable_sq_transceiver");
			level.radioangle = (0,95.2316,0);
			level.exfillocation = (-131,250,358);
			level.starttimer = 120;
			level.requirezombiekills = 0;
		}
		else if(getDvar("mapname") == "zm_transit") //transit
		{
			level.iconlocation = (-6195.53, 4112.26, -8.70799);
			level.escapezone = ("Diner");
			level.radiomodel = ("p6_zm_buildable_sq_transceiver");
			level.radioangle = (0,171.712,0);
			level.exfillocation = (-4415,-7063,-65);
			level.starttimer = 120;
			level.requirezombiekills = 0;
			
		}
		else if(getDvar("mapname") == "zm_tomb") //origins
		{
			level.iconlocation = (2899.34, 5055.05, -346.535);
			level.escapezone = ("No Mans Land");
			level.radiomodel = ("p6_zm_buildable_sq_transceiver");
			level.radioangle = (0,178.561,0);
			level.exfillocation = (137,-299,320);
			level.starttimer = 120;
			level.requirezombiekills = 0;
		}
		else if(getDvar("mapname") == "zm_highrise")
		{
			level.iconlocation = ((3011.86, 143.076, 1329.71));
			level.escapezone = ("Roof");
			level.radiomodel = ("p6_zm_buildable_sq_transceiver");
			level.radioangle = (0,-65.8683,0);
			level.exfillocation = (2036,305,2880);
			level.starttimer = 120;
			level.requirezombiekills = 0;
		}
	}
}

spawnExit()
{
	level.exfilExit = spawn( "trigger_radius", (level.exfillocation), 10, 200, 200 );
	level.exfilExit setHintString("^7Kill all the Zombies");
	level.exfilExit setcursorhint( "HINT_NOICON" );
	level thread playexfilmusic();
	
	foreach (player in get_players())
	{
		player thread show_big_message("Kill all the Zombies to open the portal!", "");
		player thread shader_animation("hud_icon_exfil");
	}
	
	level thread do_vox("exfil_during");
	
	waitTillNoZombies();
	
	foreach (player in get_players())
	{
		player show_big_message("All Enemies Eliminated! You can now Escape!", "");
	}
	
	level thread do_vox("exfil_opened");
	
	level.exfilExit setHintString("^7Press ^3&&1 ^7escape");
	
	for(;;)
	{
		level.exfilExit waittill( "trigger", i );
		if ( i usebuttonpressed())
		{
			i enableinvulnerability();
			i thread unwhoosh();
			i.hasescaped = true;
			level.successfulexfil = 1;
			wait 1;
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
			wait 0.5;
			
//			escapetransition.foreground = 0;
//			escapetransition fadeovertime( 0.2 );
//			escapetransition.alpha = 0;
			i disableinvulnerability();
			if (level.players.size == 1)
			{
				level thread sendsubtitletext(chooseAnnouncer(), 1, "Everyone has successfully escaped!", "", 5);
				i.sessionstate = "spectator";
				level notify ("exfil_everyone_escapes");
				level notify( "end_game" );
			}
			else
			{
//				escapetransition.alpha = 0;
				i thread maps\mp\gametypes_zm\_spectating::setspectatepermissions();
    			i.sessionstate = "spectator";
//				escapetransition destroy();
				if (checkAmountPlayers())
				{
					level thread sendsubtitletext(chooseAnnouncer(), 1, "Everyone has successfully escaped!", "", 5);
					level notify( "end_game" );
					level notify ("exfil_everyone_escapes");
				}
				else
				{
					level thread sendsubtitletext(chooseAnnouncer(), 1, i + " has escaped!", "", 2);
				}
				
			}
//			level waittill ("end_game");
//			level.exfilExit setHintString("");
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

maintain_exfil_zombie_count()
{
	level endon ("exfil_end");
	for(;;)
	{
		if(level.zombie_total > 40)
		{
			level.zombie_total = 40;
		}
		wait 0.01;
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

fixZombieTotal()
{
	level.zombie_total = 40;
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
//		if( distance( level.iconlocation, player.origin ) <= 10 )
		if(player.sessionstate == "spectator")
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
	return "Announcer";
}

sendsubtitletext(charactername, team, text, audio, time)
{
	if(audio != "" && (getDvarInt("enable_exfil_vox") == 1 || getDvarInt("enable_exfil_vox") == 2))
	{
		self playlocalsound(audio);
	}

	if(getDvarInt("enable_exfil_vox") == 1 || getDvarInt("enable_exfil_vox") == 3)
	{	
		if(isDefined(self.subtitleText))
		{
			self notify ("subtitle_done");
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
	
		self endon ("subtitle_done");
	
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

playexfilmusic()
{
    ent = spawn( "script_origin", ( 0, 0, 0 ) );
    ent thread stopexfilmusic();
	if(getDvarInt("exfil_music") == 0)
	{
		random = randomintrange(1,3);
		if(random <= 1)
		{
			ent playloopsound( "mus_exfil" );
		}
		else
		{
			ent playloopsound( "mus_exfil2" );
		}
	}
	else if(getDvarInt("exfil_music") == 1)
	{
		ent playloopsound( "mus_exfil" );
	}
	else if(getDvarInt("exfil_music") == 2)
	{
		ent playloopsound( "mus_exfil2" );
	}
}

stopexfilmusic()
{
    level waittill( "end_game" );
    self stoploopsound( 1.5 );
    wait 1;
    self delete();
}

do_vox(id)
{
	if(id == "exfil_available")
	{
		random = randomintrange(1,2);
		if (random == 1)
		{
			do_vox_subtitles("Entity", "The escape portal is near, contact me if you want to use it.", 4, "vox_exfil_available_1");
		}
		else
		{
			do_vox_subtitles("Entity", "The escape portal is nearby if you want to use it.", 4, "vox_exfil_available_2");
		}
	}
	else if(id == "exfil_unavailable")
	{
		random = randomintrange(1,2);
		if (random == 1)
		{
			do_vox_subtitles("Entity", "The escape portal moved away! It will be back soon.", 3, "vox_exfil_unavailable_1");
		}
		else
		{
			do_vox_subtitles("Entity", "The portal is out of range. It will come back soon.", 3, "vox_exfil_unavailable_2");
		}
	}
	else if(id == "exfil_opened")
	{
		random = randomintrange(1,2);
		if (random == 1)
		{
			do_vox_subtitles("Entity", "Its opened! Lets go!", 2, "vox_exfil_opened_1");
		}
		else
		{
			do_vox_subtitles("Entity", "What are you waiting for? Its opened!", 2, "vox_exfil_opened_2");
		}
	}
	else if(id == "exfil_during")
	{
		random = randomintrange(1,2);
		if (random == 1)
		{
			do_vox_subtitles("Entity", "Clear those zombies! The portal is about to disappear!", 3, "vox_exfil_during_1");
		}
		else
		{
			do_vox_subtitles("Entity", "Whats taking you so long! The portal is going to disappear!", 3, "vox_exfil_during_2");
		}
	}
	else if(id == "exfil_failed")
	{
		random = randomintrange(1,3);
		if (random == 1)
		{
			do_vox_subtitles("Entity", "*gasps* The portal disappeared! Aaaand theres the Aether.", 4, "vox_exfil_failed_1");
		}
		else if (random == 2)
		{
			do_vox_subtitles("Entity", "You were too late! The portal is gone! And you ticked off the Aether!", 4, "vox_exfil_failed_2");
		}
		else
		{
			do_vox_subtitles("Entity", "Portals gone and you ticked off the Aether!", 2, "vox_exfil_failed_3");
		}
	}
	
	else
	{
		return;
	}
}

do_vox_subtitles(talker, text, duration, audio)
{	
	foreach (player in level.players)
	{
		player thread sendsubtitletext(talker, 1, text, audio, duration);
		if(getDvarInt("vox_debug") == 1)
		{
			player iprintln("Attempted to play " + audio);
		}
	}
	wait duration + 1.5;
}

removeHUDEndGame()
{
	level waittill ("intermission");
	self destroy();
}

shader_animation(shader)
{
	shader_hud = newClientHudElem(self);
	shader_hud.alignx = "center";
	shader_hud.aligny = "middle";
	shader_hud.horzalign = "user_center";
	shader_hud.vertalign = "user_top";
	shader_hud.x += 0;
	shader_hud.y += 80;
	shader_hud.fontscale = 2;
	shader_hud.alpha = 1;
	shader_hud.color = ( 1, 1, 1 );
	shader_hud.hidewheninmenu = 1;
	shader_hud.foreground = 1;
	shader_hud setShader(shader, 64, 64);
	
	
	shader_hud moveOvertime( 0.25 );
    shader_hud fadeovertime( 0.25 );
    shader_hud scaleovertime( 0.25, 32, 32);
    shader_hud.alpha = 1;
//    shader_hud.setscale = 1;
    wait 3.25;
    shader_hud moveOvertime( 1 );
    shader_hud fadeovertime( 1 );
    shader_hud.alpha = 0;
    shader_hud.setscale = 2;
    shader_hud scaleovertime( 1, 128, 128);
    wait 1;
    shader_hud notify( "death" );

    if ( isdefined( shader_hud ) )
        shader_hud destroy();
}

vector_scale( vec, scale )
{
	vec = ( vec[ 0] * scale, vec[ 1] * scale, vec[ 2] * scale );
	return vec;

}

unwhoosh()
{
	level endon("game_end");
	self enableinvulnerability();
	self disableweapons();
	self hide();
	self freezecontrols( 1 );
	zoomheight = 5000;
	zoomback = 4000;
	yaw = 55;
	origin = self.origin;
	ent = spawn( "script_model", ( 0, 0, 0 ) );
	ent.angles += ( yaw, 0, 0 );
	ent.origin = self.origin;
	ent setmodel( "tag_origin" );
	self playerlinktoabsolute( ent );
	ent moveto( vector_scale( anglestoforward( self.angles + ( 0, -180, 0 ) ), zoomback ) + ( 0, 0, zoomheight ), 4, 2, 2 );
	wait 1;
	ent rotateto( ( ent.angles[ 0] - yaw, ent.angles[ 1], 0 ), 3, 1, 1 );
	wait 0.5;
	self playlocalsound( "ui_camera_whoosh_in" );
	wait 2.5;
	self unlink();
	wait 0.5;
	ent delete();
	self show();
	self enableweapons();
	self.origin = origin;
	self disableinvulnerability();
}

end_game_new()
{
    level waittill( "end_game" );
    check_end_game_intermission_delay();
/#
    println( "end_game TRIGGERED " );
#/
    clientnotify( "zesn" );

    if ( isdefined( level.sndgameovermusicoverride ) )
        level thread maps\mp\zombies\_zm_audio::change_zombie_music( level.sndgameovermusicoverride );
    else
        level thread maps\mp\zombies\_zm_audio::change_zombie_music( "game_over" );

    players = get_players();

    for ( i = 0; i < players.size; i++ )
        setclientsysstate( "lsm", "0", players[i] );

    for ( i = 0; i < players.size; i++ )
    {
        if ( players[i] player_is_in_laststand() )
        {
            players[i] recordplayerdeathzombies();
            players[i] maps\mp\zombies\_zm_stats::increment_player_stat( "deaths" );
            players[i] maps\mp\zombies\_zm_stats::increment_client_stat( "deaths" );
            players[i] maps\mp\zombies\_zm_pers_upgrades_functions::pers_upgrade_jugg_player_death_stat();
        }

        if ( isdefined( players[i].revivetexthud ) )
            players[i].revivetexthud destroy();
    }

    stopallrumbles();
    level.intermission = 1;
    level.zombie_vars["zombie_powerup_insta_kill_time"] = 0;
    level.zombie_vars["zombie_powerup_fire_sale_time"] = 0;
    level.zombie_vars["zombie_powerup_point_doubler_time"] = 0;
    wait 0.1;
    game_over = [];
    survived = [];
    players = get_players();
    setmatchflag( "disableIngameMenu", 1 );

    foreach ( player in players )
    {
        player closemenu();
        player closeingamemenu();
    }

    if ( !isdefined( level._supress_survived_screen ) )
    {
        for ( i = 0; i < players.size; i++ )
        {
            if ( isdefined( level.custom_game_over_hud_elem ) )
                game_over[i] = [[ level.custom_game_over_hud_elem ]]( players[i] );
            else
            {
                game_over[i] = newclienthudelem( players[i] );
                game_over[i].alignx = "center";
                game_over[i].aligny = "middle";
                game_over[i].horzalign = "center";
                game_over[i].vertalign = "middle";
                game_over[i].y = game_over[i].y - 130;
                game_over[i].foreground = 1;
                game_over[i].fontscale = 3;
                game_over[i].alpha = 0;
                game_over[i].color = ( 1, 1, 1 );
                game_over[i].hidewheninmenu = 1;
				
				if (level.exfilstarted == 1)
				{
					if (level.successfulexfil == 1)
					{
						game_over[i] settext( "EXFIL SUCCESSFUL" );
					}
					else
					{
						game_over[i] settext( "EXFIL FAILED" );
					}
				}
				else
				{
					game_over[i] settext( &"ZOMBIE_GAME_OVER" );
				}
                game_over[i] fadeovertime( 1 );
                game_over[i].alpha = 1;

                if ( players[i] issplitscreen() )
                {
                    game_over[i].fontscale = 2;
                    game_over[i].y = game_over[i].y + 40;
                }
            }

            survived[i] = newclienthudelem( players[i] );
            survived[i].alignx = "center";
            survived[i].aligny = "middle";
            survived[i].horzalign = "center";
            survived[i].vertalign = "middle";
            survived[i].y = survived[i].y - 100;
            survived[i].foreground = 1;
            survived[i].fontscale = 2;
            survived[i].alpha = 0;
            survived[i].color = ( 1, 1, 1 );
            survived[i].hidewheninmenu = 1;

            if ( players[i] issplitscreen() )
            {
                survived[i].fontscale = 1.5;
                survived[i].y = survived[i].y + 40;
            }

            if ( level.round_number < 2 )
            {
                if ( level.script == "zombie_moon" )
                {
                    if ( !isdefined( level.left_nomans_land ) )
                    {
                        nomanslandtime = level.nml_best_time;
                        player_survival_time = int( nomanslandtime / 1000 );
                        player_survival_time_in_mins = maps\mp\zombies\_zm::to_mins( player_survival_time );
                        survived[i] settext( &"ZOMBIE_SURVIVED_NOMANS", player_survival_time_in_mins );
                    }
                    else if ( level.left_nomans_land == 2 )
                        survived[i] settext( &"ZOMBIE_SURVIVED_ROUND" );
                }
                else
                    survived[i] settext( &"ZOMBIE_SURVIVED_ROUND" );
            }
            else
                survived[i] settext( &"ZOMBIE_SURVIVED_ROUNDS", level.round_number );

            survived[i] fadeovertime( 1 );
            survived[i].alpha = 1;
        }
    }

    if ( isdefined( level.custom_end_screen ) )
        level [[ level.custom_end_screen ]]();

    for ( i = 0; i < players.size; i++ )
    {
        players[i] setclientammocounterhide( 1 );
        players[i] setclientminiscoreboardhide( 1 );
    }

    uploadstats();
    maps\mp\zombies\_zm_stats::update_players_stats_at_match_end( players );
    maps\mp\zombies\_zm_stats::update_global_counters_on_match_end();
    wait 1;
    wait 3.95;
    players = get_players();

    foreach ( player in players )
    {
        if ( isdefined( player.sessionstate ) && player.sessionstate == "spectator" )
            player.sessionstate = "playing";
    }

    wait 0.05;
    players = get_players();

//    if ( !isdefined( level._supress_survived_screen ) )
//    {
//        for ( i = 0; i < players.size; i++ )
//        {
//            survived[i] destroy();
//            game_over[i] destroy();
//        }
//    }
//    else
//    {
//        for ( i = 0; i < players.size; i++ )
//        {
//            if ( isdefined( players[i].survived_hud ) )
//                players[i].survived_hud destroy();
//
//            if ( isdefined( players[i].game_over_hud ) )
//                players[i].game_over_hud destroy();
//        }
//    }

    intermission();
    wait( level.zombie_vars["zombie_intermission_time"] );
    level notify( "stop_intermission" );
    array_thread( get_players(), ::player_exit_level );
    bbprint( "zombie_epilogs", "rounds %d", level.round_number );
    wait 1.5;
    players = get_players();

    for ( i = 0; i < players.size; i++ )
        players[i] cameraactivate( 0 );

    exitlevel( 0 );
    wait 666;
}