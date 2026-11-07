export type Version = { major: number, minor: number, patch: number }

local function version_to_string(v: Version)
	return `{v.major}.{v.minor}.{v.patch}`
end

local function is_compatible(
	requirement: Version,
	against: Version
): (
	"ok" | "compatible" | "likely_incompatible" | "bad",
	string?
)
	if requirement.major == 0 and against.minor == 0 then
		if requirement.patch == requirement.patch then
			return "ok", nil
		else
			return "likely_incompatible",
				`requires {version_to_string(requirement)}, likely incompatible with {version_to_string(
					against
				)}`
		end
	elseif requirement.major == 0 then
		if requirement.minor > against.minor then
			return "likely_incompatible",
				`requires {version_to_string(requirement)}, likely incompatible with {version_to_string(
					against
				)}`
		elseif requirement.minor == against.minor then
			if requirement.patch <= against.patch then
				return "ok", nil
			elseif requirement.patch > against.patch then
				return "compatible",
					`requires {version_to_string(requirement)}, while likely compatible with {version_to_string(
						against
					)}, API might not function as expected`
			end
		elseif requirement.minor < against.minor then
			return "likely_incompatible",
				`requires {version_to_string(requirement)}, but api is at {version_to_string(
					against
				)}, this may indicate breaking changes`
		end
	else
		if requirement.major ~= against.major then
			return "bad",
				`requires {version_to_string(requirement)}, got {version_to_string(
					against
				)}, there's likely breaking changes`
		elseif requirement.minor > against.minor then
			return "likely_incompatible",
				`requires {version_to_string(requirement)} which may depend on additional api's, which might not be available within {version_to_string(
					against
				)}`
		elseif requirement.minor == against.minor then
			return "ok", nil
		else
			return "compatible",
				`{version_to_string(requirement)} is compatible with {version_to_string(
					against
				)}`
		end
	end

	return "bad",
		`unreachable condition reached {version_to_string(requirement)} {version_to_string(
			against
		)}`
end

return {
	is_compatible = is_compatible,
}
