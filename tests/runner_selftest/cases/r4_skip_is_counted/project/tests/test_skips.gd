extends TestCase
## A skip is printed and counted, never a silent pass.


func test_waits() -> void:
	skip("waits on purpose")
