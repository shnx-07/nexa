local platform = require('utils.platform')

local function has_bin(name)
   if not name or name == '' then
      return false
   end
   if name:sub(1, 1) == '/' then
      local f = io.open(name, 'r')
      if f ~= nil then
         io.close(f)
         return true
      end
      return false
   end
   for _, dir in ipairs({ '/usr/local/bin/', '/usr/bin/', '/bin/' }) do
      local f = io.open(dir .. name, 'r')
      if f ~= nil then
         io.close(f)
         return true
      end
   end
   return false
end

local function get_default_shell()
   local env_shell = os.getenv('SHELL')
   if env_shell and env_shell ~= '' and has_bin(env_shell) then
      return env_shell:match('([^/]+)$') or env_shell
   end
   if has_bin('zsh') then
      return 'zsh'
   elseif has_bin('fish') then
      return 'fish'
   elseif has_bin('bash') then
      return 'bash'
   end
   return 'sh'
end

---@type Config
local options = {
   default_prog = {},
   launch_menu = {},
}

if platform.is_win then
   options.default_prog = { 'pwsh', '-NoLogo' }
   options.launch_menu = {
      { label = 'PowerShell Core', args = { 'pwsh', '-NoLogo' } },
      { label = 'PowerShell Desktop', args = { 'powershell' } },
      { label = 'Command Prompt', args = { 'cmd' } },
      { label = 'Nushell', args = { 'nu' } },
      { label = 'Msys2', args = { 'ucrt64.cmd' } },
      {
         label = 'Git Bash',
         args = { 'C:\\Users\\kevin\\scoop\\apps\\git\\current\\bin\\bash.exe' },
      },
   }
elseif platform.is_mac then
   local shell = get_default_shell()
   options.default_prog = { shell, '-l' }
   options.launch_menu = {
      { label = 'Zsh', args = { 'zsh', '-l' } },
      { label = 'Fish', args = { 'fish', '-l' } },
      { label = 'Bash', args = { 'bash', '-l' } },
      { label = 'Nushell', args = { 'nu', '-l' } },
   }
elseif platform.is_linux then
   local shell = get_default_shell()
   options.default_prog = { shell, '-l' }
   options.launch_menu = {
      { label = 'Zsh', args = { 'zsh', '-l' } },
      { label = 'Fish', args = { 'fish', '-l' } },
      { label = 'Bash', args = { 'bash', '-l' } },
   }
end

return options

