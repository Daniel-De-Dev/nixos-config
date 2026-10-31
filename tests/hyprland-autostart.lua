-- Exercise startup through the real Lua API: creating a dispatcher is not exec.
local start
local commands = {}
hl = {
  on = function(event, callback)
    assert(event == 'hyprland.start', 'Unexpected startup event: ' .. event)
    assert(not start, 'Register startup once')
    start = callback
  end,
  exec_cmd = function(command) commands[#commands + 1] = command end,
}

dofile(assert(arg[1]))
assert(start, 'Startup callback was not registered')
assert(#commands == 0, 'Do not spawn processes while parsing the configuration')

start()

-- Execute each independent launch, including a failed finalization.
local log = os.tmpname()
local mock = os.tmpname()
local function quote(value) return '\'' .. value:gsub('\'', '\'\\\'\'') .. '\'' end
local script = assert(io.open(mock, 'w'))
script:write(
  'printf "%s\\n" "$1" >> ' .. quote(log) .. '\n',
  'if [ "$1" = uwsm ]; then\n',
  '  [ "$2" = finalize ] || exit 2\n',
  '  exit "${FINALIZE_STATUS:-0}"\n',
  'elif [ "$1" = hyprctl ]; then\n',
  '  [ "$2" = setcursor ] || exit 2\n',
  'fi\n'
)
script:close()
local function reset_log()
  local file = assert(io.open(log, 'w'))
  file:close()
end
local function read_log()
  local file = assert(io.open(log, 'r'))
  local value = file:read('*a')
  file:close()
  return value
end
local function success(status) return status == true or status == 0 end

local function run(finalize_status)
  reset_log()
  local failures = 0
  for _, command in ipairs(commands) do
    local expanded = command:gsub('@([%w]+)@', function(name)
      if name == 'uwsm' or name == 'hyprctl' then
        return 'sh ' .. quote(mock) .. ' ' .. name
      end
      return 'test'
    end)
    local command_line = 'FINALIZE_STATUS='
      .. finalize_status
      .. ' '
      .. expanded
    local status = os.execute(command_line)
    if not success(status) then failures = failures + 1 end
  end
  return failures, read_log()
end

local failures, calls = run(0)
assert(failures == 0, 'Initialization failed')
assert(calls == 'uwsm\nhyprctl\n', 'Finalize the session and apply the cursor')
failures, calls = run(1)
assert(failures == 1, 'Finalization failure was not exercised')
assert(
  calls == 'uwsm\nhyprctl\n',
  'Cursor setup must be independent of finalization'
)
os.remove(mock)
os.remove(log)
print('Hyprland startup callback and independent cursor setup passed')
