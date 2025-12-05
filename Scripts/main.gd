extends CanvasLayer

const VIDEO_EXTS : Array = [".mp4", ".avi", ".mov", ".mkv", ".webm"]
const THUMB_DIR : String = "user://cache"
const THUMB_SIZE : Vector2 = Vector2(200, 120)
const LAST_PATH_FILE : String = "res://lastPathData.txt"
const PREVIEW_FRAME_INTERVAL: float = 0.15

@onready var ffmpegUtils : FFMPEG = preload("res://Scripts/ffmpegUtils.gd").new()
@onready var buttonAppearAnimation : AppearAnimation = preload("res://Scripts/appearAnimation.gd").new()

@onready var openFolder : AnimatedButton = %OpenFolder
@onready var openLastFolder : AnimatedButton = %openLastFolder
@onready var clearCache : AnimatedButton = %clearCache
@onready var checkAllFiles : AnimatedButton = %checkAllFiles
@onready var configurations : AnimatedButton = %Configurations

@onready var checkForBlackFrames: AnimatedCheckBox = %CheckForBlackFrames

@onready var gridGallery : GridContainer = %GridGallery

@onready var showFileNames : AnimatedCheckBox = %showFileNames
@onready var buttons : Array = %appearAnimation.getAllButtons(self)

@onready var configWindow : Popup = %ConfigWindow

var ffmpegPath : String = "/usr/bin/ffmpeg"
var ffprobePath : String = "/usr/bin/ffprobe"
var checkFfmpeg : bool = false
var showFilesNames : bool = true
var lastFolderPath : String = ""
var fallbackThumbnail : String = ""
var trucateAt : int = 15

func _ready() -> void:
	configWindow.visible = false
	buttons.sort_custom(Callable(buttonAppearAnimation, "buttonsArraySorting"))
	%appearAnimation.animateButtons(buttons.duplicate(), true)

	var userDir : DirAccess = DirAccess.open("user://")
	if userDir && !userDir.dir_exists("cache"):
		userDir.make_dir_recursive("cache")

	openFolder.pressed.connect(openFolderF)
	openLastFolder.pressed.connect(openLastFolderF)
	clearCache.pressed.connect(clearCacheF)
	checkAllFiles.pressed.connect(checkAllFilesF)
	showFileNames.toggled.connect(func(pressed): showFilesNames = pressed; updateVisibility())
	configurations.pressed.connect(showConfigWindow)
	
func openFolderF():
	print(verifyBinExistence())
	var systemDialogue : FileDialog = FileDialog.new()
	systemDialogue.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	systemDialogue.access = FileDialog.ACCESS_FILESYSTEM
	systemDialogue.use_native_dialog = true
	systemDialogue.connect("dir_selected", Callable(self, "_onDirSelected"))
	add_child(systemDialogue)
	systemDialogue.popup_centered_ratio()

func loadFolderFiles(folderPath : String):
	lastFolderPath = folderPath
	
	var file : Object = FileAccess.open(LAST_PATH_FILE, FileAccess.WRITE)
	if file:
		file.store_line(folderPath)
		file.close()

	queueFreeChildren(gridGallery)

	var dir : Object = DirAccess.open(folderPath)
	if dir:
		dir.list_dir_begin()
		var fileName : String = dir.get_next()
		while fileName != "":
			if !dir.current_is_dir():
				var fullPath : String = folderPath.path_join(fileName)
				var fileExtension : String = "." + fileName.get_extension().to_lower()
				if fileExtension in VIDEO_EXTS:
					addGalleryItem(fullPath)
			fileName = dir.get_next()

func _onDirSelected(path : String):
	loadFolderFiles(path)

func openLastFolderF():
	if lastFolderPath != "":
		loadFolderFiles(lastFolderPath)

func clearCacheF():
	var thumbsDir : String = ProjectSettings.globalize_path(THUMB_DIR)
	if DirAccess.dir_exists_absolute(thumbsDir):
		OS.move_to_trash(thumbsDir)
		queueFreeChildren(gridGallery)

func checkAllFilesF():
	var dir : Object = DirAccess.open(lastFolderPath)
	if dir:
		dir.list_dir_begin()
		var fileName : String = dir.get_next()
		while fileName != "":
			if !dir.current_is_dir():
				var fullPath : String = lastFolderPath.path_join(fileName)
				addGalleryItem(fullPath)
			fileName = dir.get_next()

func truncateNames(fileName : String, maxLength : int) -> String:
	return fileName.substr(0, maxLength) + "..." if fileName.length() > maxLength else fileName

func showConfigWindow():
	configWindow.visible = true
	

func addGalleryItem(filePath : String):
	if !gridGallery:
		return

	var container : VBoxContainer = VBoxContainer.new()
	container.custom_minimum_size = THUMB_SIZE

	checkFfmpeg = verifyBinExistence()
	var segmentFrames : Dictionary = ffmpegUtils.createSegmentFrames(ffmpegPath, ffprobePath, checkFfmpeg, filePath, THUMB_DIR, filePath.get_file(), int(THUMB_SIZE.x), int(THUMB_SIZE.y), checkForBlackFrames.toggle_mode)

	var thumbnailTexture : Texture2D = ImageTexture.new()
	if segmentFrames.has("start") && segmentFrames["start"].size() > 0:
		thumbnailTexture = segmentFrames["start"][0]
	else:
		var img : Image = Image.new()
		var thumbnailPath : String = THUMB_DIR.path_join(filePath.get_file() + ".png")
		if img.load(thumbnailPath) == OK:
			thumbnailTexture = ImageTexture.create_from_image(img)
	
	var thumbnail : TextureRect = TextureRect.new()
	thumbnail.name = "thumbnail"
	thumbnail.texture = thumbnailTexture
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	thumbnail.size_flags_horizontal = Control.SIZE_FILL
	thumbnail.size_flags_vertical = thumbnail.size_flags_horizontal
	thumbnail.custom_minimum_size = THUMB_SIZE
	var thumbnailBorderRadius : ShaderMaterial = ShaderMaterial.new()
	thumbnailBorderRadius.shader = preload("res://Assets/Shaders/radius.gdshader")
	thumbnail.material = thumbnailBorderRadius
	thumbnail.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.add_child(thumbnail)
	var thumbnailName : Label = Label.new()
	thumbnailName.name = "thumbnailName"
	thumbnailName.text = truncateNames(filePath.get_file(), trucateAt)
	thumbnailName.visible = showFilesNames
	container.add_child(thumbnailName)
	#thumbnailName.scale
	var data : Dictionary = {
		"segmentFrames": [segmentFrames["start"], segmentFrames["middle"], segmentFrames["end"]],
		"currentSeg": 0,
		"thumbnailTexture": thumbnailTexture,
		"videoPath": filePath
	}

	thumbnail.gui_input.connect(func(event): _onThumbInput(event, data, thumbnail))
	container.mouse_entered.connect(func(): _onThumbHover(thumbnail, data))
	container.mouse_exited.connect(func(): _onThumbNotHover(thumbnail, data))
	gridGallery.add_child(container)

func verifyBinExistence() -> bool:
	if FileAccess.file_exists(ffmpegPath):
		return true

	return false

func _onThumbHover(thumbnail : TextureRect, data : Dictionary):
	var frames : Array = data["segmentFrames"][0] as Array
	if frames.is_empty():
		return

	var frameIndex : int = 0
	var timer : Timer = Timer.new()
	timer.wait_time = PREVIEW_FRAME_INTERVAL
	timer.one_shot = false
	timer.autostart = true
	timer.timeout.connect(func():
		frameIndex = (frameIndex + 1) % frames.size()
		if is_instance_valid(thumbnail):
			thumbnail.texture = frames[frameIndex]
	)

func _onThumbNotHover(thumbnail : TextureRect, data : Dictionary):
	if data.has("timer") && is_instance_valid(data["timer"]):
		data["timer"].queue_free()
	thumbnail.texture = data["thumbnailTexture"]

func _onThumbInput(event : InputEvent, data : Dictionary, thumbnail : TextureRect):
	if event is InputEventMouseMotion:
		var posX : float = event.position.x
		var third : float = THUMB_SIZE.x / 3.0 
		var segIndex : int = int(clamp(floor(posX / third), 0, 2))

		if segIndex != data.get("currentSeg", -1):
			data["currentSeg"] = segIndex
			var frames : Array = data.get("segmentFrames", []) [segIndex] as Array
			if frames.size() > 0:
				var frameIndex : int = 0
				var timer : Timer = Timer.new()
				timer.wait_time = PREVIEW_FRAME_INTERVAL
				timer.one_shot = false
				timer.autostart = true
				timer.timeout.connect(func():
					frameIndex = (frameIndex + 1) % frames.size()
					if is_instance_valid(thumbnail):
						thumbnail.texture = frames[frameIndex]
				)
				add_child(timer)
				if data.has("timer") && is_instance_valid(data["timer"]):
					data["timer"].queue_free()
				data["timer"] = timer
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if data.has("videoPath"):
			var pathToOpen := ProjectSettings.globalize_path(data["videoPath"])
			OS.shell_open(pathToOpen)

func updateVisibility():
	if gridGallery:
		for c in gridGallery.get_children():
			var label = c.get_node_or_null("thumbnailName")
			if label:
				label.visible = showFilesNames

func queueFreeChildren(node: Node):
	if node:
		for c in node.get_children():
			c.queue_free()
