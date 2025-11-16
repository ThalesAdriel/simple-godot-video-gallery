class_name FFMPEG
extends Node

# start/middle/end thumbnails for a video while skipping black/white frames
func createSegmentFrames(ffmpegPath : String, ffprobePath : String, checkFfmpeg : bool, filePath : String, thumbDir : String, fileName : String,  thumbW : int, thumbH : int) -> Dictionary:
	var segments : Dictionary = {"start": [], "middle": [], "end": []}
	if checkFfmpeg == false:
		push_error("No ffmpeg found!")
		return segments

	if !DirAccess.dir_exists_absolute(thumbDir):
		DirAccess.make_dir_recursive_absolute(thumbDir)

	var inputPabs : String = ProjectSettings.globalize_path(filePath)
	var duration : float = getVideoDuration(ffprobePath, inputPabs)
	if duration <= 0.0:
		return segments

	var segmentTimes : Array = [
		[0.0, duration * 0.1, duration * 0.2],
		[duration * 0.4, duration * 0.5, duration * 0.6],
		[duration * 0.8, duration * 0.85, duration * 0.9]
	]

	for segIndex in range(3):
		var lastFramePath : String = ""
		for timeIndex in range(3):
			var timeSec : float = segmentTimes[segIndex][timeIndex]
			var framePath : String = thumbDir.path_join("%s_%s_%d.png" % [fileName, ["start", "middle", "end"][segIndex], timeIndex])
			lastFramePath = framePath
			var outputPabs: String = ProjectSettings.globalize_path(framePath)

			if !FileAccess.file_exists(outputPabs):
				var vfFilter: String = "scale=%d:%d" % [thumbW, thumbH]
				var args : PackedStringArray = [
					"-ss", str(timeSec),
					"-i", inputPabs,
					"-vf", vfFilter,
					"-q:v", "2",
					"-y", outputPabs
				]
				OS.execute(ffmpegPath, args, [], true)

			# Skip black/white frames
			if isBlackWhite(outputPabs):
				continue

			var img : Image = Image.load_from_file(outputPabs)
			var texture := ImageTexture.new()
			texture.update(img)

		if segments[["start", "middle", "end"][segIndex]].is_empty() and lastFramePath != "":
			var fallbackImg: Image = Image.new()
			if fallbackImg.load(ProjectSettings.globalize_path(lastFramePath)) == OK:
				segments[["start", "middle", "end"][segIndex]].append(ImageTexture.create_from_image(fallbackImg))

	return segments

func isBlackWhite(imagePath : String) -> bool:
	var img : Image = Image.new()
	if img.load(imagePath) != OK:
		return true
	
	var blackPixels: int = 0
	var whitePixels: int = 0
	var totalPixels: int = img.get_width() * img.get_height()
	if totalPixels == 0:
		return true
	# works pls
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var color: Color = img.get_pixel(x, y)
			if color.r < 0.05 and color.g < 0.05 and color.b < 0.05:
				blackPixels += 1
			elif color.r > 0.95 and color.g > 0.95 and color.b > 0.95:
				whitePixels += 1

	if float(blackPixels) / totalPixels > 0.9:
		return true
	if float(whitePixels) / totalPixels > 0.9:
		return true

	return false

func getVideoDuration(ffprobePath : String, videoPath : String) -> float:
	if !FileAccess.file_exists(ffprobePath):
		return 0.0

	var args : PackedStringArray = [
		"-v", "error",
		"-show_entries", "format=duration",
		"-of", "default=noprint_wrappers=1:nokey=1",
		videoPath
	]

	var output : Array = []
	var exitCode : int = OS.execute(ffprobePath, args, output, true)
	if exitCode == 0 && output.size() > 0:
		return float(output[0])

	return 0.0
