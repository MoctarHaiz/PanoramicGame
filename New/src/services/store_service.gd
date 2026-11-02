class_name StoreService
extends Node
## The "Remove ads" purchase (one-time, non-consumable): Google Play Billing on Android, StoreKit 2
## on iPhone. Off until config/game_config.cfg [remove_ads] enabled=true; tools/extras.py then adds
## the plugins to the build. The plugins are reached by name only, so the game runs without them.

## Emitted when ads are removed (purchase or restore).
signal ads_removed
## Emitted after a restore: true when a purchase was found.
signal restore_finished(found: bool)

# Google Play Billing values (BillingClient.gd of the plugin).
const PLAY_OK := 0
const PLAY_USER_CANCELED := 1
const PLAY_ITEM_ALREADY_OWNED := 7
const PLAY_PURCHASED := 1
const PLAY_PENDING := 2
# StoreKitManager values.
const APPLE_OK := 0
const APPLE_PENDING := 5

## True when the phone's store answered and knows the product.
var available := false
var _play: Object
var _store_kit: RefCounted
var _apple_product: Object
var _price := ""
var _restoring := false


func _ready() -> void:
	if not enabled():
		return
	if Config.is_android and Engine.has_singleton("GodotGooglePlayBilling"):
		_start_play()
	elif Config.is_ios and ClassDB.class_exists(&"StoreKitManager"):
		_start_apple()


func enabled() -> bool:
	return Config.value("remove_ads", "enabled", false)


func product_id() -> String:
	return Config.value("remove_ads", "product_id", "remove_ads")


## The price in the player's currency, once the store has sent it.
func price() -> String:
	return _price


func buy_remove_ads() -> void:
	if Save.ads_removed:
		return
	if not available:
		Services.trace("buy %s" % product_id())
		if Config.is_mobile:
			Ui.toast(tr("STORE_UNAVAILABLE"))
			_refresh()
		return
	Services.analytics.log_event("purchase_start", {"item": product_id()})
	if _play:
		var result: Dictionary = _play.purchase(product_id(), "", "", false)
		if result.get("response_code", -1) != PLAY_OK:
			Ui.toast(tr("STORE_UNAVAILABLE"))
	elif _store_kit:
		_store_kit.purchase(_apple_product)


## Looks for an earlier purchase (new phone, reinstall). Emits restore_finished.
func restore() -> void:
	if not available:
		Services.trace("restore purchases")
		_finish_restore(false)
		return
	_restoring = true
	if _play:
		_play.queryPurchases("inapp", false)
	elif _store_kit:
		_store_kit.restore_purchases()


func _grant() -> void:
	if Save.ads_removed:
		return
	Save.set_option(&"ads_removed", true)
	Services.ads.remove_ads()
	Services.analytics.log_event("purchase", {"item": product_id()})
	Ui.toast(tr("PURCHASE_THANKS"))
	ads_removed.emit()


func _finish_restore(found: bool) -> void:
	_restoring = false
	if not found:
		Ui.toast(tr("NOTHING_TO_RESTORE"))
	restore_finished.emit(found)


## Asks the store again after it was unreachable (no network at launch...).
func _refresh() -> void:
	if _play:
		_play.startConnection()
	elif _store_kit:
		_store_kit.request_products(PackedStringArray([product_id()]))


# ---------------------------------------------------------------- Google Play

func _start_play() -> void:
	_play = Engine.get_singleton("GodotGooglePlayBilling")
	_play.initPlugin()
	_play.connect("connected", _on_play_connected)
	_play.connect("query_product_details_response", _on_play_product_details)
	_play.connect("query_purchases_response", _on_play_purchases)
	_play.connect("on_purchase_updated", _on_play_purchase_updated)
	_play.startConnection()


func _on_play_connected() -> void:
	_play.queryProductDetails(PackedStringArray([product_id()]), "inapp")
	_play.queryPurchases("inapp", false)  # also catches purchases made while the game was closed


func _on_play_product_details(response: Dictionary) -> void:
	if response.get("response_code", -1) != PLAY_OK:
		return
	for details: Dictionary in response.get("product_details", []):
		if details.get("product_id") != product_id():
			continue
		available = true
		var offers: Variant = details.get("one_time_purchase_offer_details_list")
		if offers is Array and not offers.is_empty():
			_price = offers[0].get("formatted_price", "")


func _on_play_purchases(response: Dictionary) -> void:
	var found := false
	if response.get("response_code", -1) == PLAY_OK:
		for purchase: Dictionary in response.get("purchases", []):
			found = _process_play_purchase(purchase) or found
	if _restoring:
		_finish_restore(found)


func _on_play_purchase_updated(response: Dictionary) -> void:
	match response.get("response_code", -1):
		PLAY_OK:
			for purchase: Dictionary in response.get("purchases", []):
				_process_play_purchase(purchase)
		PLAY_ITEM_ALREADY_OWNED:
			_play.queryPurchases("inapp", false)
		PLAY_USER_CANCELED:
			pass
		_:
			Ui.toast(tr("STORE_UNAVAILABLE"))


## Returns true when the purchase is "Remove ads" and paid.
func _process_play_purchase(purchase: Dictionary) -> bool:
	if not product_id() in purchase.get("product_ids", []):
		return false
	match purchase.get("purchase_state"):
		PLAY_PURCHASED:
			_grant()
			if not purchase.get("is_acknowledged", false):
				_play.acknowledgePurchase(purchase.get("purchase_token", ""))  # or Google refunds it
			return true
		PLAY_PENDING:
			Ui.toast(tr("PURCHASE_PENDING"))
	return false


# ---------------------------------------------------------------- App Store

func _start_apple() -> void:
	_store_kit = ClassDB.instantiate(&"StoreKitManager")
	_store_kit.products_request_completed.connect(_on_apple_products)
	_store_kit.transaction_updated.connect(_on_apple_transaction)
	_store_kit.purchase_completed.connect(_on_apple_purchase)
	_store_kit.restore_completed.connect(func(_status: int, _message: String) -> void:
		_store_kit.fetch_current_entitlements())
	_store_kit.current_entitlements_fetch_completed.connect(_on_apple_entitlements)
	_store_kit.start()  # delivers purchases that were not finished
	_store_kit.request_products(PackedStringArray([product_id()]))
	_store_kit.fetch_current_entitlements()


func _on_apple_products(products: Array, status: int) -> void:
	if status != APPLE_OK:
		return
	for product: Object in products:
		if product.product_id == product_id():
			_apple_product = product
			_price = product.display_price
			available = true


## Verified purchases, from this phone or another one with the same Apple account.
func _on_apple_transaction(transaction: Object) -> void:
	if transaction.product_id == product_id():
		_grant()
	transaction.finish()


func _on_apple_purchase(transaction: Object, status: int, _message: String) -> void:
	match status:
		APPLE_OK:
			if transaction:
				_on_apple_transaction(transaction)
		APPLE_PENDING:
			Ui.toast(tr("PURCHASE_PENDING"))


func _on_apple_entitlements(entitlements: Array) -> void:
	var found := false
	for transaction: Object in entitlements:
		found = found or transaction.product_id == product_id()
	if _restoring:
		_finish_restore(found)
