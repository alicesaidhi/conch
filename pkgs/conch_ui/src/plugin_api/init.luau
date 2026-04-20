--!strict
local RunService = game:GetService "RunService"
--[[
Implements a invokable plugin api, which allows a plugin to communicate with the
provided package.

This additionally implements a miniscule serde layer, as functions need to likely
be transferred between virtual machines.
]]

local folder = require "@self/folder"
local semver = require "@self/semver"

type PluginAPI<T> = {
	version: { major: number, minor: number, patch: number },
	key: string,

	obtain: () -> T,
}

local plugin_api = {}

local function bind_function(
	folder: Instance,
	name: string,
	fn: (...any) -> ...any
)
	local func = folder:FindFirstChild(name)
	if func then
		assert(func:IsA "BindableFunction")
		func.OnInvoke = fn
	else
		local bindable = Instance.new "BindableFunction"
		bindable.OnInvoke = fn
		bindable.Name = name
		bindable.Parent = folder
	end
end

local function bind_event<T...>(
	folder: Instance,
	name: string
): (Signal<T...>, (T...) -> ())
	local event = folder:FindFirstChild(name)

	if event then
		assert(event:IsA "BindableEvent")
		return event.Event, function(...) return event:Fire(...) end
	else
		local bindable = Instance.new "BindableEvent"

		bindable.Name = name
		bindable.Parent = folder

		return bindable.Event, function(...) bindable:Fire(...) end
	end
end

local function index_folder(folder: Instance, key: string): Instance
	local child = folder:FindFirstChild(key)

	if not child then
		local f = Instance.new "Folder"
		f.Name = key
		f.Parent = folder
		return f
	else
		return child
	end
end

export type Signal<T... = ...any> = {
	Wait: (self: Signal<T...>) -> T...,
	Connect: (
		self: Signal<T...>,
		callback: (T...) -> ()
	) -> RBXScriptConnection,
	ConnectParallel: (
		self: Signal<T...>,
		callback: (T...) -> ()
	) -> RBXScriptConnection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> RBXScriptConnection,
}

local UNIQUE_METATABLE = {}
function plugin_api.get_signal<T...>(): (Signal<T...>, (T...) -> ())
	local t: { (T...) -> () } = {}

	local function fire(...: T...)
		for _, event in t do
			event(...)
		end
	end

	return setmetatable(t, UNIQUE_METATABLE) :: any, fire
end

function plugin_api.expose<T>(version: semver.Version, key: string, value: T)
	if RunService:IsStudio() == false then return end
	if typeof(value) ~= "table" then error "can only serialize tables" end

	local plugins_api = folder.obtain_plugins_api(key, version)
	local processed = {}

	local function process(folder: Instance, v: { [string]: any })
		if processed[v] then error "cannot serialize api recursively" end
		processed[v] = true
		local events = index_folder(folder, "events")
		local functions = index_folder(folder, "functions")
		local tables = index_folder(folder, "tables")

		bind_function(folder, "__index", function(key) return v[key] end)

		for key, value in v do
			if
				typeof(value) == "table"
				and getmetatable(value) ~= UNIQUE_METATABLE
			then
				process(index_folder(tables, key), value)
			elseif typeof(value) == "function" then
				bind_function(functions, key, value)
			elseif
				typeof(value) == "table"
				and getmetatable(value) == UNIQUE_METATABLE
			then
				local _, fire = bind_event(events, key)
				table.insert(value, fire)
			end
		end
	end

	process(plugins_api, value)
end

function plugin_api.load<T>(front: {
	folder: Folder,
	version: semver.Version,
	package_ver: semver.Version,
}): T
	if RunService:IsStudio() == false then
		error "cannot load outside of studio"
	end

	local function process(t: { [string]: any }, f: Instance): { [string]: any }
		local events = index_folder(f, "events")
		local functions = index_folder(f, "functions")
		local tables = index_folder(f, "tables")

		for _, bindable in events:GetChildren() do
			assert(bindable:IsA "BindableEvent")
			t[bindable.Name] = bindable.Event
		end

		for _, bindable in functions:GetChildren() do
			assert(bindable:IsA "BindableFunction")
			t[bindable.Name] = function(...) return bindable:Invoke(...) end
		end

		for _, data in tables:GetChildren() do
			t[data.Name] = process({}, data)
		end

		return t
	end

	return process({}, folder)
end

plugin_api.find_plugins_api = folder.find_plugins_api
plugin_api.wait_for_first_api = folder.wait_for_first_api

return plugin_api
