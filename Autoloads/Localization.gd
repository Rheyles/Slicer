extends Node

## LOCALIZATION
## This autoload contains the variables and methods to manage the language of the game
##
## Ex : label.text = tr("MY_TOKEN")

var available_lng = ["en", "fr"]
var crt_lng_idx = 0

func change_lng(new_lng : String) -> void:
	TranslationServer.set_locale(new_lng)
	crt_lng_idx = available_lng.find(new_lng)
	EVENTS.emit_signal("language_changed")

func change_lng_idx(new_idx : int) -> void:
	crt_lng_idx = new_idx % available_lng.size()
	TranslationServer.set_locale(available_lng[crt_lng_idx])
	EVENTS.emit_signal("language_changed")


