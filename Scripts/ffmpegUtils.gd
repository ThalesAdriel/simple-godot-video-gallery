class_name FFMPEG
extends Node

var _threads : Array = []
var _results : Dictionary = {}
var _mutex : Mutex = Mutex.new()
var _generated_textures : Array = []

func createSegmentFrames(ffmpegPath, ffprobePath, checkffmpeg, filePath, thumbDir, fileName, thumbW, thumbH) -> Dictionary:
	var segments = {"start": [], "middle": [], "end": []}
	if !checkffmpeg:
		push_error("No ffmpeg found!")
		return segments

	if !DirAccess.dir_exists_absolute(thumbDir):
		DirAccess.make_dir_recursive_absolute(thumbDir)

	var inputPabs = ProjectSettings.globalize_path(filePath)
	var duration = getVideoDuration(ffprobePath, inputPabs)
	if duration <= 0.0:
		return segments

	var segmentTimes = [
		duration * 0.1,
		duration * 0.5,
		duration * 0.9
	]
	
	for i in range(3):
		var t := Thread.new()
		_threads.append(t)
		t.start(_generate_segment.bind(i, segmentTimes[i], ffmpegPath, inputPabs, thumbDir, fileName, thumbW, thumbH))

	_wait_for_threads()

	for label in segments.keys():
		if _results.has(label):
			for path in _results[label]:
				var img := Image.new()
				if img.load(path) == OK:
					var tex := ImageTexture.create_from_image(img)
					segments[label].append(tex)
					_generated_textures.append(tex)
				img = null

	return segments
	
func _generate_segment(segIndex, tSec, ffmpegPath, inputPabs, thumbDir, fileName, thumbW, thumbH):
	var label = ["start","middle","end"][segIndex]
	var collected : Array = []
	var framePath = thumbDir.path_join("%s_%s.png" % [fileName, label])
	var outAbs = ProjectSettings.globalize_path(framePath)

	if !FileAccess.file_exists(outAbs):
		OS.execute(ffmpegPath, [
			"-hwaccel","auto",
			"-ss", str(tSec),
			"-i", inputPabs,
			"-vf","scale=%d:%d" % [thumbW, thumbH],
			"-q:v", "2",
			"-y", outAbs
		], [], true)

	if !isBlackWhite(outAbs):
		collected.append(outAbs)
	else:
		collected.append(outAbs)

	_mutex.lock()
	_results[label] = collected
	_mutex.unlock()

func _wait_for_threads():
	for t in _threads:
		t.wait_to_finish()
	_threads.clear()

func isBlackWhite(path) -> bool:
	var img := Image.new()
	if img.load(path) != OK:
		return true

	var w = img.get_width()
	var h = img.get_height()
	if w * h == 0:
		return true

	var b = 0
	var wpx = 0
	for y in range(h):
		for x in range(w):
			var c = img.get_pixel(x, y)
			if c.r < 0.05 and c.g < 0.05 and c.b < 0.05:
				b += 1
			elif c.r > 0.95 and c.g > 0.95 and c.b > 0.95:
				wpx += 1

	var total = w * h
	if float(b)/total > 0.9: return true
	if float(wpx)/total > 0.9: return true
	return false

func getVideoDuration(ffprobePath, videoPath) -> float:
	if !FileAccess.file_exists(ffprobePath):
		return 0.0

	var out = []
	if OS.execute(
		ffprobePath,
		["-v","error","-show_entries","format=duration","-of","default=noprint_wrappers=1:nokey=1",videoPath],
		out,
		true
	) == 0 and out.size() > 0:
		return float(out[0])

	return 0.0

func freeSegmentTextures(segments: Dictionary):
	for key in segments.keys():
		for tex in segments[key]:
			if tex:
				tex.free()
	segments.clear()

func _exit_tree():
	for t in _threads:
		t.wait_to_finish()

	for tex in _generated_textures:
		if tex:
			tex.free()

	_threads.clear()
	_results.clear()
	_generated_textures.clear()
