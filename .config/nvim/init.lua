require("config.lazy")

require'nvim-treesitter.configs'.setup {
  highlight = {
    enable = true,
  },
}

require("nvim-dap-virtual-text").setup()

