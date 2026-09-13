-- :checkhealth java_ide
local M = {}

local function check_exe(name, required, advice)
  if vim.fn.executable(name) == 1 then
    vim.health.ok(name .. " encontrado")
  elseif required then
    vim.health.error(name .. " no encontrado", advice)
  else
    vim.health.warn(name .. " no encontrado", advice)
  end
end

function M.check()
  vim.health.start("java-ide.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim >= 0.10")
  else
    vim.health.error("Se necesita Neovim >= 0.10")
  end

  check_exe("java", true, "Instalá un JDK (17 o superior)")
  check_exe("javac", true, "Instalá un JDK completo, no solo el JRE")
  local version = require("java_ide.util").java_major_version()
  if version then
    vim.health.info("Versión de Java: " .. version)
  end
  check_exe("mvn", false, "Necesario para proyectos Maven")
  check_exe("gradle", false, "Opcional: los proyectos con ./gradlew no lo necesitan")

  if pcall(require, "jdtls") then
    vim.health.ok("nvim-jdtls instalado (autocompletado, errores, refactors)")
  else
    vim.health.warn("nvim-jdtls no instalado", "Recomendado para tener LSP: https://github.com/mfussenegger/nvim-jdtls")
  end
end

return M
