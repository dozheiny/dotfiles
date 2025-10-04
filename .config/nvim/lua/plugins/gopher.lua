return -- NOTE: this plugin is already lazy-loaded, it adds only about 1ms of load
-- time to your config
{
  "olexsmir/gopher.nvim",
  ft = "go",
  -- branch = "develop"
  -- (optional) will update plugin's deps on every update
  build = function()
    vim.cmd.GoInstallDeps()
  end,
  ---@module "gopher"
  ---@type gopher.Config
  opts = {},
}
