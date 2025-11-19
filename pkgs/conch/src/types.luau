local language = require "../roblox_packages/language"

export type ArgumentType<T> = {
	convert: ((any) -> T)?,
	analysis: language.AnalysisArgument?,
}

export type User = {
	read id: string,
	read name: string,
	read player: Player | false,

	disconnected: boolean,
	dirty: boolean,
	roles: { string },
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
	who: User,
	command: string,
	arguments: { unknown },
	result: { unknown },
}

export type Overload = {
	read kind: "overload",

	overloads: { language.Overload },
}

export type CommandRepresentation = {
	read name: string,
	read description: string?,
	read permissions: { string },
	read callback: (...any) -> ...any,

	read information: language.Metadata,

	dirty_replicate: boolean,
}

export type Console = {
	read vm: language.LanguageVm,
	read commands: { [string]: CommandRepresentation },
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
