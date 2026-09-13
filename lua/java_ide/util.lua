local M = {}

local uv = vim.uv or vim.loop

function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "java-ide" })
end

function M.warn(msg)
  M.notify(msg, vim.log.levels.WARN)
end

function M.error(msg)
  M.notify(msg, vim.log.levels.ERROR)
end

function M.exists(path)
  return uv.fs_stat(path) ~= nil
end

function M.write_file(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile(type(content) == "string" and vim.split(content, "\n") or content, path)
end

function M.read_file(path)
  return table.concat(vim.fn.readfile(path), "\n")
end

local reserved = {}
for word in
  ([[abstract assert boolean break byte case catch char class const continue default do double else enum
  extends final finally float for goto if implements import instanceof int interface long native new package private
  protected public return short static strictfp super switch synchronized this throw throws transient try void volatile
  while true false null]]):gmatch("%a+")
do
  reserved[word] = true
end

function M.valid_identifier(s)
  return s:match("^[%a_$][%w_$]*$") ~= nil and not reserved[s]
end

function M.valid_package(s)
  if s == "" or s:match("^%.") or s:match("%.$") or s:match("%.%.") then
    return false
  end
  for part in s:gmatch("[^%.]+") do
    if not M.valid_identifier(part) then
      return false
    end
  end
  return true
end

--- Convierte un texto cualquiera ("Mi Proyecto-2") en un segmento de paquete válido ("miproyecto2").
function M.to_package_part(s)
  s = s:lower():gsub("[^%w_]", "")
  if s:match("^%d") or reserved[s] then
    s = "_" .. s
  end
  return s
end

--- vim.ui.input que ignora respuestas vacías o canceladas.
function M.ask(prompt, default, cb)
  vim.ui.input({ prompt = prompt, default = default }, function(value)
    if value == nil or vim.trim(value) == "" then
      return M.warn("Cancelado")
    end
    cb(vim.trim(value))
  end)
end

--- Versión mayor del `java` instalado (17, 21, ...), o nil.
function M.java_major_version()
  if vim.fn.executable("java") == 0 then
    return nil
  end
  local res = vim.system({ "java", "-version" }, { text = true }):wait()
  local v = ((res.stderr or "") .. (res.stdout or "")):match('version "([^"]+)"')
  if not v then
    return nil
  end
  local major = v:match("^1%.(%d+)") or v:match("^(%d+)")
  return tonumber(major)
end

--- Nombre del ejecutable según el sistema (mvn → mvn.cmd en Windows).
function M.exe(name)
  if vim.fn.has("win32") == 1 and vim.fn.executable(name .. ".cmd") == 1 then
    return name .. ".cmd"
  end
  return name
end

return M
