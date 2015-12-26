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

if check_state then
  local lfs = err

  function iterate_processes(process)
    local process_escaped = escape_regexp(process)

    local function yield_process()
      for dir in lfs.dir('/proc') do
        if tonumber(pid) ~= nil then
          local f, err = io.open("/proc/" .. pid .. "/cmdline")
          if f then
            local cmdline = f:read("*all")
            f:close()
            if cmdline ~= "" then
              coroutine.yield(cmdline)
            end
          end
        end
      end
    end

    return coroutine.wrap(yield_process)
  end

else

  function iterate_processes()
    fd = io.popen("ps -ewwo args")
    if fd then
      return fd:lines()
    end

    -- return an empty function in case of failure
    return function () end
  end

end

local processCache = {}

function processCache:init()
  local cache = {}
  self._cache = cache
  
  for cmdline in iterate_processes() do
    table.insert(cache, cmdline)
  end

  return self
end

function find_process(process)
  for cmdline in iterate_processes() do
    if cmdline:find(process) then
      return cmdline
    end
  end
end

function processCache:find(process)
  local process_escaped = escape_regexp(process)

  for i, p in ipairs(self._cache) do
    if p:find(process_escaped) then
      return nil
    end
  end

  return true
end

function processCache:run_once(process, cmd)
  if not self:find(process) then
    return awful.util.spawn_with_shell(cmd or process)
  end
end

function run_once(process, cmd)
  if not find_process(process) then
    return awful.util.spawn_with_shell(cmd or process)
  end
end

function get_process_cache()
  return processCache:init()
end

-- vim:ft=lua:ts=2:sw=2:sts=2:tw=80:et
