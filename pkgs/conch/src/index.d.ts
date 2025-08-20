import type { AnalysisArgument, AnalysisResult } from "@rbxts/conch-language"

export type Type<T = unknown> = {
	readonly __brand_Type: T,
};
export type TypeCtor<T = unknown> = (name?: string, description?: string) => Type<T>;

type InferType<T extends Type> = T extends Type<infer U> ? U : never;
type InferTypes<T extends Type[]> = {
	[K in keyof T]: InferType<T[K]>;
};

export type VarargType<T extends unknown[] = unknown[]> = {
	readonly __brand_VarargType: T;
}
// 💜 TypeScript
type InferVarargType<T extends VarargType> = T extends VarargType<[...infer U]> ? [...U] : never;

type Overload = { description: string, arguments: Type[] }
export type OverloadType<T extends Overload[] = Overload[]> = {
	readonly __brand_OverloadType: T;
}

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
 * Executes the given text.
 * 
 * @description Outputs an error into the console if it's not enabled.
 */
export function execute(src: string): void;
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
		permissions: string[],
		arguments: () => LuaTuple<[...T, V]>,
		callback: (...arguments: [...InferTypes<T>, ...InferVarargType<V>]) => unknown,
	}
): void;
/**
 * Registers a new command.
 * 
 * @description Registers a given command with the provided description. This command is only visible to players who have the required permissions.
 */
export function register<const T extends Type[]>(
	name: string,
	props: {
		description?: string,
		permissions: string[],
		arguments: () => LuaTuple<T>,
		callback: (...arguments: InferTypes<T>) => unknown,
	}
): void;
/**
 * Registers a new command.
 * 
 * @description Registers a given command with the provided description. This command is only visible to players who have the required permissions.
 */
export function register<const T extends VarargType>(
	name: string,
	props: {
		description?: string,
		permissions: string[],
		arguments: () => T,
		callback: (...arguments: InferVarargType<T>) => unknown,
	}
): void;
/**
 * Registers a new command.
 * 
 * @description Registers a given command with the provided description. This command is only visible to players who have the required permissions.
 */
export function register<const T extends Type>(
	name: string,
	props: {
		description?: string,
		permissions: string[],
		arguments: () => T,
		callback: (argument: InferType<T>) => unknown,
	}
): void;
/**
 * Registers a new command.
 * 
 * @description Registers a given command with the provided description. This command is only visible to players who have the required permissions.
 */
export function register<const T extends OverloadType>(
	name: string,
	props: {
		description?: string,
		permissions: string[],
		arguments: () => T,
		callback: (...arguments: T extends OverloadType<infer O> ? InferTypes<O[number]['arguments']> : never) => unknown,
	}
): void;
/**
 * Registers the `license`, `print`, `info`, `warn` and `error` commands.
 */
export function register_default_commands(): void;
/**
 * Initiates the default lifecycle, automatically creating a user for every player and connecting to network events.
 */
export function initiate_default_lifecycle(): void;
/**
 * Registers a type which can be replicated.
 * 
 * @description Types must be registered on both the server and client before the command using them is registered.
 */
export function register_type<T>(
	type: string,
	data: {
		converts: (from: unknown) => T,
		analysis: AnalysisArgument
	}
): TypeCtor<T>;
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
 */
export function get_command_context(): CommandContext;
/**
 * Logs to the user using this command.
 * 
 * @description This automatically logs to the user running the command.
 */
export function log(
	kind: "warn" | "info" | "error" | "normal",
	text: string,
): void;
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
 * Calls the given function whenever a player executes something.
 */
export function on_execution(
	fn: (player: Player, src: string) => void
): () => void;

export namespace args {
	export function overload<const T extends Overload[]>(overloads: T): OverloadType<T>;
	export function literal<const T>(literal: T, name?: string, description?: string): Type<T>;

	export const any: TypeCtor<any>;
	export const string: TypeCtor<string>;
	export const strings: TypeCtor<string[]>;
	export const number: TypeCtor<number>;
	export const numbers: TypeCtor<number[]>;
	export const boolean: TypeCtor<boolean>;
	export const booleans: TypeCtor<boolean[]>;
	export const table: TypeCtor<Record<string | number, unknown>>;
	export const vector: TypeCtor<vector>;
	export const vectors: TypeCtor<vector[]>;
	export const player: TypeCtor<Player>;
	export const players: TypeCtor<Player[]>;

	export const userid: TypeCtor<number>;
	export const userids: TypeCtor<number[]>;

	export const color: TypeCtor<Color3>;
	export const colors: TypeCtor<Color3[]>;

	export const duration: TypeCtor<number>;

	export const userinput: TypeCtor<Enum.UserInputType>;

	export function variadic<const T>(type: Type<T>): VarargType<T[]>;
	export function optional<const T>(type: Type<T>): Type<T | undefined>;
	export const opt: typeof optional;

	export function enum_new<const T extends unknown[]>(options: T, name?: string, description?: string): Type<T[number]>;
	export function enum_map<const V>(map: Record<string, V>, name?: string, description?: string): Type<V>;
}
