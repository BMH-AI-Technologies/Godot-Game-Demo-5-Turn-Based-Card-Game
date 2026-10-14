extends GamePopup

func configure(title_key: String, body: String, already_translated: bool = false) -> void:
	%Heading.text = I18n.t(title_key)
	%Body.text = body if already_translated else I18n.t(body)
