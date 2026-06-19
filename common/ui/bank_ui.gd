extends PanelContainer

@onready var wallet_val: Label = %WalletValue
@onready var bank_val: Label = %BankValue
@onready var amount_input: LineEdit = %AmountInput
@onready var dep_btn: Button = %DepositButton
@onready var wd_btn: Button = %WithdrawButton
@onready var dep_all_btn: Button = %DepositAllButton
@onready var wd_all_btn: Button = %WithdrawAllButton
@onready var close_btn: Button = %CloseButton

var active_bank = null
var active_player = null

signal closed()

func setup(bank, player) -> void:
	active_bank = bank
	active_player = player
	_update_balances()
	
	dep_btn.pressed.connect(_on_deposit_pressed)
	wd_btn.pressed.connect(_on_withdraw_pressed)
	dep_all_btn.pressed.connect(_on_deposit_all_pressed)
	wd_all_btn.pressed.connect(_on_withdraw_all_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	
	# Scale animation on opening
	pivot_offset = Vector2(160, 120)
	scale = Vector2(0.9, 0.9)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Focus first button
	var first_btn = _find_first_focusable_button(self)
	if first_btn:
		first_btn.grab_focus()

func _update_balances() -> void:
	wallet_val.text = "%d G" % GameState.gold
	bank_val.text = "%d G" % GameState.bank_balance
	amount_input.text = ""
	
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud and hud.has_method("update_hud_values"):
		hud.update_hud_values()

func _on_deposit_pressed() -> void:
	var amt = amount_input.text.to_int()
	if amt <= 0:
		_spawn_floating_text("Enter valid amount!")
		return
	if GameState.gold < amt:
		_spawn_floating_text("Not enough gold!")
		return
	GameState.gold -= amt
	GameState.bank_balance += amt
	_update_balances()
	_spawn_floating_text("Deposited %d G" % amt)

func _on_withdraw_pressed() -> void:
	var amt = amount_input.text.to_int()
	if amt <= 0:
		_spawn_floating_text("Enter valid amount!")
		return
	if GameState.bank_balance < amt:
		_spawn_floating_text("Not enough in bank!")
		return
	GameState.bank_balance -= amt
	GameState.gold += amt
	_update_balances()
	_spawn_floating_text("Withdrew %d G" % amt)

func _on_deposit_all_pressed() -> void:
	var amt = GameState.gold
	if amt <= 0:
		_spawn_floating_text("No gold to deposit!")
		return
	GameState.gold = 0
	GameState.bank_balance += amt
	_update_balances()
	_spawn_floating_text("Deposited all %d G" % amt)

func _on_withdraw_all_pressed() -> void:
	var amt = GameState.bank_balance
	if amt <= 0:
		_spawn_floating_text("No savings to withdraw!")
		return
	GameState.bank_balance = 0
	GameState.gold += amt
	_update_balances()
	_spawn_floating_text("Withdrew all %d G" % amt)

func _on_close_pressed() -> void:
	if active_player:
		active_player.unfreeze()
	closed.emit()
	queue_free()

func _spawn_floating_text(text_str: String) -> void:
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud and hud.has_method("_spawn_floating_text") and active_player:
		hud._spawn_floating_text(text_str, active_player.global_position)

func _find_first_focusable_button(node: Node) -> Button:
	if node is Button and node.focus_mode == Control.FOCUS_ALL and not node.disabled and node.visible:
		return node
	for child in node.get_children():
		var found = _find_first_focusable_button(child)
		if found:
			return found
	return null
