local M = {}

M.defaults = {
  -- Carpeta donde se sugiere crear proyectos nuevos.
  projects_dir = "~/Projects",
  -- Versión de Java para proyectos nuevos. nil = detectar la del `java` instalado.
  java_version = nil,
  -- groupId sugerido para proyectos nuevos.
  group_id = "com.example",
  -- Ejecutar el main con `java` directamente (classpath en caché, compila solo si hay cambios).
  -- false = usar siempre `mvn compile exec:java` (más lento, pero es el camino "oficial" de Maven).
  fast_run = true,
  -- Comando de Maven. nil = `mvnd` si está instalado, si no `mvn`.
  maven = nil,
  -- Terminal donde se ejecuta todo: position = "bottom" | "right", size = fracción de la pantalla.
  terminal = { position = "bottom", size = 0.4 },
  -- Atajos. false para no crear ninguno.
  keymaps = { prefix = "<leader>j" },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  if opts and opts.keymaps == false then
    M.options.keymaps = false
  end
  M.options.projects_dir = vim.fn.expand(M.options.projects_dir)
end

return M
