-- Editor options — mirrors ~/.config/helix/config.toml

local o = vim.opt

o.number = true
o.relativenumber = true            -- line-number = "relative"
o.mouse = "a"                      -- mouse = true
o.cursorline = true                -- cursorline = true
o.termguicolors = true             -- true-color = true
o.colorcolumn = "120"              -- rulers = [120]
o.signcolumn = "yes"
o.updatetime = 50                  -- idle-timeout = 50
o.timeoutlen = 400
o.scrolloff = 5                    -- helix default
o.wrap = false                     -- soft-wrap off
o.showmode = false                 -- mode lives in the statusline (NOR/INS/SEL)
o.laststatus = 3
o.ignorecase = true                -- helix search is smart-case
o.smartcase = true
o.hlsearch = false
o.incsearch = true
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.smartindent = true
o.undofile = true
o.swapfile = false
o.splitright = true
o.splitbelow = true
o.fillchars = { eob = " " }
o.pumheight = 12
o.completeopt = { "menu", "menuone", "noselect" }

-- cursor-shape: normal = block, insert = bar, select = underline (operator-pending)
o.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr-o:hor20"

-- [editor.whitespace]: show tabs and non-breaking spaces
o.list = true
o.listchars = { tab = "→ ", nbsp = "⍽" }

-- trim-trailing-whitespace / trim-final-newlines
vim.api.nvim_create_autocmd("BufWritePre", {
    callback = function(ev)
        if not vim.bo[ev.buf].modifiable or vim.bo[ev.buf].binary then return end
        local view = vim.fn.winsaveview()
        vim.cmd([[silent! keeppatterns %s/\s\+$//e]])
        vim.cmd([[silent! keeppatterns %s/\n\+\%$//e]])
        vim.fn.winrestview(view)
    end,
})

-- languages.toml: markdown soft-wraps (text-width 100), plain text soft-wraps
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "markdown", "text" },
    callback = function(ev)
        vim.opt_local.wrap = true
        vim.opt_local.linebreak = true
        if ev.match == "markdown" then vim.opt_local.textwidth = 100 end
        if ev.match == "text" then vim.opt_local.colorcolumn = "50,72" end
    end,
})

-- auto-save = { focus-lost = true }
vim.api.nvim_create_autocmd("FocusLost", { command = "silent! wall" })

-- Diagnostics: end-of-line-diagnostics = "hint", inline-diagnostics on the cursor line for warnings+
vim.diagnostic.config({
    severity_sort = true,
    underline = true,
    virtual_text = { severity = { min = vim.diagnostic.severity.HINT }, spacing = 4, prefix = "●" },
    float = { border = "rounded", source = true },
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = "●",
            [vim.diagnostic.severity.WARN] = "●",
            [vim.diagnostic.severity.INFO] = "●",
            [vim.diagnostic.severity.HINT] = "●",
        },
    },
})

-- Yank flash, like helix's brief selection highlight
vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function() vim.hl.on_yank({ timeout = 150 }) end,
})
