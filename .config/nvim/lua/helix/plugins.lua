-- Plugins (lazy.nvim). Each one stands in for something Helix has built in.

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", "https://github.com/folke/lazy.nvim.git", lazypath })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({ { "Failed to clone lazy.nvim (restart nvim to retry):\n" .. out, "ErrorMsg" } }, true, {})
        return
    end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    -- theme = "gruvbox"
    {
        "ellisonleao/gruvbox.nvim",
        lazy = false,
        priority = 1000,
        config = function()
            require("gruvbox").setup({ italic = { strings = false, emphasis = false, comments = true, operators = false, folds = false } })
            vim.o.background = "dark"
            vim.cmd.colorscheme("gruvbox")
        end,
    },

    -- Infobox that pops up after space / g / m / [ / ] — helix layout
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            preset = "helix",
            delay = 150,
            icons = { mappings = false },
            spec = {
                { "<leader>", group = "space" },
                { "<leader>G", group = "debug" },
                { "<leader>Gs", group = "switch" },
                { "g", group = "goto", mode = { "n", "x" } },
                { "m", group = "match", mode = { "n", "x" } },
                { "[", group = "left bracket", mode = { "n", "x" } },
                { "]", group = "right bracket", mode = { "n", "x" } },
            },
        },
    },

    -- Pickers (space f/b/s/d/…), file explorer (space e), indent guides, rename prompt
    {
        "folke/snacks.nvim",
        lazy = false,
        priority = 900,
        opts = {
            picker = {
                enabled = true,
                layout = { preset = "default" },
                matcher = { frecency = true },
                sources = { files = { hidden = true }, grep = { hidden = true }, explorer = { hidden = true } },
            },
            explorer = { enabled = true, replace_netrw = true },
            indent = {                                  -- [editor.indent-guides]
                enabled = true,
                indent = { char = "▏", hl = "NonText" },
                scope = { enabled = false },
                animate = { enabled = false },
            },
            input = { enabled = true },
            bigfile = { enabled = true },
        },
    },

    -- Completion: popup while typing, Tab/S-Tab cycle, Enter accepts, docs + signature help
    {
        "saghen/blink.cmp",
        version = "1.*",
        event = "InsertEnter",
        opts = {
            keymap = {
                preset = "enter",
                ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
                ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
                ["<C-n>"] = { "select_next", "fallback" },
                ["<C-p>"] = { "select_prev", "fallback" },
                ["<C-x>"] = { "show", "fallback" },      -- helix: C-x = completion
                ["<C-c>"] = { "cancel", "fallback" },
            },
            completion = {
                list = { selection = { preselect = false, auto_insert = true } },
                documentation = { auto_show = true, auto_show_delay_ms = 100, window = { border = "rounded" } },
                menu = { border = "rounded", draw = { columns = { { "label", "label_description", gap = 1 }, { "kind" } } } },
            },
            signature = { enabled = true, window = { border = "rounded" } },
            sources = { default = { "lsp", "path", "snippets", "buffer" } },
            fuzzy = { implementation = "prefer_rust" },
        },
    },

    -- Syntax tree: highlighting, indents, and the objects behind mi/ma, ]f, Alt-o
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "master",
        build = ":TSUpdate",
        lazy = false,
        dependencies = { { "nvim-treesitter/nvim-treesitter-textobjects", branch = "master" } },
        main = "nvim-treesitter.configs",
        opts = {
            ensure_installed = {
                "java", "properties", "xml", "groovy", "kotlin", "sql",
                "go", "gomod", "gosum", "gowork", "rust", "elixir", "heex", "eex",
                "lua", "luadoc", "vim", "vimdoc", "query", "bash", "fish", "python",
                "json", "yaml", "toml", "markdown", "markdown_inline", "html", "css",
                "javascript", "typescript", "tsx", "dockerfile", "make", "diff",
                "git_config", "gitcommit", "gitignore", "regex",
            },
            highlight = { enable = true },
            indent = { enable = true },
            textobjects = {
                select = { enable = true, lookahead = true },
                move = { enable = true, set_jumps = true },
            },
        },
    },

    -- Language servers come from nvim-lspconfig's server definitions (see lua/helix/lsp.lua)
    { "neovim/nvim-lspconfig", lazy = false },

    -- Formatters declared in languages.toml (e.g. gofumpt for Go)
    {
        "stevearc/conform.nvim",
        event = "BufWritePre",
        cmd = "ConformInfo",
        opts = function() return require("helix.lsp").conform_opts() end,
    },

    -- Git diff gutter + ]g / [g
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            signs = {
                add = { text = "▍" }, change = { text = "▍" }, delete = { text = "▁" },
                topdelete = { text = "▔" }, changedelete = { text = "▍" }, untracked = { text = "▍" },
            },
        },
    },

    -- Multiple selections: C, Alt-C, s, S, &, ","
    { "jake-stewart/multicursor.nvim", branch = "1.0", lazy = false, config = function() require("multicursor-nvim").setup() end },

    -- ms / mr / md surround, and auto-pairs (helix auto-pairs = true)
    {
        "echasnovski/mini.nvim",
        lazy = false,
        config = function()
            require("mini.surround").setup({
                mappings = {
                    add = "ms", delete = "md", replace = "mr",
                    find = "", find_left = "", highlight = "", update_n_lines = "",
                    suffix_last = "", suffix_next = "",
                },
                search_method = "cover_or_next",
                -- helix: ms( gives (foo), not ( foo ) — opening brackets behave like closing ones
                custom_surroundings = {
                    ["("] = { input = { "%b()", "^.().*().$" }, output = { left = "(", right = ")" } },
                    ["["] = { input = { "%b[]", "^.().*().$" }, output = { left = "[", right = "]" } },
                    ["{"] = { input = { "%b{}", "^.().*().$" }, output = { left = "{", right = "}" } },
                    ["<"] = { input = { "%b<>", "^.().*().$" }, output = { left = "<", right = ">" } },
                },
                silent = true,
            })
            require("mini.pairs").setup()
        end,
    },

    -- space G: debugger (dlv / lldb-dap / elixir-ls-debug)
    { "mfussenegger/nvim-dap", lazy = true, config = function() require("helix.dap") end },

    -- gw: jump labels on words
    {
        "folke/flash.nvim",
        lazy = true,
        opts = { modes = { search = { enabled = false }, char = { enabled = false } } },
    },

    -- Statusline: NOR / INS / SEL, like [editor.statusline]
    {
        "nvim-lualine/lualine.nvim",
        lazy = false,
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            local function mode()
                local m = vim.api.nvim_get_mode().mode
                if m:find("^i") then return "INS" end
                if m == "v" or m == "V" or m == "\22" then return require("helix.keymaps").extend and "SEL" or "NOR" end
                if m:find("^[cR]") then return m:find("^c") and "CMD" or "REP" end
                return "NOR"
            end
            local function selections()
                local ok, mc = pcall(require, "multicursor-nvim")
                local n = ok and mc.numCursors and mc.numCursors() or 1
                return n > 1 and (n .. " sel") or ""
            end
            require("lualine").setup({
                options = {
                    theme = "gruvbox",
                    globalstatus = true,
                    component_separators = "",
                    section_separators = "",
                },
                sections = {
                    lualine_a = { mode },
                    lualine_b = { { "filename", path = 1, symbols = { modified = "[+]", readonly = "[RO]" } } },
                    lualine_c = { function() return vim.lsp.status() end },
                    lualine_x = { "diagnostics", selections, "location", "encoding", "filetype" },
                    lualine_y = { "branch" },
                    lualine_z = {},
                },
            })
        end,
    },

    -- bufferline = "multiple": tabs for open buffers once there is more than one
    {
        "akinsho/bufferline.nvim",
        version = "*",
        lazy = false,
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = {
            options = {
                always_show_bufferline = false,
                show_buffer_close_icons = false,
                show_close_icon = false,
                separator_style = "thin",
                diagnostics = false,
            },
        },
    },
}, {
    install = { colorscheme = { "gruvbox", "habamax" } },
    checker = { enabled = false },
    change_detection = { notify = false },
    rocks = { enabled = false },
})
