class_name DemoEndScreen
extends RunScreen

func _ready() -> void:
	super._ready()
	%Replay.pressed.connect(func(): app.replay_demo())

func refresh_text() -> void:
	super.refresh_text()
	if app == null:
		return
	var won: bool = app.demo_run.phase == DemoRun.Phase.COMPLETE
	%Title.text = I18n.t(app.demo_run.campaign.title)
	%Outcome.text = I18n.t("DEMO_COMPLETE" if won else "DEFEAT")
	%Summary.text = I18n.t(app.demo_run.campaign.completion_text if won else "DEMO_DEFEAT_BODY")
	var count: int = app.demo_run.campaign.encounters.size()
	%Progress.text = I18n.t("RUN_PROGRESS", [count if won else app.demo_run.stage, count])
