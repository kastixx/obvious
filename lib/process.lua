local setmetatable = setmetatable
local pairs = pairs
local ipairs = ipairs
local pcall = pcall

local awful = require("awful")

module("obvious.lib.process")

-- some code was taken from here:
-- http://awesome.naquadah.org/wiki/Autostart#The_native_lua_way

local check_state, err = pcall(function()
  -- stupid test for /proc availability:
  -- check if init's cmdline exists
  local file_to_check = '/proc/1/cmdline'
  if not os.rename(file_to_check, file_to_check) then
    error("/proc filesystem seems to be absent")
  end

  -- now try loading LuaFileSystem
  local lfs = require('lfs')

  -- if the above line didn't raise an error,
  -- then we have both /proc and LFS, so just
  -- return the LFS instance

  return lfs
end)

local function escape_regexp(string)
  return string:gsub("[-+?*]", {
    ["+"]  = "%+", ["-"] = "%-",
    ["*"]  = "%*", ["?"]  = "%?",
  })
end

local processCache = {}

function processCache:find(process)
  local process_escaped = escape_regexp(process)

  for i, p in ipairs(self._cache) do
    if p:find(process_escaped) then
      return nil
    end
  end

  return true
end

if check_state then
  local lfs = err

  local function read_cmdline(pid)
    if tonumber(pid) ~= nil then
      local f, err = io.open("/proc/" .. pid .. "/cmdline")
      if f then
        local cmdline = f:read("*all")
        f:close()
        if cmdline ~= "" then
          return cmdline
        end
      end
    end
  end

  function processCache:init()
    local cache = {}
    self._cache = cache

    for dir in lfs.dir("/proc") do
      local cmdline = read_cmdline(dir)
      if cmdline then
          table.insert(cache, cmdline)
      end
    end

    return self
  end

  function find_process(process)
    local process_escaped = escape_regexp(process)

    local function yield_process()
      for dir in lfs.dir('/proc') do
        local cmdline = read_cmdline(dir)
        if cmdline then
            coroutine.yield(cmdline)
        end
      end
    end

    for cmdline in coroutine.wrap(yield_process) do
      if cmdline:find(process_escaped) then
        return cmdline
      end
    end
  end

else
  function processCache:init()
    local cache = {}
    self._cache = cache

    fd = io.popen("ps -ewwo args")
    if not fd then return self end

    for line in fd:lines() do
      table.insert(cache, line)
    end
    
    return self
  end

  function find_process(process)
    local process_escaped = escape_regexp(process)

    local fd = io.popen('ps -ewwo args')
    if not fd then
      return
    end

    local cmdline = nil

    for l in fd:lines() do
      if l:find(process_escaped) then
        cmdline = l
        break
      end
    end

    fd:close()
    return cmdline
  end
end

-- vim:ft=lua:ts=2:sw=2:sts=2:tw=80:et
