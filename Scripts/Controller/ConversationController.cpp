/* Jenova C++ Node Base Script (Meteora) */

// Godot SDK
#include <Godot/godot.hpp>
#include <Godot/classes/node.hpp>
#include <Godot/variant/variant.hpp>
#include <Godot/variant/array.hpp>
#include <Godot/variant/string.hpp>
#include <Godot/variant/utility_functions.hpp>

// Namespaces
using namespace godot;
using namespace jenova::sdk;

// Self Instance
Node* self = nullptr;

// State tracking
String current_conversation_id = "conversacion_1";
String current_node_id = "nodo_inicio";

// Jenova Script Block Start
JENOVA_SCRIPT_BEGIN

// Funcion that will decide what our player response will make: CHANGE 100% IF NECESSARY
String evaluate_chord(Array played_notes)
{
	// 1. A standard chord requires exactly 3 notes
	if (played_notes.size() < 3) {
		return "incomplete";
	}
	if (played_notes.size() > 3) {
		return "dissonance";
	}

	// 2. Sort the array from lowest to highest pitch (crucial for interval math)
	played_notes.sort();

	// 3. Extract integer values
	int root = played_notes[0];
	int third = played_notes[1];
	int fifth = played_notes[2];

	// 4. Calculate intervals (distance in semitones between the keys)
	int first_interval = third - root;
	int second_interval = fifth - third;

	// 5. Pattern matching based on music theory
	if (first_interval == 4 && second_interval == 3) {
		return "acorde_mayor"; // Major chord (e.g., C-E-G -> 0, 4, 7)
	} 
	else if (first_interval == 3 && second_interval == 4) {
		return "acorde_menor"; // Minor chord (e.g., A-C-E -> 0, 3, 7)
	} 
	else {
		return "disonancia"; // Any other 3-note combination
	}
}

void process_played_notes(Array notes)
{
	String chord_result = evaluate_chord(notes);
	UtilityFunctions::print("Controller: Evaluated chord as -> ", chord_result);

	if (chord_result == "incomplete") {
		return; // Wait for more notes
	}

	// Next step: Call StoryData here with 'chord_result' to fetch dialogue
	// Here we will call the StoryData Singleton to get the next dialogue branch.
	// Example of logic to be implemented:
	// 1. Fetch current node from StoryData.
	// 2. Check if the 'chord_result' exists in 'respuestas_jugador'.
	// 3. Extract the translation text and 'siguiente_nodo'.
	// 4. Update 'current_node_id' and send a signal to PhoneView.gd to print the UI bubble.
}

// Jenova Script Block End
JENOVA_SCRIPT_END
