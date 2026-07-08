---
previous: false
next: false
---

# conch

Package available through wally under `alicesaidhi/conch` or on pesde as `alicesaidhi/conch`.

## Properties

### version

Stores the version of conch as a string in a SemVer format.

- **Type**

    ```luau
    conch.version: string
    ```

### args

Provides access to the built-in arguments API of conch.

## Functions

### get_strange_type

Obtains a strange type given a id. Returns it if registered on the executing environment. Strange types must be registered on both the server and client to properly replicate.

- **Type**

    ```luau
    function conch.get_strange_type(id: string): language.StrangeType
    ```

### register_strange_type

Registers a strange type to a given id. This allows it to be replicated over the server-client boundary and provides argument autocompletion to the UI.

Strange types are a mechanism to support obtaining values in conch that do not normally exist within conch as a language.

- **Type**

    ```luau
    function conch.register_strange_type<T>(props: {
        -- this name will be shown in the UI.
        type: string,
        -- this is what the strange type is registered as.
        id: string,
        -- an optional convert function, which allows converting an input
        -- type into an output before performing a command call.
        convert: ((unknown)) -> (T),
        -- provides a list of suggestions to the UI. if set to a type, uses the
        -- type to provide suggestions to the UI.
        suggestions: (language.Type | ((string) -> { language.Suggestion }))?,
        -- match is used by the analysis to determine if a type could match an
        -- overload. if it can potentially match the type, return true.
        match: (language.Type | (unknown) -> boolean)?,
        -- exact_match is used by conch to determine if a value exactly matches
        -- a type and is used in determining which overload to run, or how to
        -- convert the type.
        exact_match: (language.Type | (unknown) -> boolean)?
    }): language.StrangeType
    ```

### pluralize_type

Automatically converts a strange type into a plural version and registers it.

- **Type**

    ```luau
    function conch.pluralize<T>(
        type: language.StrangeType,
        additional: {
            -- provides a list of suggestions to the UI. if set to a type, uses
            -- the type to provide suggestions to the UI.
            suggestions: language.Type | ((unknown) -> { language.Suggestion })?,
            -- match is used by the analysis to determine if a type could match
            -- an overload. if it can potentially match the type, return true.
            match: language.Type | ((unknown) -> boolean)?,
            -- exact_match is used by conch to determine if a value exactly 
            -- matches a type and is used in determining which overload to run, 
            -- or how to convert the type.
            exact_match: language.Type | ((unknown) -> boolean)?,
            -- an optional convert function, which allows converting an input
            -- type into an output before performing a command call.
            convert: ((unknown) -> T)?,
        }
    ): language.Type
    ```

- **Details**

The plural type returns a union if the `additional` value is provided.

### wrap_type

Wraps the type into a command argument and returns a function to generate an argument for said type.

- **Type**

    ```luau
    function conch.wrap_type<T>(type: language.Type?, name: string?, description: string?): TypeRegistrator<T>
    ```

### execute()

Executes the given text.

- **Type**

    ```luau
    function conch.execute(src: string)~
    ```

- **Details**

    Outputs an error into the console if no local user exists to execute src as.

### cancel()

Cancels the execution of a command.

- **Type**

    ```luau
    function conch.cancel()
    ```

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

Registers the `license`, `print`, `info`, `warn` and `error` commands on the client.

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

- **Details**

    When saved to a variable like this:

    ```luau
    local context = conch.get_command_context()
    ```

   it returns:

    ```luau
    context.invocation_id -- The invocation ID of the command.
    context.executor: { -- Information about the player who executed it:
        player: Player -- The player who executed the command.
        id: string -- The player's internal ID as a string. prefer using player.UserId
        name: string
        roles: { string }
    }
    ```

    For example, we can use this to print the player's UserId:

    ```luau
    conch.register("userid", {
        description = "Prints your UserId",
        permissions = {},
        arguments = function() end,
        callback = function()
            local ctx = conch.get_command_context()
            local id = ctx.executor.player.UserId
        
            conch.log("normal", "Your player ID is " .. id)
        end
    })
    ```

 - **Details**

    When saved to a variable like this:
	```luau
	local context = conch.get_command_context()
	```
   it returns:
	```luau
	context.invocation_id -- The invocation ID of the command.
	context.executor -- Information about the player who executed it:
		player -- The player who executed the command.
		id -- The player's ID as a string, unreliable, use player.UserId to get ID.
   		name -- The player's name.
   		dirty -- A boolean whether the player is dirty or not.
   		roles -- An array of the player's roles.
   		disconnected -- A boolean whether the player is disconnected or not.
 	```

 	For example, we can use this to print the player's ID:
	```luau
 	conch.register("userid", {
 	description = "Prints your UserId",
 	permissions = {},
 	arguments = function() end,
 	callback = function()
 
	local ctx = conch.get_command_context()
 	local id = ctx.executor.player.UserId
 
	conch.log("normal", "Your player ID is " .. id)
 	end
	})
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

    When used on the server, if a command context exists it automatically logs to the user within said context. On the client, this always logs to the local_user.

### log_to()

Logs to a player.

- **Type**

    ```luau
    function conch.log_to(
        player: Player,
        kind: "warn" | "info" | "error" | "normal",
        text: string
    )
    ```

- **Details**

    This fires a RemoteEvent on the server. If your concern is about bloating the queue, consider creating a UnreliableRemoteEvent to tell the client to log instead.

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

Calls the given function whenever a player executes something using conch. Please beware that this can be bypassed by exploiters.

- **Type**

    ```luau
    function conch.on_execution(callback: (Player: Player, src: string) -> ())
    ```
