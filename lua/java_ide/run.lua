-- Compilar, ejecutar y testear con Maven, Gradle o javac.
local compile = require("java_ide.compile")
local config = require("java_ide.config")
local maven = require("java_ide.maven")
local project = require("java_ide.project")
local terminal = require("java_ide.terminal")
local util = require("java_ide.util")

local M = {}

local e = vim.fn.shellescape

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

local function fast_run_enabled()
  return config.options.fast_run and vim.fn.has("win32") == 0
end

--- Argumentos de javac comunes: codificación, versión y procesadores de anotaciones.
local function javac_flags(release, encoding)
  local flags = { "-encoding", encoding or "UTF-8" }
  if release then
    vim.list_extend(flags, { "--release", release })
  end
  -- Desde JDK 23 los procesadores (Lombok, etc.) ya no se activan solos.
  local java = util.java_major_version()
  if java and java >= 23 then
    table.insert(flags, "-proc:full")
  end
  return table.concat(vim.tbl_map(e, flags), " ")
end

--- Maven "oficial": arranca Maven, compila y ejecuta dentro de su JVM (~3 s fijos).
local function run_maven_exec(root, main_class)
  local cmd = { util.maven(), "-q", "compile", "exec:java" }
  if main_class then
    table.insert(cmd, "-Dexec.mainClass=" .. main_class)
  end
  terminal.run(cmd, root)
end

--- Maven rápido: classpath en caché, compila solo si algo cambió y ejecuta con `java`.
local function run_maven_fast(root, main_class)
  local pom = util.read_file(root .. "/pom.xml")
  local mvn = e(util.maven())
  local cache = "target/java-ide"
  local cp_file = cache .. "/classpath.txt"

  -- El classpath (jars de dependencias) solo cambia cuando cambia el pom.xml.
  local cp_stale = compile.newer_than(root .. "/pom.xml", root .. "/" .. cp_file)
  local stale = cp_stale
    or compile.is_stale(root .. "/src/main/java", root .. "/target/classes")
    or compile.is_stale(root .. "/src/main/resources", root .. "/target/classes", true)

  local script = { "set -e" }
  local function add(line)
    table.insert(script, line)
  end

  if cp_stale then
    add("mkdir -p " .. cache)
    add(mvn .. " -q dependency:build-classpath -Dmdep.outputFile=" .. cp_file)
  end
  add("CP=$(cat " .. cp_file .. ")")

  if stale and maven.needs_maven_compile(pom) then
    add(mvn .. " -q compile")
  elseif stale then
    add("mkdir -p target/classes")
    if util.exists(root .. "/src/main/resources") then
      add("cp -R src/main/resources/. target/classes/")
    end
    add("find src/main/java -name '*.java' > " .. cache .. "/sources.txt")
    add(
      "javac "
        .. javac_flags(maven.java_release(pom), maven.property(pom, "project.build.sourceEncoding"))
        .. ' -d target/classes -cp "$CP" @'
        .. cache
        .. "/sources.txt"
    )
  end

  add('exec java -cp "target/classes${CP:+:$CP}" ' .. e(main_class))
  terminal.run({ "sh", "-c", table.concat(script, "\n") }, root)
end

--- Sin build tool: compila todo src/ a out/ (solo si algo cambió) y ejecuta la clase.
local function run_plain(class)
  if vim.fn.has("win32") == 1 then
    return util.error("Ejecutar proyectos sin Maven/Gradle todavía no está soportado en Windows")
  end
  local src = project.source_root(class.file, class.package)
  local root = src:match("^(.*)/src$") or src
  local out = root .. "/out"

  local script = { "set -e" }
  if compile.is_stale(src, out) then
    vim.list_extend(script, {
      "mkdir -p " .. e(out),
      "find " .. e(src) .. " -name '*.java' > " .. e(out .. "/.java-ide-sources"),
      "javac " .. javac_flags() .. " -d " .. e(out) .. " @" .. e(out .. "/.java-ide-sources"),
    })
  end
  table.insert(script, "exec java -cp " .. e(out) .. " " .. e(class.fqcn))
  terminal.run({ "sh", "-c", table.concat(script, "\n") }, root)
end

function M.run()
  save_all()
  local kind, root = project.detect()
  local class = project.current_class()
  local main_class = (class and project.has_main(0)) and class.fqcn or nil

  if kind == "maven" then
    local pom_main = maven.main_class(util.read_file(root .. "/pom.xml"))
    if not main_class and not pom_main then
      return util.warn("Abre una clase con main (o define exec.mainClass en el pom.xml)")
    end
    -- Las clases de test no están en target/classes: para esas se usa Maven.
    local in_tests = main_class and class.file:find("/src/test/java/", 1, true)
    if fast_run_enabled() and not in_tests then
      run_maven_fast(root, main_class or pom_main)
    else
      run_maven_exec(root, main_class)
    end
  elseif kind == "gradle" then
    terminal.run({ gradle(root), "-q", "--console=plain", "run" }, root)
  elseif main_class then
    run_plain(class)
  else
    util.warn("Abre un archivo .java con main para ejecutarlo")
  end
end

--- Crea una tarea que corre un goal de Maven o una task de Gradle en la raíz del proyecto.
local function task(maven_args, gradle_args)
  return function()
    save_all()
    local kind, root = project.detect()
    if kind == "maven" then
      terminal.run(vim.list_extend({ util.maven() }, maven_args), root)
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
    return util.warn("Abre una clase de test")
  end
  if kind == "maven" then
    terminal.run({ util.maven(), "test", "-Dtest=" .. class.fqcn, "-Dsurefire.failIfNoSpecifiedTests=false" }, root)
  elseif kind == "gradle" then
    terminal.run({ gradle(root), "test", "--tests", class.fqcn }, root)
  else
    util.warn("Los tests necesitan un proyecto Maven o Gradle")
  end
end

return M
