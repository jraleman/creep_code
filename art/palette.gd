extends RefCounted

## Weathered limestone, aged brass and cold starlight share one readable palette.
## Lit runes are accents; numbers and shapes still carry every puzzle fact.

const INK := Color("141723")
const PANEL := Color("1c2230")
const NIGHT := Color("0d111a")
const CREAM := Color("f6e6c8")
const PAPER := Color("c4bcaa")
const WOOD := Color("71533d")
const WOOD_LIGHT := Color("a58560")
const WOOD_DARK := Color("3b2d2b")
const CLAY := Color("9c6554")
const RED := Color("c57961")
const BLUE := Color("3c5978")
const BLUE_LIGHT := Color("a4c9e5")
const BLUE_DARK := Color("29364d")
const GOLD := Color("f0c77a")
const BRASS := Color("b28b50")
const STONE := Color("656b78")
const STONE_LIGHT := Color("91918b")
const STONE_DARK := Color("3d4555")
const MORTAR := Color("242a36")
const IRON := Color("2c303a")
const ARCANE := Color("88b9f0")
const VIOLET := Color("b69de8")
const MOSS := Color("617658")
const BACKDROP := Color("0d1424")
const SUNLIGHT := Color("d8d2c5")
const FILL_LIGHT := Color("94a3c7")
const FIRE := Color("ffc786")

static var _weathering: NoiseTexture2D


## The shop and the ritual use the same painted finish, not two interpretations
## of an outfit. Only the immutable weathering texture is shared.
static func painted_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	if _weathering == null:
		var noise := FastNoiseLite.new()
		noise.seed = 1703
		noise.frequency = 0.09
		noise.fractal_octaves = 3
		var tint := Gradient.new()
		tint.colors = PackedColorArray([Color(0.72, 0.69, 0.66), Color.WHITE])
		_weathering = NoiseTexture2D.new()
		_weathering.width = 128
		_weathering.height = 128
		_weathering.noise = noise
		_weathering.seamless = true
		_weathering.color_ramp = tint
	material.albedo_texture = _weathering
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * 1.25
	return material
