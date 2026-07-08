---
previous: false
next: false
---

# ui

Package available through wally under `alicesaidhi/conch-ui` or on pesde as `alicesaidhi/conch_ui`.

## Properties

### theme

Provides access to the theme.

- **Type**

    ```luau
    {
        catpuccin: { ["frappe" | "latte" | "macchiato" | "moccha"]: Theme },
        selected: vide.Source<Theme>,
        select_color: (key: "base" | "blue" | "crust" | "flamingo" | "green" | "lavender" | "mantle" | "maroon" | "mauve" | "name" | "overlay0" | "overlay1" | "overlay2" | "peach" | "pink" | "red" | "rosewater" | "sapphire" | "sky" | "subtext0" | "subtext1" | "surface0" | "surface1" | "surface2" | "teal" | "text" | "yellow"): () -> Color3,

        ansi_palette: { [number]: Color3 },

        background: () -> Color3,
        background_transparency: vide.Source<number>,

        text: () -> Color3,
        text_error: () -> Color3,
        text_info: () -> Color3,
        text_warn: () -> Color3,
        text_success: () -> Color3,

        font: vide.Source<Font>
    }

    type Theme = {
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
    }
    ```

- **Details**

    Refrain from modifying the font, as we rely on the font being both monospace and a certain size. Modifying the ansi palette should only have effect on future colors, and not on any old ansi codes.

## Functions

### bind_to()

Binds the activation of Conch to a given user input or keycode.
This automatically mounts the UI if it has not yet been mounted.

- **Type**

    ```luau
    function ui.bind_to(input: Enum.KeyCode | Enum.UserInputType)
    ```

### mount()

Mounts the UI to the PlayerGui.

- **Type**

    ```luau
    function ui.mount()
    ```

### opened()

A vide source that stores if the UI is enabled or not. When called with a boolean, sets it to that boolean. Otherwise, returns the currently stored boolean.

- **Type**

    ```luau
    function ui.opened(new: boolean): boolean
    function ui.opened(): boolean
    ```

### app()

Refers to the UI component for the Conch UI.

- **Type**

    ```luau
    function ui.app()
    ```

### alignment()

A vide source that stores whether the UI is located at the top or bottom.

- **Type**

    ```luau
    function ui.alignment(new: "top" | "bottom"): "top" | "bottom"
    function ui.alignment(): "top" | "bottom"
    ```

### focused()

A vide source which determines whether the user is currently focused on the UI.
