-- Terminal de ejecución reutilizable: cada ejecución reemplaza a la anterior en la misma
-- ventana. Cerrar la ventana no detiene el proceso (útil para una API que queda corriendo).
local M = {}

local state = { win = nil, buf = nil }

-- Tiempo máximo para que el proceso anterior termine (por ejemplo, que una API libere el puerto).
local STOP_TIMEOUT_MS = 5000

local function open_window(buf)
  local term = require("java_ide.config").options.terminal
  if term.position == "right" then
    vim.cmd("botright vsplit")
    vim.api.nvim_win_set_width(0, math.floor(vim.o.columns * term.size))
  else
    vim.cmd("botright split")
    vim.api.nvim_win_set_height(0, math.floor(vim.o.lines * term.size))
  end
  state.win = vim.api.nvim_get_current_win()
  if buf then
    vim.api.nvim_win_set_buf(state.win, buf)
  end
end

local function win_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

local function current_job()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    local job = vim.b[state.buf].terminal_job_id
    if job and vim.fn.jobwait({ job }, 0)[1] == -1 then
      return job
    end
  end
end

--- ¿Hay un proceso ejecutándose?
function M.is_running()
  return current_job() ~= nil
end

--- Detiene el proceso actual y espera a que termine. Devuelve true si había uno.
function M.stop()
  local job = current_job()
  if not job then
    return false
  end
  vim.fn.jobstop(job)
  vim.fn.jobwait({ job }, STOP_TIMEOUT_MS)
  return true
end

--- Cierra la ventana; el proceso sigue ejecutándose.
function M.close()
  if win_open() then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

--- Muestra u oculta la terminal de la última ejecución.
function M.toggle()
  if win_open() then
    return M.close()
  end
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    return require("java_ide.util").warn("Todavía no ejecutaste nada")
  end
  open_window(state.buf)
  vim.cmd("normal! G")
end

--- Ejecuta `cmd` (lista de argumentos) en `cwd`, con variables de entorno extra `env`.
function M.run(cmd, cwd, env)
  M.stop()

  if win_open() then
    vim.api.nvim_set_current_win(state.win)
  else
    open_window()
  end

  local old = state.buf
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(state.win, buf)
  state.buf = buf
  if old and vim.api.nvim_buf_is_valid(old) then
    pcall(vim.api.nvim_buf_delete, old, { force = true })
  end

  local opts = { cwd = cwd, env = (env and next(env)) and env or nil }
  if vim.fn.has("nvim-0.11") == 1 then
    opts.term = true
    vim.fn.jobstart(cmd, opts)
  else
    vim.fn.termopen(cmd, opts)
  end

  vim.keymap.set("n", "q", M.close, { buffer = buf, nowait = true, desc = "Cerrar terminal (sigue ejecutándose)" })
  vim.cmd.startinsert()
end

return M
