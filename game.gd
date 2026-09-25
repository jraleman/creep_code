extends RefCounted

## Creep Code is discovered entirely through game-owned data and resources.

const OPTIONS := preload("res://games/creep_code/creep_code_options.gd")
const PALETTE := preload("res://games/creep_code/art/palette.gd")


## The shared shell supplies navigation, pause, settings, results and saves.
static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = OPTIONS.GAME_ID
	game.title = "Creep Code"
	game.tagline = "Beneath old stone, the stars still listen."
	game.menu_order = 7
	game.gameplay_scene_path = "res://games/creep_code/gameplay.tscn"
	game.intro_scene_path = "res://games/creep_code/intro.tscn"
	game.supports_multiplayer = false
	game.supports_cpu_opponent = false
	game.uses_shell_round_rules = false
	game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	game.tunables = OPTIONS.TUNABLES
	game.control_bindings = OPTIONS.CONTROL_BINDINGS
	game.store_items = OPTIONS.STORE_ITEMS
	game.store_slots = OPTIONS.STORE_SLOTS
	game.store_currency = OPTIONS.STORE_CURRENCY
	game.store_preview_scene_path = "res://games/creep_code/ui/outfit_preview.tscn"
	game.tutorial_video_path = "res://games/creep_code/assets/video/tutorial.ogv"
	game.tutorial_poster_path = "res://games/creep_code/assets/video/tutorial_poster.webp"
	game.stats_url = "https://deskcansaw.com"
	game.achievements = {
		"creep_code_sunrail": {
			"title": "Borrowed Sunlight", "description": "Restore the Sunrail relay.",
			"badge": "SUN",
		},
		"creep_code_shaft": {
			"title": "A Better Question", "description": "Find the Whisper Shaft beacon.",
			"badge": "LIFT",
		},
		"creep_code_garden": {
			"title": "Not a Step Wasted", "description": "Take a shortest route through the garden.",
			"badge": "ECHO",
		},
		"creep_code_wardens": {
			"title": "A Balanced Pair", "description": "Match the Twin Wardens' target.",
			"badge": "TWIN",
		},
		"creep_code_archipelago": {
			"title": "Worlds Together", "description": "Connect every island without a redundant bridge.",
			"badge": "LINK",
		},
		"creep_code_stair": {
			"title": "Remember the Way", "description": "Remember and climb the cheapest Memory Stair route.",
			"badge": "MIND",
		},
		"creep_code_observatory": {
			"title": "The Stars Return", "description": "Join all six seals and awaken the constellation.",
			"badge": "STAR",
		},
	}
	game.copy = {
		"store_intro": (
			"Finished rituals bank 1 Star Shard per point (max 6). Outfits cost 3 and equip "
			+ "instantly. Cosmetic only. Original Keeper is free."
		),
		"single_player_description": "One evolving ritual stage. Six enchanted relics. Bring back the stars.",
		"player_one_control_description": (
			"Click or tap the 3D relics, or use direction keys. Interact arms or confirms; "
			+ "the next one awakens automatically. Grimoire pauses play for reading."
		),
		"instructions_headline": "AWAKEN THE CONSTELLATION",
		"instructions_rules": (
			"One ancient platform transforms through six algorithm-powered relics. "
			+ "Each restored relic joins your constellation; the next rises automatically. "
			+ "Interact skips a flourish without spending a charge or arming the next puzzle.\n"
			+ "Sunrail: scan three neighboring crystals and lock the strongest charge. "
			+ "Preview is free; only arming starts its 90-second deadline. Pause or open "
			+ "the grimoire to freeze it. Untimed Sunrail in Settings removes the deadline.\n"
			+ "Shaft: choose a numbered listening seal, then listen for HIGHER or LOWER. Garden: follow "
			+ "echoes, then find a shortest route. These use questions and crossings, "
			+ "NOT seconds. Retrying a revealed garden keeps its echoes.\n"
			+ "Wardens: move sorted endpoints inward to match a target pair. "
			+ "Archipelago: connect different island networks; Up undoes a bridge. "
			+ "Stair: remember the cheapest arrivals, then climb one or two steps within the energy budget. "
			+ "All three are untimed; retries keep the stair's remembered plaques.\n"
			+ OPTIONS.SCORE_RULES + " Seals are permanent; visit points start at zero. "
			+ "An unfinished save resumes at its first missing seal. A complete save starts a fresh ritual.\n"
			+ OPTIONS.STORE_RULES
		),
		"instructions_demo_prompt": "OBSERVE. TRY. LISTEN.",
		"instructions_player_one_controls": (
			"Click or tap a crystal to start its three-cell frame, a numbered listening seal, "
			+ "or a neighboring garden platform. Direction keys and the compact action row also work. "
			+ "Tap a warden's endpoint to discard it, a bridge socket to select it, "
			+ "or a stair predecessor / destination to choose it. Confirm bridges and stairs with Interact. "
			+ "Interact arms, confirms, finishes the echo reveal, or skips a flourish. "
			+ "Grimoire opens the rules and pauses the puzzle; Interact or Grimoire closes it. "
			+ "Hint opens the paused grimoire at the next inscription. Retries are free. Escape pauses."
		),
	}
	var presentation := GameTheme.new()
	presentation.logo_texture_path = "res://games/creep_code/assets/game-icon.svg"
	presentation.accent = PALETTE.GOLD
	presentation.light = PALETTE.CREAM
	presentation.plaque_color = PALETTE.BLUE_DARK
	presentation.background_top = PALETTE.INK
	presentation.background_bottom = PALETTE.NIGHT
	presentation.style_share_card = true
	game.theme = presentation
	game.credits = [
		{"heading": "Creep Code", "lines": [
			"Game design and development: DeskCanSaw Games",
			"Six algorithm-powered relics. One transforming ritual stage.",
		]},
		{"heading": "Art and sound", "lines": [
			"Original dungeon meshes, procedural weathering and vector artwork.",
			"Original keeper outfits and rotating 3D wardrobe portraits.",
			"Flying wardens, unfolding bridges, remembered stairs and Compatibility candlelight.",
			"Shared DeskCanSaw UI sounds and game framework.",
		]},
	]
	return game
