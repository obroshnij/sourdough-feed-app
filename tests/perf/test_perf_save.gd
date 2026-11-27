extends TestCase
## PERF-04 and SAVE-13 (architecture §11): writing a full-size save takes under 10 ms. Every number is a Mac
## estimate (D-004). The payload is a real Session's, with its journal padded with copies of its own feed
## entry until the encoded save reaches the 128 KB budget, the worst case a player can reach. Only
## SaveStore.save() is timed (encode, write save.tmp, rotate, rename), the median of 5. Runs early, in a
## fresh process (tests/perf/ goes first, R-2).

const BUDGET_MS: float = 10.0
const SIZE_BUDGET: int = 128 * 1024
const RUNS: int = 5


func test_perf_04_a_full_size_save_writes_in_under_10_ms() -> void:
	if not (require(&"m4_save") and require(&"p3_contracts")):
		return
	var dir: String = QaTemp.make("perf_save")
	var s := GameSession.new()
	s.setup(FakeClock.new(1795651200), SaveStore.new(dir))
	var seeded := SaveStore.new(dir)
	s.boot()
	s.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	var payload: Dictionary = s.build_payload()
	var journal: Array = payload["journal"]
	var feed_entry: Dictionary = {}
	for e: Variant in journal:
		if typeof(e) == TYPE_DICTIONARY and (e as Dictionary).get("kind", "") == "feed":
			feed_entry = e
	if not check(not feed_entry.is_empty(), "the session journaled its feed"):
		s.free()
		QaTemp.remove(dir)
		return
	var uid: int = 1000
	while SaveCodec.encode(payload).size() < SIZE_BUDGET - 512:
		var copy: Dictionary = feed_entry.duplicate(true)
		uid += 1
		copy["uid"] = uid
		journal.append(copy)
	var bytes: int = SaveCodec.encode(payload).size()
	check_between(bytes, SIZE_BUDGET - 2048, SIZE_BUDGET, "the padded save is close to the 128 KB budget")
	var times: Array[float] = []
	for i: int in RUNS:
		var start: int = Time.get_ticks_usec()
		var err: Error = seeded.save(payload)
		times.append(float(Time.get_ticks_usec() - start) / 1000.0)
		check_eq(err, OK, "write %d succeeded" % (i + 1))
	times.sort()
	var line: String = "PERF-04 save write, Mac estimate (D-004): median %.2f ms of %d (min %.2f, max %.2f), %d bytes, budget %.0f ms" % [
		times[RUNS / 2], RUNS, times[0], times[RUNS - 1], bytes, BUDGET_MS]
	print("    " + line)
	check(times[RUNS / 2] <= BUDGET_MS, line)
	s.free()
	QaTemp.remove(dir)
