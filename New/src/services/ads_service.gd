class_name AdsService
extends Node
## AdMob (Poing Studios plugin, addons/admob): Google's consent form where the law requires one
## (on iPhone it also shows Apple's tracking prompt when the IDFA message is set up in AdMob),
## then a banner at the bottom and a full-screen ad every few game overs.
## Debug builds use Google's test ads. On a computer nothing is shown (run with -- --fake-ads to
## see where the banner goes).

signal consent_finished
signal _interstitial_done

## Google's sample ad units: always safe to show and tap.
const TEST_UNITS := {
	"android_banner": "ca-app-pub-3940256099942544/9214589741",
	"android_interstitial": "ca-app-pub-3940256099942544/1033173712",
	"ios_banner": "ca-app-pub-3940256099942544/2435281174",
	"ios_interstitial": "ca-app-pub-3940256099942544/4411468910",
}
## Height used to preview the banner on a computer.
const FAKE_BANNER_HEIGHT := 100.0
## Never keep the game waiting longer than this for the consent form (slow or no network).
const CONSENT_TIMEOUT := 8.0

var consent_done := false
var _sdk_ready := false
var _banner_wanted := false
var _banner: AdView
var _interstitial: InterstitialAd
var _interstitial_loading := false
var _fake_banner: CanvasLayer


func _ready() -> void:
	if "--fake-ads" in OS.get_cmdline_user_args():
		enable_fake_banner()


## Shows a grey stand-in for the banner, to check layouts on a computer.
func enable_fake_banner(viewport: Viewport = null) -> void:
	if not _fake_banner:
		_fake_banner = _make_fake_banner()
	_fake_banner.custom_viewport = viewport
	var view := (viewport if viewport else get_viewport()).get_visible_rect().size
	var bar: Control = _fake_banner.get_child(0)
	bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bar.position = Vector2(0, view.y - FAKE_BANNER_HEIGHT)
	bar.size = Vector2(view.x, FAKE_BANNER_HEIGHT)


func enabled() -> bool:
	return Config.value("ads", "enabled", true) and not Save.ads_removed \
			and not unit("banner").is_empty()


## True when the law requires a way to change ad choices from inside the game (EEA, UK...).
func privacy_options_required() -> bool:
	return Config.is_mobile and UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() \
			== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


func show_privacy_options() -> void:
	if Config.is_mobile:
		UserMessagingPlatform.show_privacy_options_form(func(_error: FormError) -> void: _after_consent())


## Asks for consent where the law requires it, then starts the ads. Emits consent_finished.
func start() -> void:
	if not Config.is_mobile:
		_finish_consent()
		return
	if Config.is_debug and OS.get_environment("CHAKAZULU_TOUR") == "1":
		_after_consent()  # unattended screenshots (tests/device_tour.gd): test ads, no forms
		return
	get_tree().create_timer(CONSENT_TIMEOUT).timeout.connect(_finish_consent)
	var params := ConsentRequestParameters.new()
	if Config.is_debug:  # test phones and Simulators can pretend to be in or out of Europe
		var geography := DebugGeography.Values.DISABLED
		if Config.value("ads", "debug_consent_eea", false):
			geography = DebugGeography.Values.EEA
		elif "--not-eea" in OS.get_cmdline_user_args() or OS.get_environment("CHAKAZULU_NOT_EEA") == "1":
			geography = DebugGeography.Values.NOT_EEA
		if geography != DebugGeography.Values.DISABLED:
			params.consent_debug_settings = ConsentDebugSettings.new()
			params.consent_debug_settings.debug_geography = geography
	UserMessagingPlatform.consent_information.update(params, _on_consent_info,
			func(_error: FormError) -> void: _after_consent())


func show_banner(show := true) -> void:
	_banner_wanted = show and enabled()
	if _fake_banner:
		_fake_banner.visible = _banner_wanted
		Device.banner_height = FAKE_BANNER_HEIGHT if _banner_wanted else 0.0
		return
	_refresh_banner()


## Shows a full-screen ad if enough games were played since the last one. Waits until it closes.
func maybe_show_interstitial() -> void:
	var every: int = Config.value("ads", "interstitial_every_game_overs", 5)
	if not enabled() or Save.game_overs_since_ad < every:
		return
	if not _interstitial:
		_load_interstitial()  # not ready yet: try again after the next game over
		return
	Save.game_overs_since_ad = 0
	var ad := _interstitial
	_interstitial = null
	var master := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(master, true)  # the ad has its own sound
	var done := func() -> void: _interstitial_done.emit()
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = done
	ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void: done.call()
	var safety := get_tree().create_timer(90.0, true)  # never stay stuck behind a broken ad
	safety.timeout.connect(done)
	ad.show()
	await _interstitial_done
	safety.timeout.disconnect(done)
	AudioServer.set_bus_mute(master, false)
	ad.destroy()
	_load_interstitial()


## Called after the player bought "Remove ads".
func remove_ads() -> void:
	_banner_wanted = false
	if _banner:
		_banner.destroy()
		_banner = null
	Device.banner_height = 0.0
	if _fake_banner:
		_fake_banner.visible = false
	_interstitial = null


func unit(kind: String) -> String:
	var platform := "ios" if Config.is_ios else "android"
	if Config.is_debug:
		return TEST_UNITS["%s_%s" % [platform, kind]]
	return Config.value("ads", "%s_%s" % [platform, kind], "")


# ---------------------------------------------------------------- internals

func _on_consent_info() -> void:
	var info := UserMessagingPlatform.consent_information
	if info.get_is_consent_form_available() and info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
		UserMessagingPlatform.load_consent_form(
				func(form: ConsentForm) -> void: form.show(func(_error: FormError) -> void: _after_consent()),
				func(_error: FormError) -> void: _after_consent())
	else:
		_after_consent()


## Google's rule: ads may be requested once consent is obtained or not needed.
func _can_request_ads() -> bool:
	var status := UserMessagingPlatform.consent_information.get_consent_status()
	return status == ConsentInformation.ConsentStatus.OBTAINED \
			or status == ConsentInformation.ConsentStatus.NOT_REQUIRED


func _after_consent() -> void:
	_finish_consent()
	# The consent form does not tell which purposes the player accepted, so analytics and crash
	# reports only run where no consent is needed (outside Europe, the UK and Switzerland).
	var status := UserMessagingPlatform.consent_information.get_consent_status()
	Services.analytics.set_consent(status == ConsentInformation.ConsentStatus.NOT_REQUIRED)
	# Release builds follow Google's rule strictly. Debug builds (test ads only) also start when
	# the consent lookup fails, e.g. before the consent message is set up in AdMob.
	if _sdk_ready or not enabled() or not (_can_request_ads() or Config.is_debug):
		return
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		_sdk_ready = true
		_refresh_banner()
		_load_interstitial()
	MobileAds.initialize(listener)


func _finish_consent() -> void:
	if consent_done:
		return
	consent_done = true
	consent_finished.emit()


func _refresh_banner() -> void:
	if not _sdk_ready:
		return
	if _banner_wanted and not _banner:
		var size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
		_banner = AdView.new(unit("banner"), size, AdPosition.BOTTOM)
		var listener := AdListener.new()
		listener.on_ad_loaded = _on_banner_loaded
		_banner.ad_listener = listener
		_banner.load_ad(AdRequest.new())
	elif _banner:
		if _banner_wanted:
			_banner.show()
			_on_banner_loaded()
		else:
			_banner.hide()
			Device.banner_height = 0.0


## The interface makes room for the banner, which reports its height in screen pixels.
func _on_banner_loaded() -> void:
	if not _banner or not _banner_wanted:
		return
	var window := float(DisplayServer.window_get_size().y)
	if window > 0:
		Device.banner_height = _banner.get_height_in_pixels() * get_tree().root.get_visible_rect().size.y / window


func _load_interstitial() -> void:
	if not _sdk_ready or _interstitial or _interstitial_loading or not enabled():
		return
	_interstitial_loading = true
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial_loading = false
		_interstitial = ad
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		_interstitial_loading = false
	InterstitialAdLoader.new().load(unit("interstitial"), AdRequest.new(), callback)


func _make_fake_banner() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.visible = false
	var bar := ColorRect.new()
	bar.color = Color("3b3b44")
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var text := Label.new()
	text.text = "Test ad banner"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.7))
	bar.add_child(text)
	layer.add_child(bar)
	add_child(layer)
	return layer
