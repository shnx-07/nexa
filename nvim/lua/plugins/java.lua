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
      return opts
    end,
  },
}
