class_name PieceCard
extends Control
## 조각 선택 카드 (기획서 2장)

signal picked(card: PieceCard)

const CELL: float = 18.0

var piece: Piece
var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(104, 104)


func set_piece(p: Piece) -> void:
	piece = p
	selected = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(self)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.15, 0.15, 0.2), true)
	if selected:
		draw_rect(Rect2(Vector2.ZERO, size), Color.YELLOW, false, 3.0)
	if piece == null:
		return
	var off: Vector2 = (size - Vector2(piece.size()) * CELL) / 2.0
	for i in piece.cells.size():
		draw_rect(Rect2(off + Vector2(piece.cells[i]) * CELL, Vector2(CELL - 1, CELL - 1)), Field.color_of(piece.terrain[i]), true)
		if i == piece.hq_index: # 본부 칸 표시
			draw_rect(Rect2(off + Vector2(piece.cells[i]) * CELL + Vector2(5, 5), Vector2(CELL - 11, CELL - 11)), Field.HQ_COLOR, true)
