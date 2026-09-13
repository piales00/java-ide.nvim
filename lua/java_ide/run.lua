-- Compilar, ejecutar y testear con Maven, Gradle o javac.
local compile = require("java_ide.compile")
local config = require("java_ide.config")
local env = require("java_ide.env")
local maven = require("java_ide.maven")
local project = require("java_ide.project")
local terminal = require("java_ide.terminal")
local util = require("java_ide.util")

local M = {}

local e = vim.fn.shellescape

-- Última clase main y últimos argumentos usados en cada proyecto (durante la sesión).
local last_main, last_args = {}, {}

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

local function gradle_build_file(root)
  for _, name in ipairs({ "build.gradle.kts", "build.gradle" }) do
    if util.exists(root .. "/" .. name) then
      return util.read_file(root .. "/" .. name)
    end
  end
  return ""
end

local function fast_run_enabled()
  return config.options.fast_run and vim.fn.has("win32") == 0
end

local function shell_args(args)
  return #args > 0 and (" " .. table.concat(vim.tbl_map(e, args), " ")) or ""
end

--- Argumentos de javac comunes: codificación, versión y procesadores de anotaciones.
local function javac_flags(release, encoding)
  local flags = { "-encoding", encoding or "UTF-8" }
  if release then
    vim.list_extend(flags, { "--release", release })
  end
  -- Procesadores del classpath (Lombok, etc.): desde JDK 23 ya no se activan solos,
  -- y en 21/22 activarlos explícitamente evita un aviso en cada compilación.
  local java = util.java_major_version()
  if java and java >= 21 then
    table.insert(flags, "-proc:full")
  end
  return table.concat(vim.tbl_map(e, flags), " ")
end

--- Decide qué clase ejecutar: la del archivo abierto si tiene main, la última usada en el
--- proyecto, la configurada en el build, o la única (o una a elegir) que tenga main.
local function resolve_main(key, src_dir, class, configured, cb)
  if class and project.has_main(0) then
    last_main[key] = class.fqcn
    return cb(class.fqcn)
  end
  if last_main[key] then
    return cb(last_main[key])
  end
  if configured then
    return cb(configured)
  end
  local mains = project.find_main_classes(src_dir)
  if #mains == 0 then
    return util.warn("No encontré ninguna clase con main")
  end
  if #mains == 1 then
    last_main[key] = mains[1]
    return cb(mains[1])
  end
  vim.ui.select(mains, { prompt = "¿Qué clase ejecutar?" }, function(choice)
    if choice then
      last_main[key] = choice
      cb(choice)
    end
  end)
end

-- ---------------------------------------------------------------- Maven

--- Maven "oficial": spring-boot:run o exec:java (arranca Maven completo, ~3 s fijos).
local function run_maven_exec(root, pom, main_class, args, vars)
  local cmd = { util.maven(), "-q" }
  if pom:find("spring-boot-maven-plugin", 1, true) then
    table.insert(cmd, "spring-boot:run")
    if main_class then
      table.insert(cmd, "-Dspring-boot.run.main-class=" .. main_class)
    end
    if #args > 0 then
      table.insert(cmd, "-Dspring-boot.run.arguments=" .. table.concat(args, " "))
    end
  else
    vim.list_extend(cmd, { "compile", "exec:java" })
    if main_class then
      table.insert(cmd, "-Dexec.mainClass=" .. main_class)
    end
    if #args > 0 then
      table.insert(cmd, "-Dexec.args=" .. table.concat(args, " "))
    end
  end
  terminal.run(cmd, root, vars)
end

-- Convierte la salida de `dependency:list` en dos classpaths: el de compilación
-- (sin test) y el de ejecución (sin test, provided ni system).
local SPLIT_CLASSPATH = [=[
awk -v c=target/java-ide/compile-classpath.txt -v r=target/java-ide/runtime-classpath.txt '
{
  gsub(/\033\[[0-9;]*m/, ""); sub(/ -- module.*/, ""); sub(/ \(optional\).*/, "")
  i = index($0, ":/"); if (!i) next
  path = substr($0, i + 1); n = split(substr($0, 1, i - 1), f, ":"); scope = f[n]
  if (scope == "test") next
  cp = cp sep path; sep = ":"
  if (scope != "provided" && scope != "system") { rcp = rcp rsep path; rsep = ":" }
}
END { printf "%s", cp > c; printf "%s", rcp > r }' target/java-ide/dependencies.txt]=]

--- Maven rápido: classpath en caché, compila solo si algo cambió y ejecuta con `java`.
local function run_maven_fast(root, pom, main_class, args, vars)
  local mvn = e(util.maven())
  local cache = "target/java-ide"

  -- Los jars de las dependencias solo cambian cuando cambia el pom.xml.
  local cp_stale = compile.newer_than(root .. "/pom.xml", root .. "/" .. cache .. "/runtime-classpath.txt")
  local stale = cp_stale
    or compile.is_stale(root .. "/src/main/java", root .. "/target/classes")
    or compile.is_stale(root .. "/src/main/resources", root .. "/target/classes", true)

  local script = { "set -e" }
  local function add(line)
    table.insert(script, line)
  end

  if cp_stale then
    add("mkdir -p " .. cache)
    add(
      mvn .. " -q dependency:list -DoutputAbsoluteArtifactFilename=true -DoutputFile=" .. cache .. "/dependencies.txt"
    )
    add(SPLIT_CLASSPATH)
  end

  if stale and maven.needs_maven_compile(pom, root) then
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
        .. ' -d target/classes -cp "$(cat '
        .. cache
        .. '/compile-classpath.txt)" @'
        .. cache
        .. "/sources.txt"
    )
  end

  add("RCP=$(cat " .. cache .. "/runtime-classpath.txt)")
  add('exec java -cp "target/classes${RCP:+:$RCP}" ' .. e(main_class) .. shell_args(args))
  terminal.run({ "sh", "-c", table.concat(script, "\n") }, root, vars)
end

local function run_maven(root, class, args)
  local pom = util.read_file(root .. "/pom.xml")
  local vars = env.for_run(root)
  -- Un main en src/test/java no está en target/classes: se ejecuta con Maven.
  if class and project.has_main(0) and class.file:find("/src/test/java/", 1, true) then
    return run_maven_exec(root, pom, class.fqcn, args, vars)
  end
  resolve_main(root, root .. "/src/main/java", class, maven.main_class(pom), function(main_class)
    if fast_run_enabled() then
      run_maven_fast(root, pom, main_class, args, vars)
    else
      run_maven_exec(root, pom, main_class, args, vars)
    end
  end)
end

-- ---------------------------------------------------------------- Gradle y javac

local function run_gradle(root, args)
  local spring = gradle_build_file(root):find("org.springframework.boot", 1, true)
  local cmd = { gradle(root), "--console=plain", spring and "bootRun" or "run" }
  if #args > 0 then
    table.insert(cmd, "--args=" .. table.concat(args, " "))
  end
  terminal.run(cmd, root, env.for_run(root))
end

--- Sin build tool: compila todo src/ a out/ (solo si algo cambió) y ejecuta la clase.
local function run_plain(class, args)
  if vim.fn.has("win32") == 1 then
    return util.error("Ejecutar proyectos sin Maven/Gradle todavía no está soportado en Windows")
  end
  local src = project.source_root(class.file, class.package)
  local root = src:match("^(.*)/src$") or src
  local out = root .. "/out"

  resolve_main(src, src, class, nil, function(main_class)
    local script = { "set -e" }
    if compile.is_stale(src, out) then
      vim.list_extend(script, {
        "mkdir -p " .. e(out),
        "find " .. e(src) .. " -name '*.java' > " .. e(out .. "/.java-ide-sources"),
        "javac " .. javac_flags() .. " -d " .. e(out) .. " @" .. e(out .. "/.java-ide-sources"),
      })
    end
    table.insert(script, "exec java -cp " .. e(out) .. " " .. e(main_class) .. shell_args(args))
    terminal.run({ "sh", "-c", table.concat(script, "\n") }, root, env.dotenv(root))
  end)
end

-- ---------------------------------------------------------------- comandos

--- Ejecuta el main. `args` (opcional) son los argumentos del programa.
function M.run(args)
  args = args or {}
  save_all()
  local kind, root = project.detect()
  local class = project.current_class()
  if kind == "maven" then
    run_maven(root, class, args)
  elseif kind == "gradle" then
    run_gradle(root, args)
  elseif class then
    run_plain(class, args)
  else
    util.warn("Abre un archivo .java para ejecutarlo")
  end
end

--- Pide los argumentos del programa (recuerda los últimos) y ejecuta.
function M.run_with_args()
  local _, root = project.detect()
  local key = root or (vim.uv or vim.loop).cwd()
  vim.ui.input({ prompt = "Argumentos: ", default = last_args[key] }, function(input)
    if input == nil then
      return
    end
    last_args[key] = input
    local args = {}
    for arg in input:gmatch("%S+") do
      table.insert(args, arg)
    end
    M.run(args)
  end)
end

function M.stop()
  if terminal.stop() then
    util.notify("Ejecución detenida")
  else
    util.warn("No hay nada ejecutándose")
  end
end

--- Crea una tarea que corre un goal de Maven o una task de Gradle en la raíz del proyecto.
local function task(maven_args, gradle_args)
  return function()
    save_all()
    local kind, root = project.detect()
    if kind == "maven" then
      terminal.run(vim.list_extend({ util.maven() }, maven_args), root, env.dotenv(root))
    elseif kind == "gradle" then
      terminal.run(vim.list_extend({ gradle(root) }, gradle_args), root, env.dotenv(root))
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
    terminal.run(
      { util.maven(), "test", "-Dtest=" .. class.fqcn, "-Dsurefire.failIfNoSpecifiedTests=false" },
      root,
      env.dotenv(root)
    )
  elseif kind == "gradle" then
    terminal.run({ gradle(root), "test", "--tests", class.fqcn }, root, env.dotenv(root))
  else
    util.warn("Los tests necesitan un proyecto Maven o Gradle")
  end
end

return M
