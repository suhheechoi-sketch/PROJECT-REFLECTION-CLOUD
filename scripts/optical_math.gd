extends RefCounted
class_name OpticalMath


static func reflect(direction: Vector3, surface_normal: Vector3) -> Vector3:
	# Godot's Vector3.reflect() mirrors through the normal; bounce() is the
	# plane-reflection operation used by physical rays.
	return direction.normalized().bounce(surface_normal.normalized()).normalized()


static func refract(direction: Vector3, surface_normal: Vector3, n1: float, n2: float) -> Vector3:
	var incident := direction.normalized()
	var normal := surface_normal.normalized()
	if incident.dot(normal) > 0.0:
		normal = -normal
	var cosine := clampf(-normal.dot(incident), 0.0, 1.0)
	var ratio := n1 / n2
	var discriminant := 1.0 - ratio * ratio * (1.0 - cosine * cosine)
	if discriminant < 0.0:
		return Vector3.ZERO
	return (ratio * incident + (ratio * cosine - sqrt(discriminant)) * normal).normalized()

