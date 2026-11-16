# MOTIF📱🎶

> ⚠️ **PROJECT STATUS: PROTOTYPE / PROOF OF CONCEPT (NOT FULLY PLAYABLE) ⚠️**
> *Please note that this repository contains a technical proof of concept. The game is currently in the early development phase and is not a fully playable experience. The code, UI, and systems provided represent the foundational architecture for the emotional puzzle mechanics.*

**MOTIF** is a UI-based psychological narrative puzzle game where you communicate not by choosing text options, but by playing emotional chords on a 6-key digital piano. 

Set entirely inside a smartphone interface at 5:00 AM, the protagonist returns home drunk after a rough night out. Unable to sleep, they must face the different fragmented voices in their head—represented as individual WhatsApp contacts—and process the grief of a past relationship by decoding the musical subtext of their own thoughts.

<img width="1280" height="720" alt="Video Project 9 (5)" src="https://github.com/user-attachments/assets/6bef1eed-44e5-4233-8d96-d355f2a65e5f" />


## 🛠️ Technologies
- **Godot Engine 4.6**
- **GDScript**
- **Dialogue Manager** (Godot Addon)
- **GitHub**

---

## 💡 Core Mechanics

### 1. The Emotional Keyboard

The player answers messages using a 6-note keyboard. Instead of musical notes, the keys map to spatial and emotional weight:
*   **Left [0, 1] (Gravity / Darkness):** Represents heavy emotions, rejection, walls, and pain.
*   **Center [2, 3] (Calm / Transition):** Represents breathing, introspection, and neutrality.
*   **Right [4, 5] (Light / Bridge):** Represents affirmation, joy, and warmth.

By playing combinations (chords), the player creates complex emotions. A dense cluster on the left `[0,1,2]` sounds like a toxic mockery, while a heavy base with a single high note `[0,1,5]` sounds like isolation or a suppressed cry.

### 2. Dynamic UI Color Synthesis
Visual feedback is tied directly to the audio. When the player or an NPC presses a combination of keys, the game calculates the additive RGB light of those specific notes, normalizes the brightest channel to prevent muddy grays, and lerps it with white to create a soft, pastel UI aesthetic. Every emotion dynamically tints the chat bubbles in real-time.

### 3. Psychological Puzzles
The gameplay loop consists of 5 layers of emotional deduction:
*   **Introspection:** Ignoring angry inner voices to comfort the sad ones.
*   **Telegraphing (The Draft System):** The protagonist automatically types what they *want* to say in gray text; the player must figure out the correct emotional chord to give the message color and the courage to hit send.
*   **Subtext & Lies:** Reading old chat histories to realize that a text saying "Haha, I'm fine" was actually tinted with a heavy, isolated chord (`[0,1,5]`).
*   **Emotional Combos:** Holding and sliding across the keyboard to transition from grief to acceptance to finally put the phone down and sleep.


<img width="1280" height="720" alt="Video Project 9 (6)" src="https://github.com/user-attachments/assets/70226564-c957-4e62-af8e-0eb578aa3eb6" />

---

## ⚙️ Architecture & Systems

The codebase is structured around a clean separation between UI presentation and dialogue logic, connected through a global Event Bus.

*   **`GameEvents.gd` (Event Bus):** A Singleton that mediates all communication. It receives signals from the Dialogue Manager to unlock new chats, show the keyboard, or wait for a specific musical response, preventing tight coupling between the narrative scripts and the UI nodes.
*   **`AppChat.gd` & `chat_saves`:** A persistent multi-thread system. Since the player is fighting multiple inner voices at once, they can freely switch between active chats. The system saves the `next_id` of the dialogue tree, ensuring no conversation loses its place.
*   **Dynamic Tweens & Game Feel:** Every key press triggers independent Tweens (`PianoView.gd`) that smoothly blend the keyboard's colors into the target chord. Chat bubbles feature spring-based spawn animations, hold-to-charge mechanics, and custom `RichTextEffects` (like static glitches) for narrative emphasis.
*   **Dialogue Manager Integration:** The narrative branches rely heavily on yielding the dialogue loop (`await app_chat.line_finished` and `GameEvents.wait_response()`), halting the text parser seamlessly until the player inputs the correct emotional chord.

---

## 🚀 Current State & Installation

*Currently, this repository contains the UI layout, the dynamic color/math logic, the dialogue tree parser, and the foundational event architecture. It serves as a testing ground for the core game feel.*

**To run the prototype:**
1. Clone the repository.
2. Open the project folder using **Godot 4.6**.
3. Ensure the **Dialogue Manager** plugin is enabled in `Project -> Project Settings -> Plugins`.
4. Run the main scene (`Scenes/Main.tscn`). 

*(Note: Audio assets and sound effects may be missing due to licensing restrictions. The visual feedback and dialogue logic will still function).*
