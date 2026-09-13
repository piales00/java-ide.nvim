-- java-ide.nvim: crear proyectos Java y Spring Boot, clases con su paquete, y compilar /
-- ejecutar / testear desde Neovim como en un IDE.
local M = {}

local function lazy(module, fn)
  return function(...)
    return require(module)[fn](...)
  end
end

M.new_project = lazy("java_ide.create", "new_project")
M.new_spring_project = lazy("java_ide.spring", "new_project")
M.new_class = lazy("java_ide.create", "new_class")
M.run = lazy("java_ide.run", "run")
M.run_with_args = lazy("java_ide.run", "run_with_args")
M.stop = lazy("java_ide.run", "stop")
M.toggle_terminal = lazy("java_ide.terminal", "toggle")
M.select_profile = lazy("java_ide.env", "select_profile")
M.build = lazy("java_ide.run", "build")
M.test_file = lazy("java_ide.run", "test_file")
M.test_all = lazy("java_ide.run", "test_all")
M.clean = lazy("java_ide.run", "clean")
M.package = lazy("java_ide.run", "package")
M.add_dependency = lazy("java_ide.maven", "add_dependency")
M.refresh = lazy("java_ide.maven", "refresh_lsp")

local actions = {
  -- { comando, función, tecla, descripción }
  { "JavaNewProject", "new_project", "n", "Nuevo proyecto" },
  { "JavaNewSpringProject", "new_spring_project", nil, "Nuevo proyecto Spring Boot" },
  { "JavaNewClass", "new_class", "c", "Nueva clase / interfaz / enum…" },
  { "JavaRun", "run", "r", "Ejecutar main" },
  { "JavaRunArgs", "run_with_args", "R", "Ejecutar con argumentos…" },
  { "JavaStop", "stop", "s", "Detener ejecución" },
  { "JavaTerminal", "toggle_terminal", "o", "Mostrar/ocultar terminal" },
  { "JavaProfile", "select_profile", "P", "Perfil de Spring…" },
  { "JavaBuild", "build", "b", "Compilar" },
  { "JavaTestFile", "test_file", "t", "Tests del archivo" },
  { "JavaTest", "test_all", "T", "Todos los tests" },
  { "JavaPackage", "package", "p", "Empaquetar (jar)" },
  { "JavaClean", "clean", "x", "Clean" },
  { "JavaAddDependency", "add_dependency", "d", "Agregar dependencia Maven" },
  { "JavaRefresh", "refresh", "u", "Recargar config del LSP" },
}

function M.setup(opts)
  local config = require("java_ide.config")
  config.setup(opts)

  for _, a in ipairs(actions) do
    local fn = M[a[2]]
    if a[1] == "JavaRun" then
      -- :JavaRun arg1 arg2 pasa argumentos al programa.
      vim.api.nvim_create_user_command(a[1], function(cmd)
        fn(cmd.fargs)
      end, { desc = a[4], nargs = "*" })
    else
      vim.api.nvim_create_user_command(a[1], function()
        fn()
      end, { desc = a[4] })
    end
  end

  local keymaps = config.options.keymaps
  if keymaps then
    for _, a in ipairs(actions) do
      if a[3] then
        vim.keymap.set("n", keymaps.prefix .. a[3], function()
          M[a[2]]()
        end, { desc = a[4] })
      end
    end
    local ok, wk = pcall(require, "which-key")
    if ok and wk.add then
      wk.add({ { keymaps.prefix, group = "java", icon = { icon = " ", color = "red" } } })
    end
  end
end

return M
