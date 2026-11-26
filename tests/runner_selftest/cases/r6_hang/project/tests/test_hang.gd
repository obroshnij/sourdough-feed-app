extends TestCase
## A hang (R-9). Only the outer alarm can stop it. --quit-after would exit 0 here.


func test_never_ends() -> void:
	check(true, "this check passes")
	var spins: int = 0
	while spins >= 0:
		spins = (spins + 1) % 1000
