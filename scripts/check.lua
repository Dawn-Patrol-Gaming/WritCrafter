-- Offline checks for the addon, run with LuaJIT (Lua 5.1 syntax, like the game's own Lua):
--   luajit scripts/check.lua        (from the repo root)
--
-- 1. Every file in the manifest exists, and every .lua file is in the manifest.
-- 2. Every .lua file compiles (the same syntax errors the game would stop at).
-- 3. No accidental globals: only WritCrafter may be assigned at global scope (a missing `local`
--    leaks into every other addon).
--
-- It doesn't run the code, so it can't catch wrong game API calls or logic errors.

local ALLOWED_GLOBALS = { WritCrafter = true }
local SKIP_DIRS = { [".git"] = true, docs = true, scripts = true, tests = true, [".claude"] = true }

local luajit = arg[-1] or "luajit"
local problems = 0

local function Problem(fmt, ...)
    problems = problems + 1
    print(string.format(fmt, ...))
end

local function Exists(path)
    local file = io.open(path, "rb")
    if file then
        file:close()
        return true
    end
    return false
end

-- Manifest entries, in load order.
local manifest, listed = {}, {}
for line in io.lines("WritCrafter.addon") do
    line = line:gsub("%s+$", "")
    if line ~= "" and not line:match("^##") and not line:match("^;") then
        local path = line:gsub("\\", "/")
        manifest[#manifest + 1] = path
        listed[path:lower()] = true
        if not Exists(path) then
            Problem("manifest: %s doesn't exist", path)
        end
    end
end

-- Every .lua file in the repo (outside the skipped folders).
local files = {}
local pipe = io.popen('dir /s /b *.lua 2>nul')
local root = io.popen("cd"):read("*l"):gsub("\\", "/")
for full in pipe:lines() do
    local path = full:gsub("\\", "/"):sub(#root + 2)
    local top = path:match("^([^/]+)/")
    if not (top and SKIP_DIRS[top]) then
        files[#files + 1] = path
        if not listed[path:lower()] then
            Problem("manifest: %s isn't listed, so the game never loads it", path)
        end
    end
end
pipe:close()
table.sort(files)

-- Compile, then look for global assignments in the bytecode listing.
for _, path in ipairs(files) do
    local ok, err = loadfile(path)
    if not ok then
        Problem("syntax: %s", err)
    else
        local listing = io.popen('""' .. luajit .. '" -bl "' .. path .. '""')
        local func = "?"
        for line in listing:lines() do
            local header = line:match("^%-%- BYTECODE %-%- (%S+)")
            if header then
                func = header
            end
            local name = line:match("GSET%s+%d+%s+%d+%s+; \"([^\"]+)\"")
            if name and not ALLOWED_GLOBALS[name] then
                Problem("global: %s assigns global '%s' (function at %s); missing `local`?", path, name, func)
            end
        end
        listing:close()
    end
end

print(string.format("%d files checked, %d manifest entries, %d problem(s)", #files, #manifest, problems))
os.exit(problems == 0 and 0 or 1)
