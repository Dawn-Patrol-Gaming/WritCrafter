local WC = WritCrafter

local Log = {}
WC.Log = Log

Log.LEVEL_ERROR  = 1
Log.LEVEL_NORMAL = 2
Log.LEVEL_DEBUG  = 3

local PREFIX = "|cE0B060WritCrafter|r: "

local logger

local function Format(fmt, ...)
    if select("#", ...) > 0 then
        return string.format(fmt, ...)
    end
    return tostring(fmt)
end

local function ChatLevel()
    return WC.settings and WC.settings.logLevel or Log.LEVEL_NORMAL
end

local function Chat(message)
    CHAT_ROUTER:AddSystemMessage(PREFIX .. message)
end

function Log.Init()
    if LibDebugLogger then
        logger = LibDebugLogger(WC.name)
    end
end

-- Plain chat output for command replies; always shown.
function Log.Say(fmt, ...)
    Chat(Format(fmt, ...))
end

function Log.Error(fmt, ...)
    local message = Format(fmt, ...)
    if logger then logger:Error(message) end
    Chat("|cFF5050" .. message .. "|r")
end

function Log.Info(fmt, ...)
    local message = Format(fmt, ...)
    if logger then logger:Info(message) end
    if ChatLevel() >= Log.LEVEL_NORMAL then
        Chat(message)
    end
end

function Log.Debug(fmt, ...)
    local message = Format(fmt, ...)
    if logger then logger:Debug(message) end
    if ChatLevel() >= Log.LEVEL_DEBUG then
        Chat("|c999999" .. message .. "|r")
    end
end
