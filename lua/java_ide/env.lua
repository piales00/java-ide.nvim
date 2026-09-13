-- Variables de entorno al ejecutar: archivo .env del proyecto y perfil de Spring activo.
local config = require("java_ide.config")
local util = require("java_ide.util")

local M = {}

local uv = vim.uv or vim.loop

--- Lee un archivo .env: `CLAVE=valor`, comentarios con #, `export` opcional y comillas.
function M.parse_dotenv(text)
  local vars = {}
  for line in vim.gsplit(text, "\n", { plain = true }) do
    line = vim.trim(line):gsub("^export%s+", "")
    local key, value = line:match("^([%a_][%w_.]*)%s*=%s*(.*)$")
    if key then
      local quote = value:sub(1, 1)
      if (quote == '"' or quote == "'") and value:find(quote, 2, true) then
        value = value:sub(2, value:find(quote, 2, true) - 1)
        if quote == '"' then
          value = value:gsub("\\n", "\n")
        end
      else
        value = vim.trim((value:gsub("%s+#.*$", "")))
      end
      vars[key] = value
    end
  end
  return vars
end

function M.dotenv(root)
  local name = config.options.env_file
  if not name or not root then
    return {}
  end
  local path = root .. "/" .. name
  if not util.exists(path) then
    return {}
  end
  return M.parse_dotenv(util.read_file(path))
end

-- ---------------------------------------------------------------- perfiles

local function state_file()
  return vim.fn.stdpath("data") .. "/java-ide/profiles.json"
end

local function read_state()
  local path = state_file()
  if not util.exists(path) then
    return {}
  end
  local ok, data = pcall(vim.json.decode, util.read_file(path))
  return (ok and type(data) == "table") and data or {}
end

function M.profile(root)
  return root and read_state()[root] or nil
end

function M.set_profile(root, profile)
  local data = read_state()
  data[root] = profile
  util.write_file(state_file(), vim.json.encode(data))
end

--- Perfiles encontrados en src/main/resources (application-dev.yml → dev).
function M.detect_profiles(root)
  local found, seen = {}, {}
  local dir = root .. "/src/main/resources"
  if not uv.fs_stat(dir) then
    return found
  end
  for name, type in vim.fs.dir(dir) do
    local profile = type == "file" and name:match("^application%-(.+)%.[%a]+$")
    if profile and not seen[profile] then
      seen[profile] = true
      table.insert(found, profile)
    end
  end
  table.sort(found)
  return found
end

function M.select_profile()
  local _, root = require("java_ide.project").detect()
  if not root then
    return util.warn("Los perfiles necesitan un proyecto Maven o Gradle")
  end
  local current = M.profile(root)
  local NONE, OTHER = "(ninguno)", "Otro…"
  local choices = vim.list_extend({ NONE }, M.detect_profiles(root))
  table.insert(choices, OTHER)

  vim.ui.select(choices, {
    prompt = "Perfil de Spring" .. (current and (" (actual: " .. current .. ")") or ""),
  }, function(choice)
    if not choice then
      return
    end
    local function apply(profile)
      M.set_profile(root, profile)
      util.notify(profile and ("Perfil activo: " .. profile) or "Sin perfil")
    end
    if choice == NONE then
      apply(nil)
    elseif choice == OTHER then
      util.ask("Perfiles (separados por coma): ", current, apply)
    else
      apply(choice)
    end
  end)
end

--- Variables de entorno para ejecutar: .env + SPRING_PROFILES_ACTIVE (si hay perfil).
function M.for_run(root)
  local vars = M.dotenv(root)
  local profile = M.profile(root)
  if profile then
    vars.SPRING_PROFILES_ACTIVE = profile
  end
  return vars
end

return M
