class_name BurstBadge
extends Control
## "NEW BEST!" as a stamp (the user, 2026-11-13, of three panel styles shown: "C", no box, ink brush): a round red ink
## stamp set a little askew beside the count, its edge rough as a rubber stamp's, a thin ring inside it, the words on
## two lines in leaning white capitals. One stamp for a win and a defeat (UI r21, the judges of j17: "two designs");
## after a defeat (`calm`) the same one in a deeper red (and ResultsPanel lets it settle, no fanfare).
## (Before: a gold starburst round a glossy red medallion under a crown.)

const INK := Color("140607")
const TILT := -0.2  ## it sits askew (radians)

var radius := 62.0  ## its outer radius
var calm := false  ## the quiet stamp (a new best after a defeat)


## `text`: the words (split on two lines at the first space); `burst`: its radius in units; `quiet`: the calm one.
func _init(text: String, burst := 62.0, quiet := false) -> void:
	radius = burst
	calm = quiet
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(radius, radius) * 2.0
	size = custom_minimum_size
	pivot_offset = size / 2
	var words := text.to_upper().replace("\u00a0", " ").split(" ", false, 1)
	if words.size() == 2 and words[1].length() <= 1:  # ("RECORD !": its mark stays with its word)
		words = PackedStringArray([text.to_upper()])
	# One size for its lines: the biggest at which the widest fits the disc where its line lies (the disc is
	# narrower above and below its middle: French's "NOUVEAU / RECORD !" spilled out of it at the size "NEW / BEST!"
	# fits; they may cross its inner ring, to its edge).
	const FULL := 42.0
	var lines: Array[DisplayText] = []
	var widest := 1.0
	for w: String in words:
		var t := _line(w, FULL)
		widest = maxf(widest, t.text_width())
		lines.append(t)
	var fit := FULL
	var r := radius - 3.0
	for _pass in 3:
		var far := fit * 0.92 * lines.size() * 0.5 * 0.8  # how far from its middle the outer line's letters reach
		var room := 2.0 * sqrt(maxf(r * r - far * far, 1.0)) * 0.95
		fit = minf(fit, FULL * room / widest)
	for t in lines:
		t.font_size = int(fit)
		t.outline_width = maxf(roundf(fit * 0.07), 1.5)
		t.refresh()
	var line_h := 0.0
	for t in lines:
		line_h = maxf(line_h, t.font_size * 0.92)
	var words_box := Control.new()  # the words, askew with the stamp
	words_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words_box.size = size
	words_box.pivot_offset = size / 2
	words_box.rotation = TILT
	add_child(words_box)
	for i in lines.size():
		var t := lines[i]
		t.size = Vector2(size.x, line_h)
		t.position = Vector2(0, size.y / 2 + (i - lines.size() / 2.0) * line_h)
		words_box.add_child(t)


func _line(text: String, font_size: float) -> DisplayText:
	var t := Ui.display_text(text, int(font_size), Ui.WHITE, Color("5a0808"))
	t.font = Ui.font_slant
	t.depth = 0.0
	t.shadow = Color(0, 0, 0, 0)
	t.tracking = 0.0
	return t


## A disc round `c` with a rough edge (a stamp's): its radius wobbling a little, the same every time.
static func _rough(c: Vector2, r: float, wobble: float, n := 56) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := i * TAU / n
		var k := 1.0 + wobble * (sin(a * 7.0 + 1.3) * 0.5 + sin(a * 13.0 + 0.4) * 0.3 + sin(a * 23.0 + 2.1) * 0.2)
		pts.append(c + Vector2.from_angle(a) * r * k)
	return pts


func _draw() -> void:
	var c := size / 2
	var r := radius - 3.0
	var red := Color("c0161a") if not calm else Color("8e1418")
	draw_colored_polygon(_rough(c, r, 0.03), red)
	var edge := _rough(c, r, 0.03)
	edge.append(edge[0])
	draw_polyline(edge, red, 1.5, true)
	var ring := _rough(c, r * 0.86, 0.012)
	ring.append(ring[0])
	draw_polyline(ring, Color(1.0, 0.86, 0.8, 0.8), maxf(r * 0.035, 1.5), true)
