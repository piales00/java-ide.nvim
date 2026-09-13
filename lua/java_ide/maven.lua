-- Edición del pom.xml.
local project = require("java_ide.project")
local util = require("java_ide.util")

local M = {}

-- Bloques que pueden contener <dependencies> pero NO son las dependencias del proyecto.
local NESTED = { "dependencyManagement", "build", "profiles", "reporting" }

local function nested_ranges(text)
  local ranges = {}
  for _, tag in ipairs(NESTED) do
    local from = 1
    while true do
      local s = text:find("<" .. tag .. ">", from, true)
      if not s then
        break
      end
      local _, e = text:find("</" .. tag .. ">", s, true)
      if not e then
        break
      end
      table.insert(ranges, { s, e })
      from = e + 1
    end
  end
  return ranges
end

--- Primera aparición de `needle` fuera de los bloques anidados.
local function find_top_level(text, needle, ranges)
  local from = 1
  while true do
    local s = text:find(needle, from, true)
    if not s then
      return nil
    end
    local nested = false
    for _, r in ipairs(ranges) do
      if s > r[1] and s < r[2] then
        nested = true
        break
      end
    end
    if not nested then
      return s
    end
    from = s + 1
  end
end

--- Inserta `insertion` al comienzo de la línea donde está `pos`.
local function insert_before_line(text, pos, insertion)
  local line_start = pos
  while line_start > 1 and text:sub(line_start - 1, line_start - 1) ~= "\n" do
    line_start = line_start - 1
  end
  return text:sub(1, line_start - 1) .. insertion .. text:sub(line_start)
end

--- Agrega una dependencia al texto de un pom.xml. Devuelve el nuevo texto o nil, error.
function M.insert_dependency(text, dep)
  local lines = {
    "    <dependency>",
    "      <groupId>" .. dep.group .. "</groupId>",
    "      <artifactId>" .. dep.artifact .. "</artifactId>",
    "      <version>" .. dep.version .. "</version>",
  }
  if dep.scope then
    table.insert(lines, "      <scope>" .. dep.scope .. "</scope>")
  end
  table.insert(lines, "    </dependency>")
  local block = table.concat(lines, "\n") .. "\n"

  local ranges = nested_ranges(text)
  local close = find_top_level(text, "</dependencies>", ranges)
  if close then
    return insert_before_line(text, close, block)
  end
  local anchor = find_top_level(text, "<build>", ranges) or find_top_level(text, "</project>", ranges)
  if anchor then
    return insert_before_line(text, anchor, "  <dependencies>\n" .. block .. "  </dependencies>\n\n")
  end
  return nil, "No encontré dónde insertar la dependencia en el pom.xml"
end

--- Valor de una propiedad del pom (`<name>valor</name>`), resolviendo una referencia `${otra}`.
function M.property(pom, name)
  local value = pom:match("<" .. vim.pesc(name) .. ">%s*(.-)%s*</" .. vim.pesc(name) .. ">")
  local ref = value and value:match("^%${(.+)}$")
  if ref then
    return M.property(pom, ref)
  end
  return value
end

--- Versión de Java con la que compila el proyecto, o nil.
--- (`java.version` es la propiedad que usan los proyectos de Spring Boot.)
function M.java_release(pom)
  local value = M.property(pom, "maven.compiler.release")
    or M.property(pom, "release")
    or M.property(pom, "java.version")
    or M.property(pom, "maven.compiler.source")
    or M.property(pom, "source")
  value = value and value:gsub("^1%.(%d+)$", "%1")
  return value and value:match("^%d+$") and value or nil
end

--- Clase main configurada en el pom (exec.mainClass, start-class o <mainClass>), o nil.
function M.main_class(pom)
  local value = M.property(pom, "exec.mainClass") or M.property(pom, "start-class") or M.property(pom, "mainClass")
  return value and not value:find("${", 1, true) and value or nil
end

function M.is_spring_boot(pom)
  return pom:find("org.springframework.boot", 1, true) ~= nil
end

-- Cosas del pom que `javac` solo no reproduce (código generado, módulos, filtrado de
-- recursos...). Si aparecen, se compila con Maven.
local NEEDS_MAVEN = {
  "<modules>",
  "<filtering>true",
  "<sourceDirectory>",
  "<compilerArgs>",
  "build-helper-maven-plugin",
  "kotlin-maven-plugin",
  "protobuf",
  "generated-sources",
  "maven-antrun-plugin",
}

--- Los procesadores de anotaciones configurados (ej. Lombok en proyectos de Spring Initializr)
--- se pueden usar con javac si también son dependencias: javac los encuentra en el classpath.
local function processors_in_classpath(pom)
  local processors, rest = {}, pom
  for block in pom:gmatch("<annotationProcessorPaths>(.-)</annotationProcessorPaths>") do
    for artifact in block:gmatch("<artifactId>%s*(.-)%s*</artifactId>") do
      table.insert(processors, artifact)
    end
  end
  rest = rest:gsub("<annotationProcessorPaths>.-</annotationProcessorPaths>", "")
  for _, artifact in ipairs(processors) do
    if not rest:find("<artifactId>" .. artifact .. "</artifactId>", 1, true) then
      return false
    end
  end
  return true
end

--- Spring Boot filtra application.properties/yml: `@project.version@` se reemplaza al compilar.
local function uses_resource_placeholders(root)
  local dir = root .. "/src/main/resources"
  for name, type in vim.fs.dir(dir) do
    if type == "file" and name:match("^application.*%.[%a]+$") then
      if util.read_file(dir .. "/" .. name):find("@[%w_.%-]+@") then
        return true
      end
    end
  end
  return false
end

function M.needs_maven_compile(pom, root)
  for _, needle in ipairs(NEEDS_MAVEN) do
    if pom:find(needle, 1, true) then
      return true
    end
  end
  if not processors_in_classpath(pom) then
    return true
  end
  return root ~= nil and M.is_spring_boot(pom) and uses_resource_placeholders(root)
end

function M.parse_coordinates(coords)
  local parts = vim.split(coords, ":", { plain = true })
  if #parts < 3 or #parts > 4 then
    return nil
  end
  for _, part in ipairs(parts) do
    if not part:match("^[%w_.%-]+$") then
      return nil
    end
  end
  return { group = parts[1], artifact = parts[2], version = parts[3], scope = parts[4] }
end

function M.add_dependency()
  local kind, root = project.detect()
  if kind ~= "maven" then
    return util.warn("Agregar dependencias solo está soportado en proyectos Maven")
  end

  util.ask("Dependencia (groupId:artifactId:version[:scope]): ", nil, function(coords)
    local dep = M.parse_coordinates(coords)
    if not dep then
      return util.error("Formato inválido. Ejemplo: com.google.code.gson:gson:2.11.0")
    end
    local pom = root .. "/pom.xml"
    local new, err = M.insert_dependency(util.read_file(pom), dep)
    if not new then
      return util.error(err)
    end
    util.write_file(pom, new)
    vim.cmd("checktime")
    util.notify("Agregada " .. coords)
    M.refresh_lsp()
  end)
end

--- Pide a jdtls que relea la configuración del proyecto (si nvim-jdtls está instalado).
function M.refresh_lsp()
  local ok, jdtls = pcall(require, "jdtls")
  if not ok then
    return util.warn("nvim-jdtls no está instalado; reinicia el LSP para ver los cambios")
  end
  pcall(jdtls.update_projects_config, { select_mode = "all" })
end

return M
