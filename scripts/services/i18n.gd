class_name I18n
extends RefCounted
## Translate UI keys or source text only when presenting a message.

static func t(key: String, arguments: Array = []) -> String:
	var text := String(TranslationServer.translate(key))
	if arguments.is_empty():
		return text
	var values: Array = []
	for value in arguments:
		values.append(String(TranslationServer.translate(value)) if value is String else value)
	return text % values
