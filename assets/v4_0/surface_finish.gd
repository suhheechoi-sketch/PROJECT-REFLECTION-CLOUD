extends RefCounted
## Deterministic 64px industrial texture. No external art dependencies.

static func texture(seed_value: int, panel: bool = false) -> ImageTexture:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in range(64):
		for x in range(64):
			var value := 0.78 + random.randf() * 0.18
			if panel and (x < 2 or y < 2):
				value = 0.32
			if panel and x > 5 and x < 9 and y > 5 and y < 9:
				value = 0.5
			if not panel and y % 16 == 0:
				value *= 0.85
			image.set_pixel(x, y, Color(value, value, value))
	return ImageTexture.create_from_image(image)
