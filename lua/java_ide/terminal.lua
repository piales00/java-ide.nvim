-- Terminal de ejecución reutilizable: cada ejecución reemplaza a la anterior
-- en la misma ventana, así nunca se acumulan terminales ni se "togglea" cerrando.
local M = {}

local state = { win = nil, buf = nil }

local function open_window(config)
  local term = config.options.terminal
  if term.position == "right" then
    vim.cmd("botright vsplit")
    vim.api.nvim_win_set_width(0, math.floor(vim.o.columns * term.size))
  else
    vim.cmd("botright split")
    vim.api.nvim_win_set_height(0, math.floor(vim.o.lines * term.size))
  end
  return vim.api.nvim_get_current_win()
end

function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

--- Ejecuta `cmd` (lista de argumentos) en `cwd` dentro de la terminal.
function M.run(cmd, cwd)
  local config = require("java_ide.config")

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
  else
    state.win = open_window(config)
  end

  local old = state.buf
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(state.win, buf)
  state.buf = buf

  if old and vim.api.nvim_buf_is_valid(old) then
    local job = vim.b[old].terminal_job_id
    if job then
      pcall(vim.fn.jobstop, job)
    end
    pcall(vim.api.nvim_buf_delete, old, { force = true })
  end

  if vim.fn.has("nvim-0.11") == 1 then
    vim.fn.jobstart(cmd, { cwd = cwd, term = true })
  else
    vim.fn.termopen(cmd, { cwd = cwd })
  end

  vim.keymap.set("n", "q", M.close, { buffer = buf, nowait = true, desc = "Cerrar terminal" })
  vim.cmd.startinsert()
end

return M
