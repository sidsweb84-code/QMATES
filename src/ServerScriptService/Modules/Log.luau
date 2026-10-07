--[[
	Log
	Central server logging. Keeps an in-memory ring buffer that admins can read
	with /logs, prints to the output, and persists Security/Admin entries to a
	DataStore in batches (see LoggingService in ServerMain for the flush loop).
]]

local Log = {}

export type Entry = {
	Time: number,
	Category: string,
	Level: string,
	Message: string,
	UserId: number?,
}

Log.MaxEntries = 600
Log.Entries = {} :: { Entry }
Log.PendingPersist = {} :: { Entry }
Log.PersistCategories = { Security = true, Admin = true, Economy = false, Data = true, Purchase = true }
Log.Verbose = false

local function push(entry: Entry)
	table.insert(Log.Entries, entry)
	if #Log.Entries > Log.MaxEntries then
		table.remove(Log.Entries, 1)
	end
	if Log.PersistCategories[entry.Category] then
		table.insert(Log.PendingPersist, entry)
		if #Log.PendingPersist > 500 then
			table.remove(Log.PendingPersist, 1)
		end
	end
end

local function format(entry: Entry): string
	return string.format("[%s][%s]%s %s", entry.Category, entry.Level,
		entry.UserId and (" <" .. tostring(entry.UserId) .. ">") or "", entry.Message)
end

function Log.Info(category: string, message: string, userId: number?)
	local entry = { Time = os.time(), Category = category, Level = "INFO", Message = message, UserId = userId }
	push(entry)
	if Log.Verbose then
		print(format(entry))
	end
end

function Log.Warn(category: string, message: string, userId: number?)
	local entry = { Time = os.time(), Category = category, Level = "WARN", Message = message, UserId = userId }
	push(entry)
	warn(format(entry))
end

function Log.Error(category: string, message: string, userId: number?)
	local entry = { Time = os.time(), Category = category, Level = "ERROR", Message = message, UserId = userId }
	push(entry)
	warn(format(entry))
end

function Log.Security(message: string, userId: number?)
	Log.Warn("Security", message, userId)
end

function Log.Recent(count: number, category: string?): { string }
	local lines = {}
	for i = #Log.Entries, 1, -1 do
		local entry = Log.Entries[i]
		if category == nil or string.lower(entry.Category) == string.lower(category) then
			table.insert(lines, os.date("!%H:%M:%S", entry.Time) .. " " .. format(entry))
			if #lines >= count then
				break
			end
		end
	end
	return lines
end

function Log.TakePending(): { Entry }
	local pending = Log.PendingPersist
	Log.PendingPersist = {}
	return pending
end

return Log
