-- Generadores: proyectos nuevos y clases nuevas.
local config = require("java_ide.config")
local project = require("java_ide.project")
local templates = require("java_ide.templates")
local util = require("java_ide.util")

local M = {}

local PROJECT_TYPES = { "Maven", "Java plano (src/ + out/, sin build tool)" }

local function open_project(dir, main_file)
  vim.cmd.cd(vim.fn.fnameescape(dir))
  vim.cmd.edit(vim.fn.fnameescape(main_file))
  if vim.fn.executable("git") == 1 and not util.exists(dir .. "/.git") then
    vim.system({ "git", "init", "-q" }, { cwd = dir })
  end
  util.notify("Proyecto creado en " .. dir .. "\n(el LSP puede tardar unos segundos en indexar)")
end

local function generate_project(p)
  local pkg_path = p.package:gsub("%.", "/")
  util.write_file(p.dir .. "/.gitignore", templates.gitignore)
  local main_kind = templates.find_kind("Main class")

  if p.maven then
    local java_version = config.options.java_version or util.java_major_version() or 21
    util.write_file(
      p.dir .. "/pom.xml",
      templates.pom({
        group_id = p.group_id,
        artifact_id = p.name,
        java_version = tostring(java_version),
        main_class = p.package .. ".Main",
      })
    )
    local main_file = p.dir .. "/src/main/java/" .. pkg_path .. "/Main.java"
    util.write_file(main_file, templates.java_file(main_kind, "Main", p.package))
    util.write_file(
      p.dir .. "/src/test/java/" .. pkg_path .. "/MainTest.java",
      templates.java_file(templates.find_kind("JUnit test"), "MainTest", p.package)
    )
    vim.fn.mkdir(p.dir .. "/src/main/resources", "p")
    return main_file
  end

  local main_file = p.dir .. "/src/" .. pkg_path .. "/Main.java"
  util.write_file(main_file, templates.java_file(main_kind, "Main", p.package))
  return main_file
end

function M.new_project()
  vim.ui.select(PROJECT_TYPES, { prompt = "Tipo de proyecto" }, function(choice)
    if not choice then
      return
    end
    local p = { maven = choice == PROJECT_TYPES[1] }

    util.ask("Nombre del proyecto: ", nil, function(name)
      if not name:match("^[%w_.%-]+$") then
        return util.error("Nombre inválido (usá letras, números, '-', '_' o '.'): " .. name)
      end
      p.name = name

      util.ask("Carpeta padre: ", config.options.projects_dir, function(parent)
        p.dir = vim.fs.normalize(vim.fn.expand(parent)) .. "/" .. name
        if util.exists(p.dir) then
          return util.error("Ya existe: " .. p.dir)
        end

        util.ask("groupId: ", config.options.group_id, function(group_id)
          if not util.valid_package(group_id) then
            return util.error("groupId inválido: " .. group_id)
          end
          p.group_id = group_id

          util.ask("Paquete de Main: ", group_id .. "." .. util.to_package_part(name), function(pkg)
            if not util.valid_package(pkg) then
              return util.error("Paquete inválido: " .. pkg)
            end
            p.package = pkg
            open_project(p.dir, generate_project(p))
          end)
        end)
      end)
    end)
  end)
end

--- Carpeta de fuentes donde crear la clase y el paquete sugerido.
local function target_source_root(is_test)
  local kind, root = project.detect()
  local current = project.current_class()
  local has_build_tool = kind == "maven" or kind == "gradle"

  if current then
    local src = project.source_root(current.file, current.package)
    local in_test = src:match("/src/test/java$") ~= nil
    -- En Maven/Gradle los tests van en src/test/java y el resto en src/main/java.
    if not has_build_tool or in_test == is_test then
      return src, current.package
    end
  end
  if root then
    return root .. (is_test and "/src/test/java" or "/src/main/java"), current and current.package
  end
  local cwd = (vim.uv or vim.loop).cwd()
  return util.exists(cwd .. "/src") and (cwd .. "/src") or cwd, current and current.package
end

function M.new_class()
  local names = vim.tbl_map(function(k)
    return k.name
  end, templates.kinds)

  vim.ui.select(names, { prompt = "Tipo" }, function(choice)
    if not choice then
      return
    end
    local kind = templates.find_kind(choice)
    local src, pkg = target_source_root(kind.test == true)

    util.ask("Nombre (con paquete, ej. com.app.model.User): ", pkg and (pkg .. ".") or "", function(input)
      local pkg_name, class = input:match("^(.*)%.([^.]+)$")
      if not class then
        pkg_name, class = nil, input
      end
      if not util.valid_identifier(class) or (pkg_name and not util.valid_package(pkg_name)) then
        return util.error("Nombre inválido: " .. input)
      end

      local dir = src .. (pkg_name and ("/" .. pkg_name:gsub("%.", "/")) or "")
      local path = dir .. "/" .. class .. ".java"
      if util.exists(path) then
        return util.error("Ya existe: " .. path)
      end
      util.write_file(path, templates.java_file(kind, class, pkg_name))
      vim.cmd.edit(vim.fn.fnameescape(path))
    end)
  end)
end

return M
