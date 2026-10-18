import type {
	AnalysisResult,
	LanguageVm,
	StrangeType,
	Suggestion,
	Type as LanguageType,
} from "@rbxts/conch-language"

export type Type<T = unknown> = {
	readonly __brand_Type: T,
};
export type TypeCtor<T = unknown> = (name?: string, description?: string) => Type<T>;

type InferType<T extends Type> = T extends Type<infer U> ? U : never;
type InferTypes<T extends Type[]> = {
	[K in keyof T]: InferType<T[K]>;
};
type UnionToIntersection<U> = (U extends unknown ? (arg: U) => void : never) extends (arg: infer I) => void ? I : never;

export type VarargType<T extends unknown[] = unknown[]> = {
	readonly __brand_VarargType: T;
}
// 💜 TypeScript
type InferVarargType<T extends VarargType> = T extends VarargType<[...infer U]> ? [...U] : never;

type Overload = Type[]
export type OverloadType<T extends Overload[] = Overload[]> = {
	readonly __brand_OverloadType: T;
}

type StrangeTypeData<T> = {
	type: string,
	id: string,
	convert?: (value: unknown) => T,
	suggestions?: LanguageType | ((text: string) => Suggestion[]),
	match?: LanguageType | ((value: unknown) => boolean),
	exact_match?: LanguageType | ((value: unknown) => boolean),
}

export type Log = {
	readonly kind: "normal" | "info" | "warn" | "error" | "success",
	readonly text: string,
};

export type CommandRepresentation = {
	readonly name: string,
	readonly description?: string,
	readonly permissions: string[],
	readonly aliases: string[],
	readonly cooldown?: number,
	readonly callback: (...args: any[]) => unknown,
	readonly type: LanguageType,
	dirty_replicate: boolean,
};

export type Console = {
	readonly vm: LanguageVm,
	readonly commands: Record<string, CommandRepresentation>,
	output: (log: Log) => void,
};

export type User = {
	id: string,
	name: string,
	player: Player | false,

	disconnected: boolean,
	dirty: boolean,
	roles: string[],
};

export type CommandContext = {
	executor: User,
	invocation_id: number | false,
};

/**
 * Runs before the callback of the command it is given to, after the before_run hooks. Returning a string blocks the command and shows the string to the executor as an error.
 */
export type Guard = (ctx: {
	who: User,
	command: string,
	arguments: unknown[],
}) => string | undefined;

/**
 * The version of conch.
 */
export const version: string;
/**
 * Executes the given text.
 * 
 * @description Outputs an error into the console if it's not enabled.
 */
export function execute(src: string): void;
/**
 * Cancels the command that is currently running, if there is one.
 */
export function cancel(): void;
/**
 * Quickly registers a command by only having to pass a function.
 * 
 * @description This doesn't add any analysis of any sort. This should only be reserved for temporary commands.
 */
export function register_quick(name: string, fn: (...args: any[]) => unknown, ...permissions: string[]): void;
/**
 * Registers a new command.
 * 
 * @description Registers a given command with the provided description. This command is only visible to players who have the required permissions.
 */
export function register<const T extends Type[], const V extends VarargType>(
	name: string,
	props: {
		description?: string,
		aliases?: string[],
		guards?: Guard[],
		cooldown?: number,
		permissions: string[],
		arguments: () => LuaTuple<[...T, V]>,
		callback: (...arguments: [...InferTypes<T>, ...InferVarargType<V>]) => unknown,
	}
): CommandRepresentation;
/**
 * Registers a new command.
 * 
 * @description Registers a given command with the provided description. This command is only visible to players who have the required permissions.
 */
export function register<const T extends Type[]>(
	name: string,
	props: {
		description?: string,
		aliases?: string[],
		guards?: Guard[],
		cooldown?: number,
		permissions: string[],
		arguments: () => LuaTuple<T>,
		callback: (...arguments: InferTypes<T>) => unknown,
	}
): CommandRepresentation;
/**
 * Registers a new command.
 * 
 * @description Registers a given command with the provided description. This command is only visible to players who have the required permissions.
 */
export function register<const T extends VarargType>(
	name: string,
	props: {
		description?: string,
		aliases?: string[],
		guards?: Guard[],
		cooldown?: number,
		permissions: string[],
		arguments: () => T,
		callback: (...arguments: InferVarargType<T>) => unknown,
	}
): CommandRepresentation;
/**
 * Registers a new command.
 * 
 * @description Registers a given command with the provided description. This command is only visible to players who have the required permissions.
 */
export function register<const T extends Type>(
	name: string,
	props: {
		description?: string,
		aliases?: string[],
		guards?: Guard[],
		cooldown?: number,
		permissions: string[],
		arguments: () => T,
		callback: (argument: InferType<T>) => unknown,
	}
): CommandRepresentation;
/**
 * Registers a new command.
 * 
 * @description Registers a given command with the provided description. This command is only visible to players who have the required permissions.
 */
export function register<const T extends OverloadType>(
	name: string,
	props: {
		description?: string,
		aliases?: string[],
		guards?: Guard[],
		cooldown?: number,
		permissions: string[],
		arguments: () => T,
		callback: (...arguments: T extends OverloadType<infer O> ? InferTypes<O[number]> : never) => unknown,
	}
): CommandRepresentation;
/**
 * Unregisters a command.
 *
 * @description Removes the command and its aliases. When called on the server, the command is removed from every client as well.
 */
export function unregister(name: string): void;
/**
 * Registers the `print`, `sleep`, `set`, `info`, `warn` and `error` commands on the client.
 * 
 * @description The `license` command is always registered on the client, even without calling this.
 */
export function register_default_commands(): void;
/**
 * Initiates the default lifecycle, automatically creating a user for every player and connecting to network events.
 */
export function initiate_default_lifecycle(): void;
/**
 * Registers a strange type, which is a type that conch does not support by itself.
 * 
 * @description Strange types must be registered on both the server and client with the same id before the command using them is registered. `convert` does not replicate, so a command converts its arguments where it is registered. Use `wrap_type` to turn it into an argument.
 */
export function register_strange_type<T>(data: StrangeTypeData<T>): StrangeType & Type<T>;
/**
 * Returns the strange type registered with the given id.
 */
export function get_strange_type(id: string): StrangeType | undefined;
/**
 * Turns a type into a function that creates arguments of that type, like the ones in `args`.
 * 
 * @description The name defaults to one generated from the type.
 */
export function wrap_type<T = unknown>(type: (LanguageType & Type<T>) | LanguageType | undefined, name?: string, description?: string): TypeCtor<T>;
/**
 * Creates the plural form of a strange type, which accepts either a single value or a table of them.
 * 
 * @description The additional data is a second strange type that is accepted as well, like `@a` for players.
 */
export function pluralize_type<T = unknown>(
	type: StrangeType,
	additional?: Omit<StrangeTypeData<T[]>, "type" | "id">,
): LanguageType & Type<T[]>;
/**
 * Returns if the user has the required permissions to use a command.
 * 
 * @description Returns true if the user either has all the permissions required or if the user has the super-user role.
 */
export function has_permissions(user: User, ...permissions: string[]): boolean;
/**
 * Sets the permissions associated with a role.
 * 
 * @description This overwrites the existing permissions of a role. You should only run this when you are initializing the server.
 */
export function set_role_permissions(role: string, ...permissions: string[]): void;
/**
 * Sets the limits on what clients can send to the server. Every limit is off until it is set, and calling this again replaces all of them.
 * 
 * @description `max_input_length` drops longer text before it reaches on_execution. `max_invokes_per_second` limits how many server commands each user can run per second. Per-command limits go in the `cooldown` field of `register`, in seconds per user.
 */
export function set_limits(limits: {
	max_input_length?: number,
	max_invokes_per_second?: number,
}): void;
/**
 * Gives the user the given tuple of roles.
 * 
 * @description Giving the user the `super-user` role gives them access to every command. This should only be reserved for players that are extremely trusted.
 */
export function give_roles(user: User, ...roles: string[]): void;
/**
 * Removes the tuple of roles from the user.
 */
export function remove_roles(user: User, ...roles: string[]): void;
/**
 * Returns or creates a user for the given key or player.
 */
export function get_user(key: string | Player): User;
/**
 * Sets a global variable on the command.
 * 
 * @description All globals must be valid identifiers. It should only include alphanumeric values, dashes and underscores.
 */
export function set_var(global: string, value: unknown): void;
/**
 * Returns a command context which contains information about the executor.
 * 
 * @description Returns undefined outside of the thread a command runs in.
 */
export function get_command_context(): CommandContext | undefined;
/**
 * Logs to the user using this command.
 * 
 * @description This automatically logs to the user running the command. On the server, nothing is logged outside of the thread the command runs in.
 */
export function log(
	kind: Log["kind"],
	text: string,
): void;
/**
 * Logs to the given player.
 * 
 * @description On the client, this only logs when the player is the local player.
 */
export function log_to(
	player: Player,
	kind: Log["kind"],
	text: string,
): void;
/**
 * The console of this host, which holds the vm, the registered commands and the function used to output logs.
 */
export const console: Console;
/**
 * Analyzes the given source and returns information about the given source code and gives suggestions for that position.
 */
export function analyze(src: string, where: number): AnalysisResult;
/**
 * Calls the given function to whenever a command runs that is registered by the host. On the server, it only gets called for commands registered by the server.
 */
export function on_command_run(
	fn: (ctx: {
		ok: boolean,
		who: User,
		command: string,
		arguments: unknown[],
		result: unknown[]
	}) => void
): () => void;
/**
 * Calls the given function before a command registered by the host runs, after the permission check and argument conversion. Returning a string blocks the command and shows the string to the executor as an error.
 * 
 * @description On the server, it only gets called for commands registered by the server. Blocked commands do not reach on_command_run.
 */
export function before_run(
	fn: (ctx: {
		who: User,
		command: string,
		arguments: unknown[]
	}) => string | undefined
): () => void;
/**
 * Calls the given function whenever a player executes something.
 */
export function on_execution(
	fn: (player: Player, src: string) => void
): () => void;

export namespace args {
	/**
	 * Lets a command take one of several argument lists. Exactly one of them must match the given arguments, so give them a different `literal` as the first argument when they would overlap.
	 */
	export function overload<const T extends Overload[]>(overloads: T): OverloadType<T>;
	/**
	 * A type that only matches the exact value.
	 */
	export function literal<const T extends string | number | boolean | undefined>(value: T): Type<T>;

	export const any: TypeCtor<any>;
	export const string: TypeCtor<string>;
	export const strings: TypeCtor<string[]>;
	export const number: TypeCtor<number>;
	export const numbers: TypeCtor<number[]>;
	export const boolean: TypeCtor<boolean>;
	export const booleans: TypeCtor<boolean[]>;
	export const vector: TypeCtor<vector>;
	export const vectors: TypeCtor<vector[]>;
	export const player: TypeCtor<Player>;
	export const players: TypeCtor<Player[]>;

	export const userid: TypeCtor<number>;
	export const userids: TypeCtor<number[]>;

	export const color: TypeCtor<Color3>;
	export const colors: TypeCtor<Color3[]>;

	export const duration: TypeCtor<number>;

	/**
	 * Lets the argument take any amount of values. Only the last argument can be variadic.
	 */
	export function variadic<const T>(type: Type<T>): VarargType<T[]>;
	/**
	 * Lets the argument be left out, in which case it is undefined.
	 */
	export function opt<const T>(type: Type<T>): Type<T | undefined>;

	/**
	 * Creates an enum type from an array. The values are matched by themselves or by their string form.
	 *
	 * @description The id must be the same on the server and the client.
	 */
	export function enum_from_array<const T extends readonly unknown[]>(id: string, options: T, name?: string, description?: string): TypeCtor<T[number]>;
	/**
	 * Creates an enum type from a map, where the keys are typed and converted to their values.
	 *
	 * @description The id must be the same on the server and the client.
	 */
	export function enum_from_map<const V>(id: string, map: ReadonlyMap<string, V> | { readonly [key: string]: V }, name?: string, description?: string): TypeCtor<V>;
	/**
	 * Creates an enum type from a function that returns the options every time they are needed, so they can change while the game runs.
	 *
	 * @description The id must be the same on the server and the client.
	 */
	export function dynamic<V>(id: string, options: () => ReadonlyMap<unknown, V> | { readonly [key: string]: V }, name?: string, description?: string): TypeCtor<V>;
	/**
	 * Creates an enum type from an array of literals. Unlike `enum_from_array`, it replicates with the command and does not need to be registered on the client.
	 */
	export function static_enum_from_array<const T extends readonly (string | number | boolean)[]>(options: T, name?: string, description?: string): TypeCtor<T[number]>;

	/**
	 * A table type with the given fields, and optionally a type for the other keys and their values.
	 */
	export function struct<const T extends { readonly [key: string]: Type }>(fields: T): Type<{ [K in keyof T]: InferType<T[K]> }>;
	export function struct<const T extends { readonly [key: string]: Type }, K extends string | number, V>(fields: T, indexer: Type<K>, value: Type<V>): Type<{ [F in keyof T]: InferType<T[F]> } & Record<K, V>>;

	/**
	 * A type that matches any of the given types.
	 */
	export function union<const T extends Type[]>(...types: T): Type<InferType<T[number]>>;
	/**
	 * A type that matches all of the given types.
	 */
	export function intersect<const T extends Type[]>(...types: T): Type<UnionToIntersection<InferType<T[number]>>>;
}
