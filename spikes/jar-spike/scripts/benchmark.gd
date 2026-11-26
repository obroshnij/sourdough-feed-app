class_name SpikeBenchmark
extends Node
## Scripted orbit benchmark. The starter state is frozen. The camera orbits a
## full turn while pitch and zoom sweep. Per frame it records the 3D viewport's
## CPU and GPU render time (RenderingServer.viewport_get_measured_render_time_*),
## writes a CSV under user://, appends a summary row and prints p50/p95/p99.
## Every number is a Mac estimate, not a phone measurement.

signal finished

var viewport_rid: RID
var orbit: OrbitCamera
var seconds: float = 60.0
var warmup: float = 3.0
var label: String = "run"
var meta: Dictionary[String, String] = {}

var _t: float = 0.0
var _cpu := PackedFloat32Array()
var _gpu := PackedFloat32Array()
var _frame := PackedFloat32Array()
var _setup := PackedFloat32Array()
var _draw_calls: int = 0
var _done: bool = false


func start() -> void:
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	orbit.input_enabled = false
	set_process(true)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var phase: float = clampf((_t - warmup) / seconds, 0.0, 1.0)
	orbit.yaw = OrbitCamera.DEFAULT_YAW + TAU * phase
	orbit.pitch = 0.30 + 0.22 * sin(TAU * phase * 2.0)
	orbit.distance = OrbitCamera.DEFAULT_DISTANCE * (1.0 + 0.25 * sin(TAU * phase * 3.0))
	if _t < warmup:
		return
	_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid))
	_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
	_setup.append(RenderingServer.get_frame_setup_time_cpu())
	_frame.append(delta * 1000.0)
	_draw_calls = maxi(_draw_calls, RenderingServer.viewport_get_render_info(viewport_rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	if _t >= warmup + seconds:
		_done = true
		_finish()


func _finish() -> void:
	var dir: String = "user://bench"
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = "%s/%s.csv" % [dir, label]
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_line("frame,cpu_ms,gpu_ms,setup_ms,frame_ms")
	for i: int in range(_cpu.size()):
		f.store_line("%d,%.4f,%.4f,%.4f,%.4f" % [i, _cpu[i], _gpu[i], _setup[i], _frame[i]])
	f.close()
	var row: PackedStringArray = PackedStringArray([
		label, meta.get("renderer", ""), meta.get("adapter", ""), meta.get("api", ""), meta.get("tier", ""),
		meta.get("resolution", ""), meta.get("msaa", ""), str(_cpu.size()),
		"%.3f" % pct(_cpu, 0.5), "%.3f" % pct(_cpu, 0.95), "%.3f" % pct(_cpu, 0.99),
		"%.3f" % pct(_gpu, 0.5), "%.3f" % pct(_gpu, 0.95), "%.3f" % pct(_gpu, 0.99),
		"%.3f" % pct(_frame, 0.5), "%.3f" % pct(_frame, 0.95), "%.3f" % pct(_frame, 0.99),
		str(_draw_calls)])
	var summary_path: String = "%s/summary.csv" % dir
	var exists: bool = FileAccess.file_exists(summary_path)
	var s: FileAccess = FileAccess.open(summary_path, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if exists:
		s.seek_end()
	else:
		s.store_line("label,renderer,adapter,api,tier,resolution,msaa,frames,cpu_p50,cpu_p95,cpu_p99,gpu_p50,gpu_p95,gpu_p99,frame_p50,frame_p95,frame_p99,draw_calls_max")
	s.store_line(",".join(row))
	s.close()
	print("BENCH (Mac estimate, not a phone) %s" % label)
	print("BENCH   renderer=%s adapter=%s api=%s tier=%s res=%s msaa=%s frames=%d draw_calls_max=%d" % [
		meta.get("renderer", ""), meta.get("adapter", ""), meta.get("api", ""), meta.get("tier", ""),
		meta.get("resolution", ""), meta.get("msaa", ""), _cpu.size(), _draw_calls])
	print("BENCH   cpu_ms   p50=%.3f p95=%.3f p99=%.3f" % [pct(_cpu, 0.5), pct(_cpu, 0.95), pct(_cpu, 0.99)])
	print("BENCH   gpu_ms   p50=%.3f p95=%.3f p99=%.3f" % [pct(_gpu, 0.5), pct(_gpu, 0.95), pct(_gpu, 0.99)])
	print("BENCH   frame_ms p50=%.3f p95=%.3f p99=%.3f" % [pct(_frame, 0.5), pct(_frame, 0.95), pct(_frame, 0.99)])
	print("BENCH   csv=%s" % ProjectSettings.globalize_path(path))
	print("BENCH   gpu_nonzero_frames=%d of %d" % [_count_nonzero(_gpu), _gpu.size()])
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	if rd != null:
		var n: int = rd.get_captured_timestamps_count()
		print("BENCH   rd_timestamps=%d frame=%d" % [n, rd.get_captured_timestamps_frame()])
		for i: int in range(n):
			print("BENCH     ts %d %s gpu_us=%d cpu_us=%d" % [i, rd.get_captured_timestamp_name(i),
				rd.get_captured_timestamp_gpu_time(i), rd.get_captured_timestamp_cpu_time(i)])
	finished.emit()


static func _count_nonzero(values: PackedFloat32Array) -> int:
	var c: int = 0
	for v: float in values:
		if v > 0.0:
			c += 1
	return c


static func pct(values: PackedFloat32Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat32Array = values.duplicate()
	sorted.sort()
	var idx: int = clampi(int(ceil(p * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return sorted[idx]
