extends Node
## Store and platform services. Each one works without its plugin (desktop, or not set up yet):
## its calls then do nothing, so the game never depends on them.

var ads: AdsService
var analytics: AnalyticsService
var share: ShareService
var leaderboards: LeaderboardService
var store: StoreService
var push: PushService


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	analytics = _add(AnalyticsService.new())
	ads = _add(AdsService.new())
	share = _add(ShareService.new())
	leaderboards = _add(LeaderboardService.new())
	store = _add(StoreService.new())
	push = _add(PushService.new())


func _add(service: Node) -> Node:
	add_child(service)
	return service


## Logs what a service would do when its plugin is missing (debug builds only).
static func trace(what: String) -> void:
	if OS.is_debug_build():
		print_rich("[color=gray][services] %s[/color]" % what)
