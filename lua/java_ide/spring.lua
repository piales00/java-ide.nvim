-- Proyectos Spring Boot generados con Spring Initializr (start.spring.io).
local config = require("java_ide.config")
local util = require("java_ide.util")

local M = {}

local metadata_cache = {}

local BUILD_TYPES = {
  { id = "maven-project", name = "Maven" },
  { id = "gradle-project", name = "Gradle (Groovy)" },
  { id = "gradle-project-kotlin", name = "Gradle (Kotlin DSL)" },
}

local function base_url()
  return (config.options.spring.initializr_url:gsub("/+$", ""))
end

local function curl(args, cb)
  local cmd = vim.list_extend({ "curl", "-sS", "-L", "--max-time", "60" }, args)
  vim.system(cmd, { text = true }, vim.schedule_wrap(cb))
end

-- ---------------------------------------------------------------- versiones

--- "4.1.0-M1" → { 4, 1, 0, rango del calificador, número del calificador }.
function M.parse_version(v)
  v = v:gsub("%.x", ".999")
  local major, minor, patch, rest = v:match("^(%d+)%.(%d+)%.?(%d*)(.*)$")
  if not major then
    return nil
  end
  local qualifier = rest:upper()
  local rank = 4 -- versión final
  if qualifier:find("SNAPSHOT", 1, true) then
    rank = 3
  elseif qualifier:match("^[-.]?RC") then
    rank = 2
  elseif qualifier:match("^[-.]?M%d") then
    rank = 1
  end
  return { tonumber(major), tonumber(minor), tonumber(patch) or 0, rank, tonumber(rest:match("(%d+)$") or "") or 0 }
end

function M.compare(a, b)
  local va, vb = M.parse_version(a), M.parse_version(b)
  if not va or not vb then
    return 0
  end
  for i = 1, 5 do
    if va[i] ~= vb[i] then
      return va[i] < vb[i] and -1 or 1
    end
  end
  return 0
end

--- ¿`version` está dentro de un rango de Initializr? ("[3.4.0,4.0.0-M1)" o "3.4.0" = desde).
function M.in_range(version, range)
  if not range or range == "" then
    return true
  end
  local open, low, high, close = range:match("^([%[%(])%s*(.-)%s*,%s*(.-)%s*([%]%)])$")
  if not open then
    return M.compare(version, range) >= 0
  end
  if low ~= "" then
    local c = M.compare(version, low)
    if c < 0 or (c == 0 and open == "(") then
      return false
    end
  end
  if high ~= "" then
    local c = M.compare(version, high)
    if c > 0 or (c == 0 and close == ")") then
      return false
    end
  end
  return true
end

-- ---------------------------------------------------------------- metadata

function M.metadata(cb)
  local url = base_url()
  if metadata_cache[url] then
    return cb(metadata_cache[url])
  end
  if vim.fn.executable("curl") == 0 then
    return util.error("Se necesita `curl` para crear proyectos Spring Boot")
  end
  util.notify("Consultando " .. url .. "…")
  curl({ "-H", "Accept: application/vnd.initializr.v2.2+json", url }, function(res)
    if res.code ~= 0 then
      return util.error("No se pudo conectar con " .. url .. "\n" .. (res.stderr or ""))
    end
    local ok, meta = pcall(vim.json.decode, res.stdout)
    if not ok or type(meta) ~= "table" or not meta.dependencies then
      return util.error("Respuesta inesperada de " .. url)
    end
    metadata_cache[url] = meta
    cb(meta)
  end)
end

--- Versión de Java para el proyecto: la configurada o instalada (o la mayor disponible por debajo).
function M.pick_java_version(meta)
  local wanted = tonumber(config.options.java_version) or util.java_major_version()
  local best
  for _, v in ipairs(meta.javaVersion.values) do
    local n = tonumber(v.id)
    if n and wanted and n <= wanted and (not best or n > best) then
      best = n
    end
  end
  return best and tostring(best) or meta.javaVersion.default
end

--- Dependencias compatibles con la versión de Spring Boot elegida.
function M.dependencies_for(meta, boot_version)
  local items = {}
  for _, group in ipairs(meta.dependencies.values) do
    for _, dep in ipairs(group.values) do
      if M.in_range(boot_version, dep.versionRange) then
        table.insert(items, { id = dep.id, name = dep.name, group = group.name, description = dep.description or "" })
      end
    end
  end
  return items
end

-- ---------------------------------------------------------------- selección de dependencias

--- Selección múltiple con el picker de Snacks (Tab marca, Enter confirma).
local function pick_with_snacks(items, cb)
  local confirmed = false
  Snacks.picker.pick({
    title = "Dependencias · Tab marca · Enter confirma",
    items = vim.tbl_map(function(dep)
      return {
        text = dep.name .. " " .. dep.group .. " " .. dep.id,
        dep = dep,
        preview = { text = dep.name .. "\n\n" .. dep.group .. " · " .. dep.id .. "\n\n" .. dep.description },
      }
    end, items),
    format = function(item)
      return { { item.dep.name, "SnacksPickerLabel" }, { "  " .. item.dep.group, "SnacksPickerComment" } }
    end,
    preview = "preview",
    on_close = function()
      if not confirmed then
        util.warn("Cancelado")
      end
    end,
    confirm = function(picker)
      confirmed = true
      local selected = picker:selected({ fallback = true })
      picker:close()
      cb(vim.tbl_map(function(item)
        return item.dep
      end, selected))
    end,
  })
end

--- Selección múltiple con vim.ui.select: se agregan de a una hasta elegir "Crear proyecto".
local function pick_with_select(items, cb)
  local chosen = {}
  local function step()
    local remaining = vim.tbl_filter(function(dep)
      return not vim.tbl_contains(chosen, dep)
    end, items)
    local names = vim.tbl_map(function(dep)
      return dep.name
    end, chosen)
    local choices =
      { { label = "✔ Crear proyecto" .. (#chosen > 0 and (" (" .. table.concat(names, ", ") .. ")") or "") } }
    for _, dep in ipairs(remaining) do
      table.insert(choices, { label = dep.group .. " › " .. dep.name, dep = dep })
    end
    vim.ui.select(choices, {
      prompt = "Agregar dependencia",
      format_item = function(c)
        return c.label
      end,
    }, function(choice)
      if not choice then
        return util.warn("Cancelado")
      end
      if not choice.dep then
        return cb(chosen)
      end
      table.insert(chosen, choice.dep)
      step()
    end)
  end
  step()
end

function M.pick_dependencies(items, cb)
  if type(_G.Snacks) == "table" and Snacks.picker and Snacks.picker.pick then
    pick_with_snacks(items, cb)
  else
    pick_with_select(items, cb)
  end
end

-- ---------------------------------------------------------------- generar

local function open_generated(dir)
  vim.cmd.cd(vim.fn.fnameescape(dir))
  -- .env suele tener contraseñas: que nunca se suba a git.
  local gitignore = dir .. "/.gitignore"
  if util.exists(gitignore) and not util.read_file(gitignore):find("\n%.env\n") then
    vim.fn.writefile({ "", "### java-ide.nvim ###", ".env" }, gitignore, "a")
  end
  if vim.fn.executable("git") == 1 and not util.exists(dir .. "/.git") then
    vim.system({ "git", "init", "-q" }, { cwd = dir })
  end
  local app = vim.fs.find(function(name)
    return name:match("Application%.java$") ~= nil
  end, { path = dir .. "/src/main/java", type = "file" })[1]
  if app then
    vim.cmd.edit(vim.fn.fnameescape(app))
  end
  util.notify("Proyecto Spring Boot creado en " .. dir .. "\n(el LSP puede tardar en indexar la primera vez)")
end

--- Descarga el proyecto de Initializr y lo descomprime en `p.parent/p.name`.
function M.generate(p, cb)
  local tmp = vim.fn.tempname() .. ".tgz"
  local fields = {
    type = p.type,
    language = "java",
    bootVersion = p.boot_version,
    baseDir = p.name,
    groupId = p.group_id,
    artifactId = p.name,
    name = p.name,
    packageName = p.package,
    packaging = "jar",
    javaVersion = p.java_version,
    dependencies = table.concat(p.dependencies, ","),
  }
  local args = { "-o", tmp, "-w", "%{http_code}", base_url() .. "/starter.tgz" }
  for key, value in pairs(fields) do
    vim.list_extend(args, { "--data-urlencode", key .. "=" .. value })
  end

  util.notify("Generando proyecto con Spring Initializr…")
  curl(args, function(res)
    if res.code ~= 0 then
      return util.error("No se pudo descargar el proyecto\n" .. (res.stderr or ""))
    end
    if vim.trim(res.stdout) ~= "200" then
      local ok, body = pcall(vim.json.decode, util.exists(tmp) and util.read_file(tmp) or "")
      os.remove(tmp)
      return util.error("Spring Initializr rechazó el proyecto: " .. (ok and body and body.message or res.stdout))
    end
    vim.fn.mkdir(p.parent, "p")
    vim.system({ "tar", "-xzf", tmp, "-C", p.parent }, {}, function(tar)
      os.remove(tmp)
      vim.schedule(function()
        if tar.code ~= 0 then
          return util.error("No se pudo descomprimir el proyecto")
        end
        open_generated(p.parent .. "/" .. p.name)
        if cb then
          cb()
        end
      end)
    end)
  end)
end

function M.new_project()
  M.metadata(function(meta)
    local p = { java_version = M.pick_java_version(meta) }

    vim.ui.select(BUILD_TYPES, {
      prompt = "Build",
      format_item = function(t)
        return t.name
      end,
    }, function(build)
      if not build then
        return
      end
      p.type = build.id

      -- La versión recomendada primero; las SNAPSHOT (inestables) al final.
      local versions = vim.tbl_map(function(v)
        return v.id
      end, meta.bootVersion.values)
      table.sort(versions, function(a, b)
        if a == b then
          return false
        end
        if a == meta.bootVersion.default or b == meta.bootVersion.default then
          return a == meta.bootVersion.default
        end
        local snap_a, snap_b = a:find("SNAPSHOT", 1, true) ~= nil, b:find("SNAPSHOT", 1, true) ~= nil
        if snap_a ~= snap_b then
          return snap_b
        end
        return M.compare(a, b) > 0
      end)

      vim.ui.select(versions, {
        prompt = "Versión de Spring Boot",
        format_item = function(v)
          return v == meta.bootVersion.default and (v .. " (recomendada)") or v
        end,
      }, function(boot_version)
        if not boot_version then
          return
        end
        p.boot_version = boot_version

        util.ask("Nombre del proyecto: ", nil, function(name)
          if not name:match("^[%w_.%-]+$") then
            return util.error("Nombre inválido (usa letras, números, '-', '_' o '.'): " .. name)
          end
          p.name = name

          util.ask("Carpeta padre: ", config.options.projects_dir, function(parent)
            p.parent = vim.fs.normalize(vim.fn.expand(parent))
            if util.exists(p.parent .. "/" .. name) then
              return util.error("Ya existe: " .. p.parent .. "/" .. name)
            end

            util.ask("groupId: ", config.options.group_id, function(group_id)
              if not util.valid_package(group_id) then
                return util.error("groupId inválido: " .. group_id)
              end
              p.group_id = group_id

              util.ask("Paquete: ", group_id .. "." .. util.to_package_part(name), function(pkg)
                if not util.valid_package(pkg) then
                  return util.error("Paquete inválido: " .. pkg)
                end
                p.package = pkg

                M.pick_dependencies(M.dependencies_for(meta, boot_version), function(deps)
                  p.dependencies = vim.tbl_map(function(d)
                    return d.id
                  end, deps)
                  M.generate(p)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
end

return M
