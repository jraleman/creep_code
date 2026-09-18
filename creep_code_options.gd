extends RefCounted

## Preload-safe declarations shared by the manifest, gameplay and model tests.

const Palette = preload("res://games/creep_code/art/palette.gd")
const GAME_ID := "creep_code"
const RELAXED_KEY := "game/creep_code_relaxed_sunrail"
const DEFAULT_RELAXED := false
const SUNRAIL_SECONDS := 90.0
const SCORE_RULES := (
	"1 point per different relic solved this visit (maximum 6). "
	+ "No speed bonus. Hints and retries cost no points."
)

const UP_KEY := "controls/creep_code_up"
const DOWN_KEY := "controls/creep_code_down"
const LEFT_KEY := "controls/creep_code_left"
const RIGHT_KEY := "controls/creep_code_right"
const INTERACT_KEY := "controls/creep_code_interact"
const BACK_KEY := "controls/creep_code_back"
const RESET_KEY := "controls/creep_code_reset"
const HINT_KEY := "controls/creep_code_hint"
const UP := &"creep_code_up"
const DOWN := &"creep_code_down"
const LEFT := &"creep_code_left"
const RIGHT := &"creep_code_right"
const INTERACT := &"creep_code_interact"
const BACK := &"creep_code_back"
const RESET := &"creep_code_reset"
const HINT := &"creep_code_hint"

const RELICS: Array[Dictionary] = [
	{"id": &"sunrail", "title": "The Sunrail", "badge": "SUN", "achievement": "creep_code_sunrail"},
	{"id": &"shaft", "title": "The Whisper Shaft", "badge": "WHISPER", "achievement": "creep_code_shaft"},
	{"id": &"garden", "title": "The Echo Garden", "badge": "ECHO", "achievement": "creep_code_garden"},
	{"id": &"wardens", "title": "The Twin Wardens", "badge": "TWIN", "achievement": "creep_code_wardens"},
	{"id": &"archipelago", "title": "The Broken Archipelago", "badge": "LINK", "achievement": "creep_code_archipelago"},
	{"id": &"stair", "title": "The Memory Stair", "badge": "MIND", "achievement": "creep_code_stair"},
]

const SUNRAIL_TILES: Array[int] = [3, 6, 2, 7, 1, 5, 4, 8, 6, 2, 9, 1]
const SHAFT_FLOORS := 15
const GARDEN_ROWS := ["S..#.", ".#.#.", ".#...", "...#.", "##..G"]
const WARDEN_PYLONS: Array[int] = [1, 3, 4, 6, 8, 11, 13, 16]
const WARDEN_TARGET := 15
const ISLAND_COUNT := 6
const BRIDGE_SOCKETS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 5),
	Vector2i(5, 4), Vector2i(4, 3), Vector2i(3, 0),
	Vector2i(1, 4), Vector2i(0, 4), Vector2i(2, 4),
]
const STAIR_COSTS: Array[int] = [2, 5, 8, 1, 5, 9, 2, 4]

const OUTFIT_SLOT := "keeper_outfit"
const DEFAULT_OUTFIT := &"keeper"
const STORE_RULES := (
	"Finish the ritual to bank 1 Star Shard per point (up to 6). "
	+ "Outfits cost 3 shards, are cosmetic only and stay unlocked."
)
const STORE_SLOTS: Array[Dictionary] = [
	{
		"id": OUTFIT_SLOT, "kind": "outfit", "title": "Keeper",
		"description": "Dress the keeper who guides your ritual.",
	},
]
const STORE_CURRENCY := {
	"name": "Star Shard", "plural": "Star Shards",
	"points_per_score": 1.0, "round_bonus": 0, "win_bonus": 0, "max_per_round": 6,
}
const STORE_ITEMS: Array[Dictionary] = [
	{
		"id": "keeper", "kind": "outfit", "title": "Original Keeper",
		"description": "The familiar goggles, work coat and stargazer's hat. Always yours.",
		"price": 0, "default": true, "badge": "KEEPER",
		"color": Palette.BLUE_LIGHT, "heading": "Keeper outfits",
	},
	{
		"id": "warrior", "kind": "outfit", "title": "Warrior",
		"description": "Bronze-trimmed armor, a crimson cloak, sword and star shield.",
		"price": 3, "badge": "WARD", "color": Palette.RED, "heading": "Keeper outfits",
	},
	{
		"id": "ranger", "kind": "outfit", "title": "Ranger",
		"description": "A moss-green hood, trail cloak, curved bow and a quiver of arrows.",
		"price": 3, "badge": "TRAIL", "color": Palette.MOSS, "heading": "Keeper outfits",
	},
	{
		"id": "wizard", "kind": "outfit", "title": "Wizard",
		"description": "A star-sewn robe, pointed violet hat and crystal-tipped staff.",
		"price": 3, "badge": "ARCANE", "color": Palette.VIOLET, "heading": "Keeper outfits",
	},
]

const TUNABLES: Array[Dictionary] = [
	{
		"key": RELAXED_KEY,
		"type": GameManifest.OPTION_TOGGLE,
		"default": DEFAULT_RELAXED,
		"title": "Untimed Sunrail",
		"description": (
			"Pause the capacitor deadline immediately. Turning this off resumes "
			+ "its remaining time. Failed attempts still need a reset."
		),
		"heading": "Creep Code",
	},
]

const CONTROL_BINDINGS: Array[Dictionary] = [
	{
		"key": UP_KEY, "action": UP, "default": KEY_W, "title": "Upper path / higher floor",
		"description": "Take the upper garden path, raise a listening floor, undo a bridge, or choose one stair step.",
		"player": 0, "movement": true, "heading": "Relic controls",
	},
	{
		"key": DOWN_KEY, "action": DOWN, "default": KEY_S, "title": "Lower path / lower floor",
		"description": "Take the lower garden path, lower a listening floor, or choose two stair steps.",
		"player": 0, "movement": true, "heading": "Relic controls",
	},
	{
		"key": LEFT_KEY, "action": LEFT, "default": KEY_A, "title": "Previous rune / left path",
		"description": "Move left, advance the left warden, choose a previous bridge, or select one stair step.",
		"player": 0, "movement": true, "heading": "Relic controls",
	},
	{
		"key": RIGHT_KEY, "action": RIGHT, "default": KEY_D, "title": "Next rune / right path",
		"description": "Move right, advance the right warden, choose the next bridge, or select two stair steps.",
		"player": 0, "movement": true, "heading": "Relic controls",
	},
	{
		"key": INTERACT_KEY, "action": INTERACT, "default": KEY_E, "title": "Interact / confirm",
		"description": "Arm or confirm a relic, connect a bridge, inscribe or climb a stair; skip a flourish.",
		"player": 0, "heading": "Actions",
	},
	{
		"key": BACK_KEY, "action": BACK, "default": KEY_Q, "title": "Open / close grimoire",
		"description": "Read this relic's rules without spending time or charges.",
		"player": 0, "heading": "Actions",
	},
	{
		"key": RESET_KEY, "action": RESET, "default": KEY_R, "title": "Reset attempt",
		"description": "Retry for free. The garden keeps its echoes; the stair keeps its remembered plaques.",
		"player": 0, "heading": "Actions",
	},
	{
		"key": HINT_KEY, "action": HINT, "default": KEY_H, "title": "Read inscription",
		"description": "Open the paused grimoire at this relic's next inscription.",
		"player": 0, "heading": "Actions",
	},
]
