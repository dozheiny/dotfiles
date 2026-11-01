-- Language servers, formatters and format-on-save — taken from ~/.config/helix/languages.toml,
-- so Helix and Neovim always run the same servers with the same settings. Edit that file, not this one.

local api = vim.api

-- languages.toml as a Lua table (python's tomllib does the parsing; read once, on first use)
local helix
local function languages()
    if not helix then
        local out = vim.fn.system({ "python3", "-I", "-c",
            "import json, tomllib, os; print(json.dumps(tomllib.load(open(os.path.expanduser('~/.config/helix/languages.toml'), 'rb'))))" })
        helix = vim.v.shell_error == 0 and vim.json.decode(out) or {}
    end
    return helix
end
local function helix_config(name) return ((languages()["language-server"] or {})[name] or {}).config end

-- nvim-lspconfig name → helix name. Servers in helix's built-in defaults are used if installed, like Helix does.
local servers = {
    jdtls = "jdtls",
    gopls = "gopls",
    golangci_lint_ls = "golangci-lint-lsp",
    rust_analyzer = "rust-analyzer",
    elixirls = "elixir-ls",
    ty = "ty",
    ruff = "ruff",
    jedi_language_server = "jedi",
    pylsp = "pylsp",
    bashls = "bash-language-server",
    lua_ls = "lua-language-server",
    yamlls = "yaml-language-server",
    jsonls = "vscode-json-language-server",
    ts_ls = "typescript-language-server",
    marksman = "marksman",
    taplo = "taplo",
    clangd = "clangd",
    dockerls = "docker-langserver",
}

-- Java: our ~/.local/bin/jdtls wrapper (Lombok, per-project index); its own index separate from Helix's
vim.lsp.config("jdtls", {
    cmd = { "jdtls" },
    cmd_env = { JDTLS_CLIENT = "nvim" },
    root_markers = { "pom.xml", "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts", "mvnw", "gradlew", ".git" },
    init_options = { extendedClientCapabilities = { classFileContentsSupport = true } },
})
vim.lsp.config("elixirls", { cmd = { "elixir-ls" } })

for name, helix_name in pairs(servers) do
    -- servers that ask for a named settings section (jdtls/elixirls configs already carry theirs)
    local section = ({ gopls = "gopls", rust_analyzer = "rust-analyzer" })[name]
    -- keep nvim-lspconfig's own hooks for the server (rust_analyzer, clangd, … define some)
    local base = vim.lsp.config[name] or {}
    local function chain(hook, ...)
        if type(hook) == "function" then hook(...) end
        if type(hook) == "table" then for _, h in ipairs(hook) do h(...) end end
    end
    local base_before, base_init = base.before_init, base.on_init
    vim.lsp.config(name, {
        -- helix sends `config` as initializationOptions …
        before_init = function(params, config)
            chain(base_before, params, config)
            local cfg = helix_config(helix_name)
            if not cfg then return end
            params.initializationOptions = vim.tbl_deep_extend("force", params.initializationOptions or {}, cfg)
            if name == "jdtls" then params.initializationOptions.settings = cfg end
        end,
        -- … and as workspace settings
        on_init = function(client, result)
            chain(base_init, client, result)
            local cfg = helix_config(helix_name)
            if not cfg then return end
            client.settings = vim.tbl_deep_extend("force", client.settings or {}, section and { [section] = cfg } or cfg)
            client:notify("workspace/didChangeConfiguration", { settings = client.settings })
        end,
    })
    local cmd = vim.lsp.config[name] and vim.lsp.config[name].cmd
    if type(cmd) == "table" and vim.fn.executable(cmd[1]) == 1 then vim.lsp.enable(name) end
end

-- display-inlay-hints = true (global, so servers that register hints after startup — jdtls — get them too)
vim.lsp.inlay_hint.enable(true)

-- Open library classes (jdt:// links from goto-definition) as decompiled/attached source
api.nvim_create_autocmd("BufReadCmd", {
    pattern = "jdt://*",
    callback = function(ev)
        local client = vim.lsp.get_clients({ name = "jdtls" })[1]
        if not client then return end
        local res = client:request_sync("java/classFileContents", { uri = ev.match }, 10000, ev.buf)
        local text = res and res.result or ("// could not load " .. ev.match)
        vim.bo[ev.buf].modifiable = true
        api.nvim_buf_set_lines(ev.buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
        vim.bo[ev.buf].filetype = "java"
        vim.bo[ev.buf].buftype = "nofile"
        vim.bo[ev.buf].modifiable = false
        vim.lsp.buf_attach_client(ev.buf, client.id)
    end,
})

-- Formatters and auto-format, per [[language]] in languages.toml (used by conform's plugin spec)
local M = {}

function M.conform_opts()
    local formatters, by_ft, auto = {}, {}, {}
    for _, lang in ipairs(languages().language or {}) do
        if lang.formatter and lang.formatter.command then
            local id = "helix_" .. lang.name
            formatters[id] = { command = lang.formatter.command, args = lang.formatter.args or {}, stdin = true }
            by_ft[lang.name] = { id }
        end
        if lang["auto-format"] then auto[lang.name] = true end
    end
    return {
        formatters = formatters,
        formatters_by_ft = by_ft,
        default_format_opts = { lsp_format = "fallback" },
        format_on_save = function(buf)
            if auto[vim.bo[buf].filetype] then return { timeout_ms = 3000 } end
        end,
    }
end

return M
