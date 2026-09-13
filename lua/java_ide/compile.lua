-- Saber si hace falta compilar, comparando cada fuente con su archivo compilado.
--
-- Se compara archivo por archivo (Foo.java → Foo.class) en vez de usar una marca de tiempo
-- propia: así, si jdtls ya compiló al guardar (lo hace solo en proyectos Maven/Gradle),
-- las clases están al día y se ejecuta sin volver a compilar.
local M = {}

local uv = vim.uv or vim.loop

local function is_newer(a, b)
  return a.sec > b.sec or (a.sec == b.sec and a.nsec > b.nsec)
end

--- true si `target` no existe o `source` fue modificado después.
function M.newer_than(source, target)
  local t = uv.fs_stat(target)
  if not t then
    return true
  end
  local s = uv.fs_stat(source)
  return s ~= nil and is_newer(s.mtime, t.mtime)
end

--- true si algún archivo de `src_dir` no está compilado/copiado en `out_dir` o cambió después.
--- Con `resources = true` se comparan todos los archivos (se copian tal cual);
--- si no, solo los .java contra su .class.
function M.is_stale(src_dir, out_dir, resources)
  if not uv.fs_stat(src_dir) then
    return false
  end
  if not uv.fs_stat(out_dir) then
    return true
  end
  for name, type in vim.fs.dir(src_dir, { depth = math.huge }) do
    if type == "file" then
      local target
      if resources then
        target = out_dir .. "/" .. name
      elseif name:match("%.java$") then
        target = out_dir .. "/" .. name:gsub("%.java$", ".class")
      end
      if target and M.newer_than(src_dir .. "/" .. name, target) then
        return true
      end
    end
  end
  return false
end

return M
