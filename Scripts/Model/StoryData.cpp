/* Jenova C++ Node Base Script (Meteora) */

// Godot SDK
#include <Godot/godot.hpp>
#include <Godot/classes/node.hpp>
#include <Godot/variant/variant.hpp>
#include <Godot/variant/dictionary.hpp>
#include <Godot/variant/string.hpp>
#include <Godot/classes/file_access.hpp>
#include <Godot/classes/json.hpp>
#include <Godot/variant/utility_functions.hpp>

// Namespaces
using namespace godot;
using namespace jenova::sdk;

// Self Instance
Node* self = nullptr;

// Global Dictionary to store the JSON data
Dictionary story_database;

JENOVA_SCRIPT_BEGIN

bool load_json(String file_path)
{
	//1. We try to open the file, get the text and close it
	Ref<FileAccess> file = FileAccess::open(file_path, FileAccess::READ); 
	
	if (file.is_null()) {
		UtilityFunctions::print("StoryData Error: Could not open ", file_path);
		return false;
	}

	String content = file->get_as_text();
	file->close();
	
	//2. We get the data on json
	Ref<JSON> json = memnew(JSON);
	Error error = json->parse(content);

	if (error == OK) {
		story_database = json->get_data(); //If its okey, we save it in our dictionary
		UtilityFunctions::print("StoryData: JSON successfully loaded.");
		return true;
	} else {
		UtilityFunctions::print("StoryData Error: Failed to parse JSON.");
		return false;
	}
}

Dictionary get_dialogue_node(String conversation_id, String node_id)
{
	//We get the dialogue with the conversation id and the especific node
	if (story_database.has(conversation_id)) {
		Dictionary conversation = story_database[conversation_id];
		if (conversation.has(node_id)) {
			return conversation[node_id];
		}
	}
	
	UtilityFunctions::print("StoryData Warning: Node not found -> ", node_id);
	return Dictionary(); // Returns an empty dictionary if the node is missing
}

// Jenova Script Block End
JENOVA_SCRIPT_END
