import type Vide from "@rbxts/vide";
import type * as Conch from "@rbxts/conch";

type Palette = {
	name: string,
	rosewater: Color3,
	flamingo: Color3,
	pink: Color3,
	mauve: Color3,
	red: Color3,
	maroon: Color3,
	peach: Color3,
	yellow: Color3,
	green: Color3,
	teal: Color3,
	sky: Color3,
	sapphire: Color3,
	blue: Color3,
	lavender: Color3,
	text: Color3,
	subtext1: Color3,
	subtext0: Color3,
	overlay2: Color3,
	overlay1: Color3,
	overlay0: Color3,
	surface2: Color3,
	surface1: Color3,
	surface0: Color3,
	base: Color3,
	mantle: Color3,
	crust: Color3,
};

/**
 * Binds the activation of Conch to a given user input or keycode. This automatically mounts the UI if it has not yet been mounted.
 */
export function bind_to(input: Enum.KeyCode | Enum.UserInputType): void;
/**
 * Opens Conch when one of the given aliases is sent in chat. This automatically mounts the UI if it has not yet been mounted.
 */
export function bind_to_chat(primary: string, secondary?: string): void;
/**
 * Returns the command history, most recent first.
 */
export function get_history(): string[];
/**
 * Replaces the command history, for example with one saved through on_history_changed.
 */
export function set_history(history: string[]): void;
/**
 * Calls the callback with the history whenever it changes. Returns a function that disconnects it.
 */
export function on_history_changed(callback: (history: string[]) => void): () => void;
/**
 * Mounts the UI to the PlayerGui.
 */
export function mount(): void;
/**
 * A vide source that stores if the UI is enabled or not. When called with a boolean, sets it to that boolean. Otherwise, returns the currently stored boolean.
 */
export declare const opened: Vide.Source<boolean>
/**
 * A vide source that stores if the textbox is focused. When called with a boolean, focuses or unfocuses it.
 */
export declare const focused: Vide.Source<boolean>
/**
 * A vide source that stores if the mouse is unlocked while the UI is open. Defaults to true. Set it to false if your game manages the mouse itself.
 */
export declare const unlock_mouse: Vide.Source<boolean>
/**
 * A vide source that stores if the input is at the bottom or the top of the screen. Defaults to bottom.
 */
export declare const alignment: Vide.Source<"bottom" | "top">
/**
 * The theme of the UI. `selected` is a vide source holding the palette, which can be set to another catppuccin flavor or a custom palette.
 */
export declare const theme: {
	readonly catpuccin: {
		readonly frappe: Palette,
		readonly latte: Palette,
		readonly macchiato: Palette,
		readonly moccha: Palette,
	},
	readonly selected: Vide.Source<Palette>,
	readonly select_color: (key: Exclude<keyof Palette, "name">) => () => Color3,

	readonly ansi_pallete: Readonly<Record<number, Color3>>,

	readonly background: () => Color3,
	readonly background_transparency: Vide.Source<number>,

	readonly text: () => Color3,
	readonly text_error: () => Color3,
	readonly text_info: () => Color3,
	readonly text_warn: () => Color3,
	readonly text_success: () => Color3,
	readonly font: Vide.Source<Font>,
}
/**
 * The conch package the UI uses.
 */
export declare const conch: typeof Conch
/**
 * Refers to the UI component for the Conch UI.
 */
export function app(): ScreenGui;