class_name CameraProjector
extends ScreenProjector
## Projects through a Camera3D (the side-on game camera).

var _camera: Camera3D


func _init(camera: Camera3D) -> void:
	_camera = camera


func to_screen(at: Vector3, _size: Vector2) -> Vector2:
	return _camera.unproject_position(at)


func is_behind(at: Vector3) -> bool:
	return _camera.is_position_behind(at)
