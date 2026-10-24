-- Exercise the actual generated Lua without starting a compositor.
local bindings = {}
local next_id = 0
local dispatcher = {}
setmetatable(dispatcher, {
  __index = function() return dispatcher end,
  __call = function() return {} end,
})
hl = setmetatable({
  dsp = dispatcher,
  bind = function(keys, _, flags)
    local description = flags.description:gsub(' %b[]$', '')
    bindings[description] = keys
    next_id = next_id + 1
    return {
      arg = next_id,
      enabled = true,
      submap = '',
      description = flags.description,
    }
  end,
}, {
  __index = function()
    return function() return {} end
  end,
})

dofile(arg[1])
local modifier = assert(arg[2])
for _, description in ipairs({
  'Applications: Open terminal',
  'Applications: Open browser',
  'Applications: Open file manager',
  'Windows: Switch window',
  'Help: Search keyboard shortcuts',
  'Applications: Open application launcher',
  'Preview: Close desktop',
}) do
  assert(
    assert(bindings[description], description):match(
      '^' .. modifier .. ' %s*%+'
    ),
    description
  )
end
for description, keys in pairs(bindings) do
  assert(not description:match('^Session:'), description)
  assert(not description:match('^Audio:'), description)
  assert(not description:match('^Media:'), description)
  assert(not description:match('brightness$'), description)
  assert(not description:match('^Capture: Record'), description)
  if modifier == 'ALT' then assert(not keys:find('SUPER', 1, true), keys) end
end
print(
  'Preview application/AGS modifiers and host-control exclusions passed: '
    .. modifier
)
