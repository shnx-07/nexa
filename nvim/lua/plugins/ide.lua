return {
  -- Universal syntax highlighting with automatic language grammar installation
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.auto_install = true
      opts.highlight = opts.highlight or {}
      opts.highlight.enable = true
      opts.indent = opts.indent or {}
      opts.indent.enable = true
      opts.matchup = opts.matchup or {}
      opts.matchup.enable = true
    end,
  },

  -- Bracket-to-bracket jumper (%) for brackets, HTML/XML tags, and language control keywords
  {
    "andymass/vim-matchup",
    event = "BufReadPost",
    init = function()
      vim.g.matchup_matchparen_offscreen = { method = "popup" }
      vim.g.matchup_matchparen_deferred = 1
    end,
  },

  -- Color-coded bracket pairs for complex nested expressions
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = "BufReadPost",
  },

  -- Language-aware commenting for embedded languages (e.g. JSX, HTML/CSS/JS, SQL in Python)
  {
    "JoosepAlviste/nvim-ts-context-commentstring",
    opts = {
      enable_autocmd = false,
    },
  },

  -- Automatic Word Occurrences Highlighter (Normal Cursor Word + Visual Selection)
  {
    "RRethy/vim-illuminate",
    event = "BufReadPost",
    opts = {
      delay = 100,
      under_cursor = true,
      filetypes_denylist = {
        "dirbuf",
        "dirvish",
        "fugitive",
        "neo-tree",
        "TelescopePrompt",
        "snacks_picker_input",
      },
    },
    config = function(_, opts)
      require("illuminate").configure(opts)

      -- Clean visual highlights for matching words across the file
      vim.api.nvim_set_hl(0, "IlluminatedWordText", { bg = "#383e4a", underline = true })
      vim.api.nvim_set_hl(0, "IlluminatedWordRead", { bg = "#383e4a", underline = true })
      vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { bg = "#383e4a", underline = true })
      vim.api.nvim_set_hl(0, "VisualWordHighlight", { bg = "#444b58", underline = true, bold = true })

      -- Real-time Visual Selection Highlighter:
      -- Selecting any word or phrase in visual mode instantly highlights all identical occurrences
      local match_id = nil
      local augroup = vim.api.nvim_create_augroup("VisualSelectHighlighter", { clear = true })

      local function clear_match()
        if match_id then
          pcall(vim.fn.matchdelete, match_id)
          match_id = nil
        end
      end

      vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged" }, {
        group = augroup,
        callback = function()
          local mode = vim.fn.mode()
          if mode == "v" or mode == "V" or mode == "\22" then
            local vpos = vim.fn.getpos("v")
            local cpos = vim.fn.getpos(".")
            local s_row, s_col = vpos[2], vpos[3]
            local e_row, e_col = cpos[2], cpos[3]

            if s_row > e_row or (s_row == e_row and s_col > e_col) then
              s_row, e_row = e_row, s_row
              s_col, e_col = e_col, s_col
            end

            if s_row == e_row and math.abs(e_col - s_col) >= 1 then
              local line = vim.api.nvim_get_current_line()
              local text = line:sub(s_col, e_col)
              text = text:gsub("^%s+", ""):gsub("%s+$", "")
              if #text >= 2 then
                clear_match()
                local pattern = "\\V" .. vim.fn.escape(text, "\\")
                match_id = vim.fn.matchadd("VisualWordHighlight", pattern, -1)
                return
              end
            end
          end
          clear_match()
        end,
      })
    end,
  },

  -- Debugger (DAP) Visual Signs & Highlights
  {
    "mfussenegger/nvim-dap",
    opts = function()
      vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#e51400" })
      vim.api.nvim_set_hl(0, "DapBreakpointCondition", { fg = "#fd971f" })
      vim.api.nvim_set_hl(0, "DapLogPoint", { fg = "#61afef" })
      vim.api.nvim_set_hl(0, "DapStopped", { fg = "#98c379", bg = "#252836" })

      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DapBreakpoint", linehl = "", numhl = "" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DapBreakpointCondition", linehl = "", numhl = "" })
      vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DapLogPoint", linehl = "", numhl = "" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DapStopped", linehl = "DapStopped", numhl = "DapStopped" })
    end,
  },

  -- Live Virtual Text for Debugger: prints variable values & results directly inline in code
  {
    "theHamsta/nvim-dap-virtual-text",
    opts = {
      enabled = true,
      enabled_commands = true,
      highlight_changed_variables = true,
      highlight_new_as_changed = true,
      show_stop_reason = true,
      commented = false,
      only_first_definition = false,
      all_references = true,
      display_callback = function(variable, _buf, _stackframe, _node, options)
        if options.virt_text_pos == "inline" then
          return " = " .. variable.value
        else
          return variable.name .. " = " .. variable.value
        end
      end,
    },
  },

  -- Visual DAP UI: Shows Scopes (Variables/Locals), Watches, Stacks, Breakpoints & REPL
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "nvim-neotest/nvim-nio" },
    opts = {
      layouts = {
        {
          elements = {
            { id = "scopes", size = 0.40 },   -- Variables (Locals & Globals live inspection)
            { id = "watches", size = 0.25 },  -- Custom watch expressions
            { id = "stacks", size = 0.20 },   -- Call stack
            { id = "breakpoints", size = 0.15 }, -- Active breakpoints list
          },
          position = "left",
          size = 45,
        },
        {
          elements = {
            { id = "repl", size = 0.5 },      -- Interactive evaluation REPL
            { id = "console", size = 0.5 },   -- Terminal output
          },
          position = "bottom",
          size = 12,
        },
      },
    },
  },
}
