-- Minimal standalone helpers.
--
-- This config began life as an Omarchy overlay, where these functions came from
-- /usr/share/omarchy/default/hypr/helpers.lua. They are inlined here so the
-- config runs on a plain Arch install with no Omarchy packages present.

o = o or {}

function o.shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function file_exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

function o.cmd_present(command)
  if command:find("/", 1, true) then
    return file_exists(command)
  end

  local path = os.getenv("PATH") or "/usr/local/bin:/usr/bin"
  for directory in (path .. ":"):gmatch("([^:]*):") do
    local dir = directory ~= "" and directory or "."
    if file_exists(dir .. "/" .. command) then
      return true
    end
  end

  return false
end

-- Launch through uwsm when it is installed (it imports the systemd session
-- environment); otherwise run the command directly so a missing uwsm is not a
-- dead keybind.
function o.launch(command)
  if o.cmd_present("uwsm-app") then
    return "uwsm-app -- " .. command
  end
  return command
end

-- hl.bind with an optional description and a string-or-dispatcher argument.
function o.bind(keys, description, dispatcher, options)
  local opts = options or {}

  if description then
    opts.description = description
  end

  if type(dispatcher) == "string" then
    dispatcher = hl.dsp.exec_cmd(dispatcher)
  end

  hl.bind(keys, dispatcher, opts)
end
