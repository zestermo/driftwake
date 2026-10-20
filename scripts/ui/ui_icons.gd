class_name UIIcons
extends RefCounted
## The menus' pixel icons (the skills menu's tabs and its compass-rose emblem), kept as the mock's SVGs
## (docs/media/progression_mock/icons) and rasterised once with hard edges: no half-transparent pixels.

const SVG := {
	"crown": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" width="16" height="16"><g fill="#0c2427"><rect x="1" y="7" width="14" height="8"/><rect x="1" y="4" width="4" height="4"/><rect x="6" y="2" width="4" height="6"/><rect x="11" y="4" width="4" height="4"/></g><g fill="#f2c45e"><rect x="2" y="8" width="12" height="4"/><rect x="2" y="5" width="2" height="3"/><rect x="7" y="3" width="2" height="5"/><rect x="12" y="5" width="2" height="3"/></g><rect x="2" y="12" width="12" height="2" fill="#b88a3a"/><rect x="5" y="10" width="2" height="1" fill="#f17c62"/><rect x="9" y="10" width="2" height="1" fill="#f17c62"/><rect x="7" y="9" width="2" height="1" fill="#f5e8c8"/></svg>',
	"swords": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" width="16" height="16"><g stroke="#0c2427" stroke-width="4" stroke-linecap="square"><path d="M3 3 L10 10"/><path d="M13 3 L6 10"/><path d="M9 12 L12 9"/><path d="M4 9 L7 12"/></g><g stroke-width="2" stroke-linecap="square"><path d="M3 3 L10 10" stroke="#f5e8c8"/><path d="M13 3 L6 10" stroke="#f5e8c8"/><path d="M9 12 L12 9" stroke="#f2c45e"/><path d="M4 9 L7 12" stroke="#f2c45e"/><path d="M12 12 L13 13" stroke="#f17c62"/><path d="M4 12 L3 13" stroke="#f17c62"/></g></svg>',
	"compass": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" width="16" height="16"><circle cx="8" cy="8" r="7" fill="#0c2427"/><circle cx="8" cy="8" r="5.5" fill="#173338" stroke="#f2c45e" stroke-width="1.5"/><path d="M8 3 L10 8 L6 8 Z" fill="#f17c62"/><path d="M8 13 L10 8 L6 8 Z" fill="#f5e8c8"/></svg>',
	"chest": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" width="16" height="16"><rect x="1" y="3" width="14" height="12" fill="#0c2427"/><rect x="2" y="4" width="12" height="3" fill="#f2c45e"/><rect x="2" y="8" width="12" height="6" fill="#b88a3a"/><rect x="2" y="7" width="12" height="1" fill="#0c2427"/><rect x="7" y="6" width="2" height="4" fill="#f5e8c8"/><rect x="7" y="9" width="2" height="1" fill="#0c2427"/><rect x="2" y="13" width="12" height="1" fill="#8a6a2c"/></svg>',
	"fruit": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" width="16" height="16"><circle cx="8" cy="9.5" r="6.2" fill="#0c2427"/><circle cx="8" cy="9.5" r="5" fill="#8a6cc9"/><path d="M5 9 L8 9 L8 12 L11 12" stroke="#c9a8ff" stroke-width="1" fill="none"/><rect x="5" y="6" width="2" height="1" fill="#c9a8ff"/><rect x="7" y="1" width="2" height="4" fill="#0c2427"/><rect x="8" y="2" width="1" height="2" fill="#8a6a2c"/><rect x="9" y="1" width="5" height="3" fill="#0c2427"/><rect x="10" y="2" width="3" height="1" fill="#9be08a"/></svg>',
	"emblem": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32"><circle cx="16" cy="16" r="10" fill="none" stroke="#65c9c0" stroke-width="1.5"/><path d="M24 8 L18 16 L24 24 L16 18 L8 24 L14 16 L8 8 L16 14 Z" fill="#f5e8c8" stroke="#0c2427" stroke-width="1"/><path d="M16 1 L19 13 L31 16 L19 19 L16 31 L13 19 L1 16 L13 13 Z" fill="#f2c45e" stroke="#0c2427" stroke-width="1"/><path d="M16 1 L19 13 L16 16 Z M31 16 L19 19 L16 16 Z M16 31 L13 19 L16 16 Z M1 16 L13 13 L16 16 Z" fill="#b88a3a"/><circle cx="16" cy="16" r="2" fill="#f17c62" stroke="#0c2427" stroke-width="1"/></svg>',
}

static var _cache: Dictionary = {}


## The icon as a texture, `scale` times its SVG size.
static func tex(id: String, scale: float = 1.0) -> Texture2D:
	var key := "%s@%s" % [id, scale]
	if _cache.has(key):
		return _cache[key]
	var img := Image.new()
	img.load_svg_from_string(SVG[id], scale)
	img.convert(Image.FORMAT_RGBA8)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0) if c.a >= 0.5 else Color(0, 0, 0, 0))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t
