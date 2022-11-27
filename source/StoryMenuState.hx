package;

#if desktop
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.effects.FlxFlicker;
import flixel.util.FlxTimer;
import lime.net.curl.CURLCode;
import flixel.graphics.FlxGraphic;
import WeekData;

using StringTools;

class StoryMenuState extends MusicBeatState
{
	public static var weekCompleted:Map<String, Bool> = new Map<String, Bool>();
	private static var curWeek:Int = 0;
	
	private static var lastDifficultyName:String = '';
	
	var curDifficulty:Int = 1;
	var loadedWeeks:Array<WeekData> = [];
	
	var grpLocks:FlxTypedGroup<FlxSprite>;
	var optionsGrp:FlxTypedGroup<FlxSprite>;
	var sansGrp:FlxTypedGroup<FlxSprite>;
	
	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		PlayState.isStoryMode = true;
		WeekData.reloadWeekFiles(true);
		if(curWeek >= WeekData.weeksList.length) curWeek = 0;
		persistentUpdate = persistentDraw = true;

		grpLocks = new FlxTypedGroup<FlxSprite>();
		add(grpLocks);
		
		sansGrp = new FlxTypedGroup<FlxSprite>();
		add(sansGrp);
		
		optionsGrp = new FlxTypedGroup<FlxSprite>();
		add(optionsGrp);
		
		Conductor.changeBPM(100);
		
		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end
		
		CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
		if(lastDifficultyName == '')
		{
			lastDifficultyName = CoolUtil.defaultDifficulty;
		}
		curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(lastDifficultyName)));
		
		var diff:String = CoolUtil.difficulties[curDifficulty];
		lastDifficultyName = diff;
		
		for (i in 1...4)
		{
			var weekFile:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			
			loadedWeeks.push(weekFile);
			WeekData.setDirectoryFromWeek(weekFile);
			// weekThing.updateHitbox();
			
			// Needs an offset thingie
			var spr:FlxSprite = new FlxSprite().loadGraphic(Paths.image('mainmenu/phase' + i));
			spr.screenCenter(XY);
			spr.frames = Paths.getSparrowAtlas('mainmenu/phase' + i);
			spr.animation.addByPrefix('idle', 'idle', 24);
			spr.animation.addByPrefix('selected', 'selected', 24);
			spr.animation.play('idle');
			spr.ID = i - 1;
			
			switch (i)
			{
				case 1:
					spr.x = ((1280 / 12) * 2) - (spr.width / 2);
				case 3:
					spr.x = ((1280 / 12) * 10) - (spr.width / 2);
			}
			
			spr.y += (spr.height / 2);
			
			optionsGrp.add(spr);
			spr.updateHitbox();
			spr.centerOffsets();
			
			if (Paths.image('mainmenu/sansPhase' + i) != null)
			{
				var sans:FlxSprite = new FlxSprite();
				sans.frames = Paths.getSparrowAtlas('mainmenu/sansPhase' + i);
				sans.animation.addByPrefix('idle', 'idle', 24, false);
				sans.animation.addByPrefix('selected', 'selected', 24, false);
				sans.animation.play('idle');
				sans.scale.set(0.55, 0.55);
				sans.ID = i - 1;
				sans.updateHitbox();
				sans.centerOffsets();
				
				sans.x = spr.getGraphicMidpoint().x - (sans.width / 2);
				sans.y = (spr.getGraphicMidpoint().y - (sans.height / 2)) - 38;
				
				sansGrp.add(sans);
			}
		}
		
		var spr:FlxSprite = new FlxSprite().loadGraphic(Paths.image('mouse', 'shared'));
		
		FlxG.mouse.load(spr.pixels);
		
		changeWeek();

		super.create();
	}

	var movedBack:Bool = false;
	
	override function update(elapsed:Float)
	{
		if (!movedBack && !selectedWeek)
		{
			if(FlxG.keys.justPressed.CONTROL)
			{
				persistentUpdate = false;
				openSubState(new GameplayChangersSubstate());
			}
			
			optionsGrp.forEach(function(spr:FlxSprite)
			{
				if (FlxG.mouse.overlaps(spr))
				{
					changeWeek(spr.ID);
					
					if (FlxG.mouse.justPressed)
					{
						selectWeek();
						FlxFlicker.flicker(spr, 1, 0.06, true, false);
					}
				}
			});
		}
		
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;
			
		if (controls.BACK && !selectedWeek && !movedBack)
		{
			movedBack = true;
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
			MusicBeatState.switchState(new MainMenuState());
		}
		
		

		super.update(elapsed);
	}

	var selectedWeek:Bool = false;
	var stopspamming:Bool = false;
	
	function selectWeek()
	{
		if (!weekIsLocked(loadedWeeks[curWeek].fileName))
		{
			if (stopspamming == false)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				stopspamming = true;
			}
			
			sansGrp.forEach(function(spr:FlxSprite)
			{
				if (spr.ID == curWeek)
					spr.animation.play('selected', true, true);
			});

			// We can't use Dynamic Array .copy() because that crashes HTML5, here's a workaround.
			var songArray:Array<String> = [];
			var leWeek:Array<Dynamic> = loadedWeeks[curWeek].songs;
			for (i in 0...leWeek.length) {
				songArray.push(leWeek[i][0]);
			}

			// Nevermind that's stupid lmao
			PlayState.storyPlaylist = songArray;
			PlayState.isStoryMode = true;
			selectedWeek = true;

			var diffic = CoolUtil.getDifficultyFilePath(curDifficulty);
			if(diffic == null) diffic = '';

			PlayState.storyDifficulty = curDifficulty;

			PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + diffic, PlayState.storyPlaylist[0].toLowerCase());
			PlayState.campaignScore = 0;
			PlayState.campaignMisses = 0;
			new FlxTimer().start(1, function(tmr:FlxTimer)
			{
				LoadingState.loadAndSwitchState(new PlayState(), true);
				FreeplayState.destroyFreeplayVocals();
			});
		} else {
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
	}

	var lerpScore:Int = 0;
	var intendedScore:Int = 0;

	function changeWeek(change:Int = 0):Void
	{
		curWeek = change;
		PlayState.storyWeek = curWeek;
		
		optionsGrp.forEach(function(spr:FlxSprite)
		{
			spr.animation.play('idle');
			spr.updateHitbox();

			if (spr.ID == curWeek)
			{
				spr.animation.play('selected');
				spr.centerOffsets();
			}
		});
	}
	
	override function beatHit()
	{
		super.beatHit();
		
		sansGrp.forEach(function(spr:FlxSprite)
		{
			if (!selectedWeek)
				spr.animation.play('idle', true);
		});
	}
	

	function weekIsLocked(name:String):Bool {
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!weekCompleted.exists(leWeek.weekBefore) || !weekCompleted.get(leWeek.weekBefore)));
	}
}
