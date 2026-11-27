class_name EventPresenter
extends Node
## Decides when a raised event shows (architecture §9.1, ux-design §12). The Session's scheduler decides
## whether it exists (caps, quiet hours); this only holds and orders what was raised:
## - Nothing interrupts an open sheet, the feed sequence, the smell moment or the return flow.
## - The queue releases 600 ms after the main screen goes idle: attention, then nudge, then info.
## - One tier at a time, except a toast may show while a card is up. Toasts keep a 1.2 s gap.
## - event_withdrawn hides a queued or shown card (for example hungry_again after a feed).
## Toasts need no acknowledgement. Cards and sheets are acknowledged through Session.apply(AckEventAction).

signal present_sheet(event: SimEvent)
signal present_card(event: SimEvent)
signal present_toast(event: SimEvent)
signal withdraw_shown(uid: int)

const IDLE_DELAY_S: float = 0.6
const TOAST_GAP_S: float = 1.2
const TOAST_QUEUE_MAX: int = 3
const PRIORITY: Dictionary[StringName, int] = {
	SimEvent.PRESENT_SHEET: 0, SimEvent.PRESENT_CARD: 1, SimEvent.PRESENT_TOAST: 2,
}

## Returns true while something holds the screen (UiRoot.is_idle() negated, plus the return flow).
var is_busy: Callable = func() -> bool: return false
## True while a card or a sheet from this presenter is up.
var card_up: Callable = func() -> bool: return false
var sheet_up: Callable = func() -> bool: return false
var toast_up: Callable = func() -> bool: return false

var queue: Array[SimEvent] = []
var shown_uid: int = 0

var _idle_since_ms: int = -1
var _last_toast_ms: int = -1000000


func bind(session: GameSession) -> void:
	session.event_raised.connect(enqueue)
	session.event_withdrawn.connect(withdraw)


func enqueue(e: SimEvent) -> void:
	for q: SimEvent in queue:
		if q.uid == e.uid:
			return
	queue.append(e)
	var toasts: Array[SimEvent] = []
	for q: SimEvent in queue:
		if q.presentation() == SimEvent.PRESENT_TOAST:
			toasts.append(q)
	if toasts.size() > TOAST_QUEUE_MAX:
		# The oldest info drops to the journal only (Session already wrote it).
		queue.erase(toasts[0])


func withdraw(uid: int) -> void:
	for i: int in range(queue.size() - 1, -1, -1):
		if queue[i].uid == uid:
			queue.remove_at(i)
	if shown_uid == uid:
		shown_uid = 0
		withdraw_shown.emit(uid)


func _process(_delta: float) -> void:
	if queue.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	if is_busy.call():
		_idle_since_ms = -1
		return
	if _idle_since_ms < 0:
		_idle_since_ms = now
	if now - _idle_since_ms < int(IDLE_DELAY_S * 1000.0 * UiMotion.time_scale):
		return
	queue.sort_custom(func(a: SimEvent, b: SimEvent) -> bool:
		var pa: int = PRIORITY.get(a.presentation(), 2)
		var pb: int = PRIORITY.get(b.presentation(), 2)
		return pa < pb if pa != pb else a.uid < b.uid)
	var next: SimEvent = queue[0]
	match next.presentation():
		SimEvent.PRESENT_SHEET:
			if sheet_up.call():
				return
			queue.pop_front()
			shown_uid = next.uid
			present_sheet.emit(next)
		SimEvent.PRESENT_CARD:
			if card_up.call() or sheet_up.call():
				return
			queue.pop_front()
			shown_uid = next.uid
			present_card.emit(next)
		_:
			if toast_up.call() or now - _last_toast_ms < int(TOAST_GAP_S * 1000.0 * UiMotion.time_scale):
				return
			queue.pop_front()
			_last_toast_ms = now
			present_toast.emit(next)
