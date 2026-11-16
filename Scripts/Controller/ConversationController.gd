extends Node

# Validates if the submitted notes match the expected emotional recipe.
# Order does not matter: a chord is the set of keys held together.
func validate_response(played_notes: Array, expected_notes: Array) -> bool:
	var played = played_notes.duplicate()
	var expected = expected_notes.duplicate()
	played.sort()
	expected.sort()
	return played == expected

func process_played_notes(notes: Array, expected_notes: Array) -> bool:
	print("Controller: Received charged chord -> ", notes)

	if validate_response(notes, expected_notes):
		print("Controller: CORRECT!")
		return true

	print("Controller: INCORRECT.")
	return false
