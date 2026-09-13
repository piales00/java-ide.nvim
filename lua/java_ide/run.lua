-- Compilar, ejecutar y testear con Maven, Gradle o javac.
local project = require("java_ide.project")
local terminal = require("java_ide.terminal")
local util = require("java_ide.util")

local M = {}

local function save_all()
  vim.cmd("silent! wall")
end

local function gradle(root)
  if vim.fn.has("win32") == 1 and util.exists(root .. "/gradlew.bat") then
    return root .. "/gradlew.bat"
  end
  if util.exists(root .. "/gradlew") then
    return "./gradlew"
  end
  return "gradle"
end

local function pom_has_main_class(root)
  local pom = util.read_file(root .. "/pom.xml")
  return pom:find("exec.mainClass", 1, true) ~= nil or pom:find("<mainClass>", 1, true) ~= nil
end

--- Sin build tool: compila todos los .java del source root a out/ y ejecuta la clase.
local function run_plain(class)
  if vim.fn.has("win32") == 1 then
    return util.error("Ejecutar proyectos sin Maven/Gradle todavía no está soportado en Windows")
  end
  local src = project.source_root(class.file, class.package)
  local root = src:match("^(.*)/src$") or src
  local out = root .. "/out"
  local e = vim.fn.shellescape
  local script = table.concat({
    "set -e",
    "mkdir -p " .. e(out),
    "find " .. e(src) .. " -name '*.java' > " .. e(out .. "/.sources"),
    "javac -d " .. e(out) .. " @" .. e(out .. "/.sources"),
    "java -cp " .. e(out) .. " " .. e(class.fqcn),
  }, "\n")
  terminal.run({ "sh", "-c", script }, root)
end

function M.run()
  save_all()
  local kind, root = project.detect()
  local class = project.current_class()
  local main_class = (class and project.has_main(0)) and class.fqcn or nil

  if kind == "maven" then
    if not main_class and not pom_has_main_class(root) then
      return util.warn("Abrí una clase con main (o definí exec.mainClass en el pom.xml)")
    end
    local cmd = { util.exe("mvn"), "-q", "compile", "exec:java" }
    if main_class then
      table.insert(cmd, "-Dexec.mainClass=" .. main_class)
    end
    terminal.run(cmd, root)
  elseif kind == "gradle" then
    terminal.run({ gradle(root), "-q", "--console=plain", "run" }, root)
  elseif main_class then
    run_plain(class)
  else
    util.warn("Abrí un archivo .java con main para ejecutarlo")
  end
end

--- Crea una tarea que corre un goal de Maven o una task de Gradle en la raíz del proyecto.
local function task(maven_args, gradle_args)
  return function()
    save_all()
    local kind, root = project.detect()
    if kind == "maven" then
      terminal.run(vim.list_extend({ util.exe("mvn") }, maven_args), root)
    elseif kind == "gradle" then
      terminal.run(vim.list_extend({ gradle(root) }, gradle_args), root)
    else
      util.warn("Esto necesita un proyecto Maven o Gradle")
    end
  end
end

M.build = task({ "compile" }, { "classes" })
M.test_all = task({ "test" }, { "test" })
M.clean = task({ "clean" }, { "clean" })
M.package = task({ "package" }, { "build" })

function M.test_file()
  save_all()
  local kind, root = project.detect()
  local class = project.current_class()
  if not class then
    return util.warn("Abrí una clase de test")
  end
  if kind == "maven" then
    terminal.run({ util.exe("mvn"), "test", "-Dtest=" .. class.fqcn, "-Dsurefire.failIfNoSpecifiedTests=false" }, root)
  elseif kind == "gradle" then
    terminal.run({ gradle(root), "test", "--tests", class.fqcn }, root)
  else
    util.warn("Los tests necesitan un proyecto Maven o Gradle")
  end
end

return M
