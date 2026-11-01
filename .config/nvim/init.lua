-- Neovim, set up to behave like Helix (~/.config/helix):
-- same keymap (selection-first), theme, options and language servers.
--
--   lua/helix/options.lua   editor settings        ← config.toml [editor]
--   lua/helix/plugins.lua   plugins (lazy.nvim)
--   lua/helix/keymaps.lua   the Helix keymap
--   lua/helix/lsp.lua       language servers       ← languages.toml (read live)

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("helix.options")
require("helix.plugins")
require("helix.keymaps")
require("helix.lsp")
