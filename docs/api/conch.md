---
previous: false
next: false
---

# conch

Package available through wally under `alicesaidhi/conch` or on pesde as `alicesaidhi/conch`.

## Functions

### execute()

Executes the given text

- **Type**

    ```luau
    function conch.execute<T>(src: string)~
    ```

- **Details**

    Outputs an error into the console if it's not enabled.

### register_quick()

Quickly registers a command by only having to pass a function

- **Type**

    ```luau
    function conch.register_quick(
        name: string,
        fn: (...any) -> (...any),
		...: Permission
    )
    ```

- **Details**

    This doesn't add any analysis of any sort. This should only be reserved for temporary commands.

### register()

Registers a new command.

- **Type**

    ```luau
    function conch.register(
		name: string,
		props: {
			description: string?,
			permissions: { Permission },
			arguments: () -> T...,
			callback: (T...) -> (...any),
		}
	)
    ```

- **Details**

    Registers a given command with the provided description. This command is only visible to players who have the required permissions.

### register_default_commands()

Registers the `license`, `print`, `info`, `warn` and `error` commands.

- **Type**

    ```luau
    function conch.register_default_commands()
    ```

### initiate_default_lifecycle()

Initiates the default lifecycle, automatically creating a user for every player and connecting to network events.

- **Type**

    ```luau
    function conch.initiate_default_lifecycle()
    ```

### register_type()

Registers a type which can be replicated

- **Type**

    ```luau
    function conch.register_type<T>(
		type: string,
		data: {
			convert: (any) -> T,
			analysis: AnalysisCommandArgument | AnalysisCommandVariadic
		}
	): (name: string?, description: string?) -> T
    ```

- **Details**

    Types must be registered on both the server and client before the command using them is registered.

### has_permissions()

Returns if the user has the required permissions to use a command.

- **Type**

	```luau
	function conch.has_permissions(user: User, ...: string): boolean
	```

- **Details**

	Returns true if the user either has all the permissions required or if the user has the `super-user` role.

### set_role_permissions()

Sets the permissions associated with a role.

- **Type**

	```luau
	function conch.set_role_permissions(role: string, ...: string)
	```

- **Details**

	This overwrites the existing permissions of a role. You should only run this when you are initializing the server.

### give_roles()

Gives the user the given tuple of roles.

- **Type**

	```luau
	function conch.give_roles(user: User, ...: string)
	```

- **Details**

	Giving the user the `super-user` role gives them access to every command. This should only be reserved for players that are extremely trusted.

### remove_roles()

Removes the tuple of roles from the user.

- **Type**
	
	```luau
	function conch.remove_roles(user: User, ...: string)
	```

### get_user()

Returns or creates a user for the given key or player.

- **Type**

	```luau
	function conch.get_user(key: string | Player)
	```

### set_var()

Sets a global variable on the command.

- **Type**

	```luau
	function conch.set_var(global: string, value: unknown)
	```

- **Details**

	All globals must be valid identifiers. It should only include alphanumeric values, dashes and underscores.

### get_command_context()

Returns a command context which contains information about the executor.

- **Type**

	```luau
	function conch.get_command_context(): CommandContext
	```

### log()

Logs to the user using this command.

- **Type**

	```luau
	function conch.log(
		kind: "warn" | "info" | "error" | "normal",
		text: string
	)
	```

- **Details**

	This automatically logs to the user running the command.

### analyze()

Analyzes the given source and returns information about the given source code and gives suggestions for that position.

- **Type**

	```luau
	function conch.analyze(src: string, where: number): AnalysisInformation
	```

### on_command_run()

Calls the given function to whenever a command runs that is registered by the host. On the server, it only gets called for commands registered by the server.

- **Type**

	```luau
	function conch.on_command_run(fn: (ctx: {
		ok: boolean,
		who: User,
		command: string,
		arguments: { unknown },
		result: { unknown }
	}) -> ()): () -> ()
	```

### on_execution()

Calls the given function whenever a player executes something.

- **Type**

	```luau
	function conch.on_execution(fn: (player: Player, src: string) -> ()): () -> ()
	```

