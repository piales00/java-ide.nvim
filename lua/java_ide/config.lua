local M = {}

M.defaults = {
  -- Carpeta donde se sugiere crear proyectos nuevos.
  projects_dir = "~/Projects",
  -- Versión de Java para proyectos nuevos. nil = detectar la del `java` instalado.
  java_version = nil,
  -- groupId sugerido para proyectos nuevos.
  group_id = "com.example",
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
