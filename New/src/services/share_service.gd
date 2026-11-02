class_name ShareService
extends Node
## The phone's share menu (godot-mobile-plugins share plugin, addons/SharePlugin): a picture of
## the run (ShareCard), a challenge and a link to the game.

var _share: Share


func _ready() -> void:
	if Config.is_mobile:
		_share = Share.new()
		add_child(_share)


func share_run(bobs: int, stars: int) -> void:
	var text := tr("SHARE_TEXT_ONE") if bobs == 1 else tr("SHARE_TEXT") % bobs
	text += "\n" + Config.store_url()
	var image := await ShareCard.render(bobs, stars)
	var path := OS.get_user_data_dir().path_join("share_card.png")
	image.save_png(path)
	Services.analytics.log_event("share", {"bobs": bobs, "stars": stars})
	if _share:
		_share.share_image(path, "Chaka Zulu", "Chaka Zulu", text)
	else:
		Services.trace("share: %s (%s)" % [text, path])
