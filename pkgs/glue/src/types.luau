local types = require "../luau_packages/types"

export type Type = {
	kind: "varargs" | "arg",
	type: string,
	name: string,
	description: string,
}

export type User = {
	read id: string,
	read name: string,
	read player: Player | false,

	disconnected: boolean,
	dirty: boolean,
	roles: { string },
}

export type UserPublic = {
	read id: string,
	read name: string,
	read player: Player | false,

	read disconnected: boolean,
	read roles: { string },
	read dirty: boolean,
}

export type Log = {
	read kind: "normal" | "info" | "warn" | "error",
	read text: string,
}

export type CommandContext = {
	read executor: User,
	read invocation_id: number | false,
}

export type AfterCommandRunContext = {
	ok: boolean,
	command: string,
	arguments: { unknown },
	result: { unknown },
}

export type CommandRepresentation = {
	read name: string,
	read permissions: { string },
	read callback: (...any) -> ...any,
	read type_info: types.AnalysisCommand,
	read arguments: { Type },

	dirty_replicate: boolean,
}

export type Console = {
	read vm: types.VirtualMachine,
	read commands: { CommandRepresentation },
	output: (Log) -> (),
}

export type Connection = {
	read callback: (...any) -> ...any,
	read disconnect: (any) -> (),
	disconnected: boolean,
}

export type ConnectionPublic = {
	read callback: (...any) -> ...any,
	read disconnect: (any) -> (),
	read disconnected: boolean,
}

export type Signal<T...> = {
	read fire: (any, T...) -> (),
	read connect: (any, (T...) -> ()) -> Connection,
}

export type SignalPublic<T...> = {
	read connect: (any, (T...) -> ()) -> Connection,
}

export type Result = { type: "ok", results: unknown } | { type: "err" }

export type Role = string
export type Permission = string

return {}
