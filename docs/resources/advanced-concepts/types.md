# Built-in types

By default, all available types for arguments in conch are under `conch.args`.

Here's the current list of available types:

| Type Name | Data Type | Type Name | Data Type     | Can implicitly cast               |
| --------- | --------- | --------- | ------------- | --------------------------------- |
| string    | `string`  | strings   | `{ string }`  | any tostringable type             |
| number    | `number`  | numbers   | `{ number }`  |                                   |
| boolean   | `boolean` | booleans  | `{ boolean }` | `number`                          |
| table     | `{}`      |           |               |                                   |
| vector    | `vector`  | vectors   | `{ vector }`  | `{ number }`,                     |
| player    | `Player`  | players   | `{ Player }`  | `string`, `@a` (all players), `@s` (yourself), player |
| userinput | `Enum.UserInputType` |			|				| `string` |
| userid | `number` | userids | `{ number }` | `Player`, `string`, `@a`, `@s`, `number` |
| duration | `number` |  | | `string`, `number` |
| color3 | `Color3` |  | | `number`, `vector` |

## Variadic Types

All types can be made variadic by using `conch.args.variadic`.

## Custom types

Conch is technically a full-on language, so types beyond the ones that are built-in have to be implicitly cast into that type. In order to do this, you can use `conch.register_type` to register new exotic types. These types need tbe registered both by the client and server before `initiate_default_lifecycle` and returns a function which can be used to add that type within commands.

### Enums

A common example of when you want to register a type is enums. Conch provides a built-in utility within `conch.args` for this called `enum_new` and `enum_map`. These allow for quickly creating a new type for an enum, like items. `enum_new` takes in an array of possible options, while `enum_map` takes in a map of possible keys and their associated value.

Let's start with a basic example where we want to register a type for our items. Let's say our items are stored inside a table like this:

```lua
return {

	health_potion = {
		name = "Health Potion",
		description = "+10 HP"
	},

	swiftness_potion = {
		name = "Swiftness Potion",
		description = "+4 Speed"
	}

}
```

We want to register an enum for each possible item so that we can get autocomplete for our `give-item` command. We can do this easily with `enum_new` to give the user a list of valid options to choose from.

```lua
local itemname = conch.register_type(
	"item-name", -- A unique identifier for the type that is the same on both server and client
	conch.args.enum_new({ "health_potion", "swiftness_potion" }) -- enum_new generates a new value that we can pass into our register_type.
)

conch.initiate_default_lifecycle()
```

We can then use this to implement our `give-item` command!

```lua
local function give_item(who: Player, item_name: keyof<Items>)
	local inventory = inventories[who]
	local item = items[item_name]

	local copy = table.clone(item)
	table.insert(inventory, copy)
end

conch.register("give-item", {
	description = "Gives a specific item to the specified player.",
	permissions = { "give-item" },
	arguments = function() return
		conch.args.player("to", "The player to give the item to"),
		args.itemname("name", "The name of the item to give")
	end,

	callback = give_item
})
```

We can make this even easier by using the `enum_map` command, which would cast the given string into the desired type. In layman's terms, key goes in, associated value goes out.

```lua
local item = conch.register_type(
	"item", -- A unique identifier for the type that is the same on both server and client
	conch.args.enum_map(items) -- enum_map generates a new value that we can pass into our register_type.
)
```


```lua
local function give_item(who: Player, item: valueof<Items>)
	local inventory = inventories[who]

	local copy = table.clone(item)
	table.insert(inventory, copy)
end

conch.register("give-item", {
	description = "Gives a specific item to the specified player.",
	permissions = { "give-item" },
	arguments = function() return
		conch.args.player("to", "The player to give the item to"),
		args.item("item", "The item to give")
	end,

	callback = give_item
})
```

### Complex Custom Types

> [!WARNING]
> This feature is considered unstable and may be subject to changes in future versions.

Write more complicated types and suggestions by taking advantage of Conch's analysis features. This allows developers to feed data directly into the analysis system and/or write their own implicit converts.

```luau
export type AnalysisCommandArgument = {
	kind: "argument",
	name: string,
	description: string?,
	type: string?,
	suggestion_generator: ((text: string) -> { string })?,
}
```

```lua
conch.register_type("custom", {
	convert = function(value: unknown) -- this function handles implicit converts. it converts the given value into another value and is only fed into the function.
		return "new value!"
	end,

	analysis = {
		kind = "argument", -- keep it as argument.
		name = "custom-type", -- the default type for the data
		type = "Player", -- the type that is displayed in the suggestions ui
		suggestion_generator = function(text: string)
			return {
				"suggestion-1",
				"suggestion-2"
			}
		end -- returns a list of suggestions based on the given text
	} -- this is fed into the analysis
})