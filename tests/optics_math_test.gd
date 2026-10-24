extends SceneTree


func _initialize() -> void:
	var reflected := OpticalMath.reflect(Vector3.RIGHT, Vector3.LEFT)
	assert(reflected.is_equal_approx(Vector3.LEFT), "A plane mirror should reflect the normal component.")

	var incident := Vector3(0.5, 0.0, -sqrt(0.75))
	var refracted := OpticalMath.refract(incident, Vector3.FORWARD, 1.0, 1.5)
	assert(not refracted.is_zero_approx(), "A ray entering a denser medium should refract.")
	assert(absf(refracted.x - 1.0 / 3.0) < 0.001, "Snell's law should produce sin(theta2)=sin(theta1)/1.5.")
	var red_path := OpticalMath.refract(incident, Vector3.FORWARD, 1.0, 1.42)
	var blue_path := OpticalMath.refract(incident, Vector3.FORWARD, 1.0, 1.60)
	assert(absf(red_path.x - blue_path.x) > 0.02, "Different wavelength indices should produce separate prism paths.")

	var total_internal_reflection := OpticalMath.refract(Vector3(0.9, 0.0, 0.43589), Vector3.BACK, 1.5, 1.0)
	assert(total_internal_reflection.is_zero_approx(), "A ray beyond the critical angle should report total internal reflection.")

	print("Optical math checks passed.")
	quit(0)

