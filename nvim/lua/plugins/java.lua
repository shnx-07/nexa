return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      opts.cmd = opts.cmd or {}
      -- Point jdtls explicitly to Java 25 so it never crashes with exit code 13
      local java_bin = "/usr/lib/jvm/java-25-openjdk/bin/java"
      if vim.fn.filereadable(java_bin) == 1 then
        opts.cmd = {
          vim.fn.stdpath("data") .. "/mason/bin/jdtls",
          "--jvm-arg=-javaagent:" .. vim.fn.stdpath("data") .. "/mason/packages/jdtls/lombok.jar",
          string.format("--java-executable=%s", java_bin),
        }
      end

      -- Attach custom code generator actions
      local old_on_attach = opts.on_attach
      opts.on_attach = function(args)
        if old_on_attach then
          old_on_attach(args)
        end

        local bufnr = args.buf

        local function java_source_action(action_type, title_pattern)
          local params = vim.lsp.util.make_range_params()
          params.context = {
            only = action_type and { action_type } or nil,
            diagnostics = {},
          }
          vim.lsp.buf_request(bufnr, "textDocument/codeAction", params, function(err, actions)
            if not err and actions and #actions > 0 then
              for _, a in ipairs(actions) do
                if not title_pattern or (a.title and a.title:lower():find(title_pattern)) then
                  if a.edit then
                    vim.lsp.util.apply_workspace_edit(a.edit, "utf-8")
                  elseif a.command then
                    vim.lsp.buf.execute_command(a.command)
                  end
                  return
                end
              end
            end
            -- Fallback: query all code actions and filter by pattern
            local all_params = vim.lsp.util.make_range_params()
            all_params.context = { diagnostics = {} }
            vim.lsp.buf_request(bufnr, "textDocument/codeAction", all_params, function(_, all_actions)
              if all_actions then
                for _, a in ipairs(all_actions) do
                  local t = (a.title or ""):lower()
                  if t:find(title_pattern or "constructor") then
                    if a.edit then
                      vim.lsp.util.apply_workspace_edit(a.edit, "utf-8")
                    elseif a.command then
                      vim.lsp.buf.execute_command(a.command)
                    end
                    return
                  end
                end
              end
              vim.notify("No " .. (title_pattern or "constructor") .. " action available at cursor", vim.log.levels.INFO)
            end)
          end)
        end

        local function generate_constructor()
          java_source_action("source.generate.constructors", "constructor")
        end

        local function generate_getters_setters()
          java_source_action("source.generate.accessors", "getter")
        end

        local function generate_to_string()
          java_source_action("source.generate.toString", "tostring")
        end

        -- User commands
        vim.api.nvim_buf_create_user_command(bufnr, "GenerateConstructor", generate_constructor, { desc = "Generate Java Constructor" })
        vim.api.nvim_buf_create_user_command(bufnr, "GenerateGettersSetters", generate_getters_setters, { desc = "Generate Getters and Setters" })
        vim.api.nvim_buf_create_user_command(bufnr, "GenerateToString", generate_to_string, { desc = "Generate toString()" })

        -- Keybindings (NO SPACE / NO LEADER)
        local map = function(keys, func, desc)
          vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
        end

        map("<F7>", generate_constructor, "Java: Generate Constructor")
        map("<M-c>", generate_constructor, "Java: Generate Constructor")
        map("<M-CR>", function() vim.lsp.buf.code_action() end, "Java: Quick Fix & Actions")
        map("<M-g>", generate_getters_setters, "Java: Generate Getters & Setters")
        map("<M-o>", function() require("jdtls").organize_imports() end, "Java: Organize Imports")
      end

      return opts
    end,
  },
}
