extends RefCounted
## Compiles, because the annotation silences the error. The lint must still fail it.

@warning_ignore("untyped_declaration")
var level = 1
