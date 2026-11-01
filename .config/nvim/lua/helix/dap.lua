-- Debugging (nvim-dap) — same adapters and launch templates as Helix's `space G` menu:
-- Go → dlv, Rust → lldb-dap, Elixir → elixir-ls-debug (see languages.toml).

local dap = require("dap")

vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DiagnosticInfo" })
vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticOk", linehl = "CursorLine" })

-- Go
dap.adapters.delve = {
    type = "server",
    port = "${port}",
    executable = { command = "dlv", args = { "dap", "-l", "127.0.0.1:${port}" } },
}
dap.configurations.go = {
    { type = "delve", name = "source (package)", request = "launch", program = "${fileDirname}" },
    { type = "delve", name = "test (package)", request = "launch", mode = "test", program = "${fileDirname}" },
    { type = "delve", name = "main module", request = "launch", program = "${workspaceFolder}" },
    { type = "delve", name = "attach", request = "attach", mode = "local", processId = require("dap.utils").pick_process },
}

-- Rust (Rust's own lldb pretty-printers, so Vec/String/HashMap show as values)
dap.adapters["lldb-dap"] = { type = "executable", command = "lldb-dap", name = "lldb-dap" }
local rust_init = {}
local sysroot = vim.fn.trim(vim.fn.system({ "rustc", "--print", "sysroot" }))
if vim.v.shell_error == 0 then
    rust_init = { ('command script import "%s/lib/rustlib/etc/lldb_lookup.py"'):format(sysroot) }
end
dap.configurations.rust = {
    {
        type = "lldb-dap",
        name = "binary",
        request = "launch",
        program = function() return vim.fn.input("Binary: ", vim.fn.getcwd() .. "/target/debug/", "file") end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        initCommands = rust_init,
    },
    { type = "lldb-dap", name = "attach", request = "attach", pid = require("dap.utils").pick_process, initCommands = rust_init },
}

-- Elixir
dap.adapters.mix_task = { type = "executable", command = "elixir-ls-debug" }
dap.configurations.elixir = {
    {
        type = "mix_task", name = "mix test (file)", request = "launch",
        task = "test", taskArgs = { "${file}", "--trace" }, startApps = true,
        requireFiles = { "test/**/test_helper.exs", "${file}" }, projectDir = "${workspaceFolder}",
    },
    { type = "mix_task", name = "mix phx.server", request = "launch", task = "phx.server", startApps = true, projectDir = "${workspaceFolder}" },
    { type = "mix_task", name = "mix run", request = "launch", task = "run", taskArgs = { "--no-halt" }, startApps = true, projectDir = "${workspaceFolder}" },
}
