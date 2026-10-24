extends RefCounted
## Shared visible-camera ray for aim and device picking, including interpolation.
static func ray(camera: Camera3D, pixel: Vector2) -> Dictionary:
	var size := camera.get_viewport().get_visible_rect().size
	var ndc := Vector2(pixel.x * 2.0 / size.x - 1.0, 1.0 - pixel.y * 2.0 / size.y)
	var inverse := camera.get_camera_projection().inverse()
	var near_point := inverse * Vector4(ndc.x, ndc.y, -1, 1)
	var far_point := inverse * Vector4(ndc.x, ndc.y, 1, 1)
	var a := Vector3(near_point.x, near_point.y, near_point.z) / near_point.w
	var b := Vector3(far_point.x, far_point.y, far_point.z) / far_point.w
	var pose := camera.get_global_transform_interpolated()
	return {"origin": pose * a, "direction": (pose.basis * (b - a)).normalized()}

static func screen_position(camera: Camera3D, point: Vector3) -> Vector2:
	var local := camera.get_global_transform_interpolated().affine_inverse() * point
	var projected := camera.get_camera_projection() * Vector4(local.x, local.y, local.z, 1)
	var size := camera.get_viewport().get_visible_rect().size
	return Vector2((projected.x / projected.w + 1.0) * size.x * 0.5, (1.0 - projected.y / projected.w) * size.y * 0.5)
