-- Detección del proyecto y de la clase del buffer actual.
local M = {}

local uv = vim.uv or vim.loop

local function buffer_path(buf)
  local name = vim.api.nvim_buf_get_name(buf or 0)
  -- Buffers especiales (term://, oil://, etc.) no son rutas reales.
  if name == "" or name:match("^%a[%w+.-]*://") then
    return nil
  end
  return name
end

--- Devuelve kind ("maven" | "gradle" | "plain") y la raíz del proyecto (nil si es "plain").
function M.detect(path)
  path = path or buffer_path(0)
  local start = path and vim.fn.fnamemodify(path, ":p:h") or uv.cwd()
  local found = vim.fs.find({ "pom.xml", "build.gradle", "build.gradle.kts" }, { upward = true, path = start })[1]
  if not found then
    return "plain", nil
  end
  return vim.fs.basename(found) == "pom.xml" and "maven" or "gradle", vim.fs.dirname(found)
end

--- Paquete declarado en el buffer (`package com.foo;`), o nil.
function M.buffer_package(buf)
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf or 0, 0, 100, false)) do
    local pkg = line:match("^%s*package%s+([%w_.$]+)%s*;")
    if pkg then
      return pkg
    end
  end
end

--- Información de la clase del buffer actual: { fqcn, package, file }, o nil si no es un .java.
function M.current_class()
  local file = buffer_path(0)
  if not file or not file:match("%.java$") then
    return nil
  end
  local class = vim.fn.fnamemodify(file, ":t:r")
  local pkg = M.buffer_package(0)
  return { fqcn = pkg and (pkg .. "." .. class) or class, package = pkg, file = file }
end

--- Carpeta raíz de fuentes (la que contiene com/foo/...) para un archivo y su paquete.
function M.source_root(file, pkg)
  local dir = vim.fn.fnamemodify(file, ":p:h")
  if not pkg then
    return dir
  end
  local suffix = "/" .. pkg:gsub("%.", "/")
  if dir:sub(-#suffix) == suffix then
    return dir:sub(1, #dir - #suffix)
  end
  return dir
end

--- ¿El buffer tiene un método main? (incluye `void main()` de Java 21+).
function M.has_main(buf)
  local text = table.concat(vim.api.nvim_buf_get_lines(buf or 0, 0, -1, false), "\n")
  return text:match("void%s+main%s*%(") ~= nil
end

--- Clases con main dentro de una carpeta de fuentes, como nombres completos (com.app.Main).
function M.find_main_classes(src_dir)
  local found = {}
  if not uv.fs_stat(src_dir) then
    return found
  end
  for name, type in vim.fs.dir(src_dir, { depth = math.huge }) do
    if type == "file" and name:match("%.java$") then
      local fd = io.open(src_dir .. "/" .. name, "r")
      local text = fd and fd:read("*a") or ""
      if fd then
        fd:close()
      end
      if text:match("void%s+main%s*%(") then
        table.insert(found, (name:gsub("%.java$", ""):gsub("/", ".")))
      end
    end
  end
  table.sort(found)
  return found
end

return M
