extends TestCase
## Positive control: a nested test file is discovered, and a test may await a frame.


func test_awaits_a_frame() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	await tree.process_frame
	check(tree != null, "awaited one frame")
