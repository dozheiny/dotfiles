-- The Helix keymap, on top of Neovim.
--
-- Model: a Helix selection is a Visual selection; a 1-char selection is plain Normal mode.
--   w/b/e/f/t/x/%/mi… SELECT, then d/c/y/r/>/… ACT on the selection (no vim operators).
--   v toggles extend ("SEL") mode: motions grow the selection instead of replacing it.
-- Reference: https://docs.helix-editor.com/keymap.html

local M = { extend = false }

local api = vim.api
local map = vim.keymap.set

local function t(keys) return api.nvim_replace_termcodes(keys, true, false, true) end
-- "i": put keys at the front of the typeahead, so they run before anything already queued
-- (macros, fast typing) — appending would let the next key act before the selection exists
local function feed(keys, remap) api.nvim_feedkeys(t(keys), (remap and "m" or "n") .. "i", false) end
local function visual() local m = api.nvim_get_mode().mode; return m == "v" or m == "V" or m == "\22" end
local function mc() return require("multicursor-nvim") end

-- Leaving Visual mode ends extend mode too
api.nvim_create_autocmd("ModeChanged", {
    pattern = "[vV\x16]*:[^vV\x16]*",
    callback = function() M.extend = false end,
})


------------------------------------------------------------------------
-- Selection primitives (positions are { row (1-based), col (0-based byte) })
------------------------------------------------------------------------

local function line(r) return api.nvim_buf_get_lines(0, r - 1, r, false)[1] or "" end
local function last_row() return api.nvim_buf_line_count(0) end
local function char(p) local l = line(p[1]); return p[2] < #l and l:sub(p[2] + 1, p[2] + 1) or "\n" end
local function before(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end

local function next_pos(p)
    if p[2] < #line(p[1]) then return { p[1], p[2] + 1 } end
    if p[1] < last_row() then return { p[1] + 1, 0 } end
end

local function prev_pos(p)
    if p[2] > 0 then return { p[1], p[2] - 1 } end
    if p[1] > 1 then return { p[1] - 1, #line(p[1] - 1) } end
end

-- Character class: "space" (incl. line ends), "word" (letters, digits, _, non-ASCII), "punct"
local function class(c, long)
    if c == "\n" or c:match("%s") then return "space" end
    if long or c:match("[%w_]") or c:byte() >= 0x80 then return "word" end
    return "punct"
end

-- Current selection: anchor, head
local function selection()
    local head = api.nvim_win_get_cursor(0)
    if not visual() then return head, head end
    local v = vim.fn.getpos("v")
    return { v[2], v[3] - 1 }, head
end

-- Make anchor..head the (charwise) selection.
-- Stays inside Visual mode when already there (moves one end, `o`, moves the other), so
-- extend mode and the Alt-o history survive — leaving Visual would reset both.
local function select(anchor, head)
    local function to(p) return ("<Cmd>call cursor(%d,%d)<CR>"):format(p[1], p[2] + 1) end
    if anchor[1] == head[1] and anchor[2] == head[2] and not M.extend then
        feed((visual() and "<Esc>" or "") .. to(head))
        return
    end
    local mode = api.nvim_get_mode().mode
    if mode == "v" then
        feed(to(anchor) .. "o" .. to(head))
    elseif mode == "V" or mode == "\22" then
        feed("v" .. to(anchor) .. "o" .. to(head))
    else
        feed(to(anchor) .. "v" .. to(head))
    end
end

-- Word motions. Each returns the new (anchor, head) given where the motion starts.
local motions = {}

-- w / W: from start to just before the next word
function motions.next_start(start, long)
    local p = start
    if char(p) == "\n" then                    -- at a line end: continue on the next line
        p = next_pos(p)
        if not p then return start, start end
        while char(p):match("^[ \t]$") and next_pos(p) do p = next_pos(p) end
        start = p
    end
    local function skip(cond)                  -- advance while cond holds, without leaving the line
        while cond(char(p)) do
            local n = next_pos(p)
            if not n or n[1] ~= p[1] then return end
            p = n
        end
    end
    local c = class(char(p), long)
    if c ~= "space" then skip(function(ch) return ch ~= "\n" and class(ch, long) == c end) end
    skip(function(ch) return ch == " " or ch == "\t" end)
    -- p is on the next word (or the line end); the selection stops just before it
    return start, before(start, p) and prev_pos(p) or p
end

-- e / E: from start to the end of the next word
function motions.next_end(start, long)
    local p = start
    while class(char(p), long) == "space" do
        local n = next_pos(p)
        if not n then return start, p end
        p = n
    end
    local c = class(char(p), long)
    while true do
        local n = next_pos(p)
        if not n or char(n) == "\n" or class(char(n), long) ~= c then break end
        p = n
    end
    return start, p
end

-- b / B: from start back to the beginning of the previous word
function motions.prev_start(start, long)
    local p = start
    while class(char(p), long) == "space" do
        local n = prev_pos(p)
        if not n then return start, p end
        p = n
    end
    local c = class(char(p), long)
    while true do
        local n = prev_pos(p)
        if not n or char(n) == "\n" or class(char(n), long) ~= c then break end
        p = n
    end
    return start, p
end

local function word_motion(kind, long)
    return function()
        local anchor, head = selection()
        local a, h, has_sel = anchor, head, visual()
        for _ = 1, vim.v.count1 do
            local start = h
            if kind == "prev_start" then
                -- the char under a 1-wide cursor is not part of a backward motion (helix ranges are half-open)
                if not has_sel or before(h, a) then start = prev_pos(h) or h end
            elseif has_sel and not before(h, a) then
                start = next_pos(h) or h                    -- a selection ends after its head
            elseif kind == "next_end" then
                local n = next_pos(h)                       -- already at a word end: go to the next one
                if n and class(char(n), long) ~= class(char(h), long) then start = n end
            end
            local na, nh = motions[kind](start, long)
            -- at the very end/start of the buffer there is nowhere to go: keep the current selection
            if not (na[1] == nh[1] and na[2] == nh[2] and has_sel) then a, h = na, nh end
            has_sel = true
        end
        select(M.extend and anchor or a, h)
    end
end

-- f/t/F/T: select to (or till) the next/previous occurrence of a character on the line
local function find_char(forward, till)
    return function()
        local ok, ch = pcall(vim.fn.getcharstr)
        if not ok or ch == t("<Esc>") then return end
        local anchor, head = selection()
        local l = line(head[1])
        local col                                   -- 1-based byte index of the match
        if forward then
            local from = head[2] + 2                -- the char after the cursor
            for _ = 1, vim.v.count1 do
                col = l:find(ch, from, true)
                if not col then return end
                from = col + 1
            end
            col = till and col - 1 or col + #ch - 1
        else
            local stop = head[2]                    -- search text before the cursor
            for _ = 1, vim.v.count1 do
                local found
                for i = stop - #ch + 1, 1, -1 do
                    if l:sub(i, i + #ch - 1) == ch then found = i; break end
                end
                if not found then return end
                col, stop = found, found - 1
            end
            col = till and col + #ch or col
        end
        select(M.extend and anchor or head, { head[1], col - 1 })
    end
end

-- Movement that collapses the selection (unless extending)
local function move(keys)
    return function()
        local count = vim.v.count > 0 and tostring(vim.v.count) or ""
        if visual() and not M.extend then return "<Esc>" .. count .. keys end
        return count .. keys
    end
end


------------------------------------------------------------------------
-- Tree-sitter selections: Alt-o expand, Alt-i shrink, Alt-n / Alt-p siblings
------------------------------------------------------------------------

local ts_history = {}

local function sel_range()
    local a, h = selection()
    if before(h, a) then a, h = h, a end
    if api.nvim_get_mode().mode == "V" then a = { a[1], 0 }; h = { h[1], math.max(#line(h[1]) - 1, 0) } end
    return a, h
end

local function node_bounds(node)
    local sr, sc, er, ec = node:range()     -- 0-based, end exclusive
    if ec == 0 and er > sr then
        er = er - 1
        ec = #line(er + 1)
    end
    return { sr + 1, sc }, { er + 1, math.max(ec - 1, 0) }
end

local function covers(node, s, e)
    local ns, ne = node_bounds(node)
    return not before(s, ns) and not before(ne, e) and (before(ns, s) or before(e, ne))
end

local function ts_node(s)
    local ok, node = pcall(vim.treesitter.get_node, { pos = { s[1] - 1, s[2] }, ignore_injections = false })
    return ok and node or nil
end

local function ts_expand()
    local s, e = sel_range()
    local node = ts_node(s)
    while node and not covers(node, s, e) do node = node:parent() end
    if not node then return end
    table.insert(ts_history, { s, e })
    local ns, ne = node_bounds(node)
    select(ns, ne)
end

local function ts_shrink()
    local prev = table.remove(ts_history)
    if prev then select(prev[1], prev[2]) end
end

local function ts_sibling(forward)
    local s, e = sel_range()
    local node = ts_node(s)
    while node and node:parent() do
        local ns, ne = node_bounds(node)
        if not before(s, ns) and not before(ne, e) then break end
        node = node:parent()
    end
    local sib = node and (forward and node:next_named_sibling() or node:prev_named_sibling())
    if sib then
        local ns, ne = node_bounds(sib)
        select(ns, ne)
    end
end

api.nvim_create_autocmd("ModeChanged", { pattern = "*:n", callback = function() ts_history = {} end })


------------------------------------------------------------------------
-- Text objects for mi / ma (and ]f, [t …)
------------------------------------------------------------------------

-- helix object key → tree-sitter capture (others fall through to vim's built-in objects)
local ts_objects = { f = "function", t = "class", a = "parameter", c = "comment", T = "test" }
-- helix keys that differ from vim's: x = (X)HTML tag, m = closest pair
local vim_objects = { x = "t", m = "b" }

local function textobject(around)
    return function()
        local ok, key = pcall(vim.fn.getcharstr)
        if not ok or key == t("<Esc>") then return end
        local capture = ts_objects[key]
        if capture then
            local query = "@" .. capture .. (around and ".outer" or ".inner")
            require("nvim-treesitter.textobjects.select").select_textobject(query, "textobjects", "v")
        else
            feed((visual() and "" or "v") .. (around and "a" or "i") .. (vim_objects[key] or key))
        end
    end
end

local function ts_move(fn, capture)
    return function()
        require("nvim-treesitter.textobjects.move")[fn]("@" .. capture .. ".outer")
    end
end


------------------------------------------------------------------------
-- Small actions
------------------------------------------------------------------------

local function toggle_comment()
    local s, e = sel_range()
    require("vim._comment").toggle_lines(s[1], e[1])
end

local function lsp_format()
    if visual() then
        local s, e = sel_range()
        vim.lsp.buf.format({ range = { start = { s[1], s[2] }, ["end"] = { e[1], e[2] + 1 } } })
        feed("<Esc>")
    else
        require("conform").format({ lsp_format = "fallback" })
    end
end

-- * : use the selection (or word) as the search pattern, without moving
local function search_selection()
    local text
    if visual() then
        local s, e = sel_range()
        text = table.concat(api.nvim_buf_get_text(0, s[1] - 1, s[2], e[1] - 1, e[2] + 1, {}), "\n")
        text = "\\V" .. vim.fn.escape(text, "\\"):gsub("\n", "\\n")
    else
        text = "\\<" .. vim.fn.expand("<cword>") .. "\\>"
    end
    vim.fn.setreg("/", text)
    vim.v.searchforward = 1
end

local function root()
    return vim.fs.root(0, { ".git", ".helix", "pom.xml", "build.gradle", "build.gradle.kts", "go.mod", "Cargo.toml", "mix.exs" })
        or vim.uv.cwd()
end

local function picker(name, opts) return function() Snacks.picker[name](opts and opts() or nil) end end


------------------------------------------------------------------------
-- Keymap
------------------------------------------------------------------------

-- Neovim's own LSP defaults (grn, gra, grr, gri, grt, gO) would shadow helix's goto keys
for _, m in ipairs({ { "n", "grn" }, { "n", "gra" }, { "x", "gra" }, { "n", "grr" }, { "n", "gri" }, { "n", "grt" }, { "n", "gO" },
    { "n", "gc" }, { "x", "gc" }, { "o", "gc" }, { "n", "gcc" } }) do
    pcall(vim.keymap.del, m[1], m[2])
end

local nx = { "n", "x" }

-- Movement (collapses the selection; extends in SEL mode)
for _, k in ipairs({ "h", "j", "k", "l", "<Left>", "<Right>", "<Up>", "<Down>", "<Home>", "<End>",
    "<C-u>", "<C-d>", "<C-b>", "<C-f>", "<PageUp>", "<PageDown>", "G" }) do
    map("x", k, move(k), { expr = true })
end
map(nx, "w", word_motion("next_start"), { desc = "next word start" })
map(nx, "e", word_motion("next_end"), { desc = "next word end" })
map(nx, "b", word_motion("prev_start"), { desc = "previous word start" })
map(nx, "W", word_motion("next_start", true), { desc = "next WORD start" })
map(nx, "E", word_motion("next_end", true), { desc = "next WORD end" })
map(nx, "B", word_motion("prev_start", true), { desc = "previous WORD start" })
map(nx, "f", find_char(true, false), { desc = "find next char" })
map(nx, "t", find_char(true, true), { desc = "till next char" })
map(nx, "F", find_char(false, false), { desc = "find previous char" })
map(nx, "T", find_char(false, true), { desc = "till previous char" })
map(nx, "<C-s>", "m'", { desc = "save to jumplist" })

-- Selection
map("n", "v", function() M.extend = true; return "v" end, { expr = true, desc = "select (extend) mode" })
map("x", "v", function() M.extend = not M.extend; vim.cmd.redrawstatus() end, { desc = "toggle extend mode" })
map("n", "x", "V", { desc = "select line" })
map("x", "x", function()
    local m = api.nvim_get_mode().mode
    if m ~= "V" then return "V" end
    local anchor, head = selection()
    return (head[1] < anchor[1] and "o" or "") .. "j"
end, { expr = true, desc = "extend line below" })
map("n", "X", "V", { desc = "extend to line bounds" })
map("x", "X", function() return api.nvim_get_mode().mode == "V" and "" or "V" end, { expr = true, desc = "extend to line bounds" })
map(nx, "%", function() feed((visual() and "<Esc>" or "") .. "ggvG$") end, { desc = "select all" })
map("x", ";", "<Esc>", { desc = "collapse selection" })
map("n", ";", "<Nop>")
map("x", "<M-;>", "o", { desc = "flip selection" })
map(nx, "<M-o>", ts_expand, { desc = "expand selection" })
map(nx, "<M-Up>", ts_expand, { desc = "expand selection" })
map(nx, "<M-i>", ts_shrink, { desc = "shrink selection" })
map(nx, "<M-Down>", ts_shrink, { desc = "shrink selection" })
map(nx, "<M-n>", function() ts_sibling(true) end, { desc = "select next sibling" })
map(nx, "<M-Right>", function() ts_sibling(true) end, { desc = "select next sibling" })
map(nx, "<M-p>", function() ts_sibling(false) end, { desc = "select previous sibling" })
map(nx, "<M-Left>", function() ts_sibling(false) end, { desc = "select previous sibling" })

-- Multiple selections
map(nx, "C", function() mc().lineAddCursor(1) end, { desc = "copy selection to next line" })
map(nx, "<M-C>", function() mc().lineAddCursor(-1) end, { desc = "copy selection to previous line" })
map("x", "s", function() mc().matchCursors() end, { desc = "select regex matches" })
map("n", "s", "<Nop>")
map("x", "S", function() mc().splitCursors() end, { desc = "split selection on regex" })
map(nx, "&", function() mc().alignCursors() end, { desc = "align selections" })
map(nx, ",", function() mc().clearCursors() end, { desc = "keep primary selection" })
map(nx, "<C-q>", function() mc().toggleCursor() end, { desc = "toggle a cursor here" })
mc().addKeymapLayer(function(layer)
    layer("n", "<Esc>", function()
        if not mc().cursorsEnabled() then mc().enableCursors() else mc().clearCursors() end
    end)
    layer(nx, "(", mc().prevCursor)
    layer(nx, ")", mc().nextCursor)
    layer(nx, "<M-,>", mc().deleteCursor)
end)

-- Changes
map("n", "d", "x", { desc = "delete selection" })
map("x", "d", "d", { desc = "delete selection" })
map("n", "<M-d>", '"_x', { desc = "delete (no yank)" })
map("x", "<M-d>", '"_d', { desc = "delete (no yank)" })
map("n", "c", "s", { desc = "change selection" })
map("x", "c", "c", { desc = "change selection" })
map("n", "<M-c>", '"_s', { desc = "change (no yank)" })
map("x", "<M-c>", '"_c', { desc = "change (no yank)" })
map("n", "y", "yl", { desc = "yank selection" })
map("x", "y", "ygv", { desc = "yank selection" })
map("x", "p", "<Esc>`>p", { desc = "paste after selection" })
map("x", "P", "<Esc>`<P", { desc = "paste before selection" })
map("n", "R", "vP", { desc = "replace with yanked" })
map("x", "R", "P", { desc = "replace with yanked" })
map("n", "`", "vu<Esc>", { desc = "lowercase" })
map("x", "`", "u", { desc = "lowercase" })
map("n", "<M-`>", "vU<Esc>", { desc = "uppercase" })
map("x", "<M-`>", "U", { desc = "uppercase" })
map("x", "i", "<Esc>`<i", { desc = "insert before selection" })
map("x", "a", "<Esc>`>a", { desc = "append after selection" })
map("x", "I", "<Esc>I", { desc = "insert at line start" })
map("x", "A", "<Esc>A", { desc = "append at line end" })
map("x", "o", "<Esc>o", { desc = "open line below" })
map("x", "O", "<Esc>O", { desc = "open line above" })
map("x", "u", "<Esc>u", { desc = "undo" })
map(nx, "U", function() return (visual() and "<Esc>" or "") .. "<C-r>" end, { expr = true, desc = "redo" })
map("n", "<M-u>", "g-", { desc = "earlier" })
map("n", "<M-U>", "g+", { desc = "later" })
map("n", ">", ">>", { desc = "indent" })
map("n", "<", "<<", { desc = "unindent" })
map("x", ">", ">gv", { desc = "indent" })
map("x", "<", "<gv", { desc = "unindent" })
map(nx, "=", lsp_format, { desc = "format selection" })
map(nx, "<C-c>", toggle_comment, { desc = "toggle comment" })
map("n", "Q", function() return vim.fn.reg_recording() ~= "" and "q" or "qq" end, { expr = true, desc = "record macro" })
map("n", "q", "@q", { desc = "replay macro" })

-- Search: n / N select the next match
map("n", "n", "ngn", { desc = "select next match" })
map("n", "N", "NgN", { desc = "select previous match" })
map("x", "n", function() return M.extend and "n" or "<Esc>ngn" end, { expr = true, desc = "select next match" })
map("x", "N", function() return M.extend and "N" or "<Esc>NgN" end, { expr = true, desc = "select previous match" })
map(nx, "*", search_selection, { desc = "search selection" })

-- Goto mode (g)
local gmoves = { gg = "gg0", ge = "G0", gh = "0", gl = "$", gs = "^", gt = "H", gc = "M", gb = "L", ["g."] = "`." }
for lhs, rhs in pairs(gmoves) do map(nx, lhs, move(rhs), { expr = true, desc = "goto " .. rhs }) end
map(nx, "gd", vim.lsp.buf.definition, { desc = "goto definition" })
map(nx, "gD", vim.lsp.buf.declaration, { desc = "goto declaration" })
map(nx, "gy", vim.lsp.buf.type_definition, { desc = "goto type definition" })
map(nx, "gr", picker("lsp_references"), { desc = "goto references" })
map(nx, "gi", picker("lsp_implementations"), { desc = "goto implementation" })
map(nx, "ga", "<C-^>", { desc = "last accessed file" })
map(nx, "gn", "<Cmd>bnext<CR>", { desc = "next buffer" })
map(nx, "gp", "<Cmd>bprevious<CR>", { desc = "previous buffer" })
map(nx, "gw", function() require("flash").jump() end, { desc = "goto word (labels)" })

-- Match mode (m)
map(nx, "mm", move("%"), { expr = true, desc = "goto matching bracket" })
map("n", "ms", function() feed("ms", true); feed("v") end, { desc = "surround add" })   -- runs as: v, ms
map("x", "md", function() feed("<Esc>md", true) end, { desc = "surround delete" })
map("x", "mr", function() feed("<Esc>mr", true) end, { desc = "surround replace" })
map(nx, "mi", textobject(false), { desc = "select inside object" })
map(nx, "ma", textobject(true), { desc = "select around object" })

-- Unimpaired ([ and ])
map(nx, "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "next diagnostic" })
map(nx, "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "previous diagnostic" })
map(nx, "]D", function() vim.diagnostic.jump({ count = math.huge, wrap = false, float = true }) end, { desc = "last diagnostic" })
map(nx, "[D", function() vim.diagnostic.jump({ count = -math.huge, wrap = false, float = true }) end, { desc = "first diagnostic" })
map(nx, "]f", ts_move("goto_next_start", "function"), { desc = "next function" })
map(nx, "[f", ts_move("goto_previous_start", "function"), { desc = "previous function" })
map(nx, "]t", ts_move("goto_next_start", "class"), { desc = "next type" })
map(nx, "[t", ts_move("goto_previous_start", "class"), { desc = "previous type" })
map(nx, "]a", ts_move("goto_next_start", "parameter"), { desc = "next argument" })
map(nx, "[a", ts_move("goto_previous_start", "parameter"), { desc = "previous argument" })
map(nx, "]c", ts_move("goto_next_start", "comment"), { desc = "next comment" })
map(nx, "[c", ts_move("goto_previous_start", "comment"), { desc = "previous comment" })
map(nx, "]g", function() require("gitsigns").nav_hunk("next") end, { desc = "next change" })
map(nx, "[g", function() require("gitsigns").nav_hunk("prev") end, { desc = "previous change" })
map(nx, "]G", function() require("gitsigns").nav_hunk("last") end, { desc = "last change" })
map(nx, "[G", function() require("gitsigns").nav_hunk("first") end, { desc = "first change" })
map(nx, "]p", move("}"), { expr = true, desc = "next paragraph" })
map(nx, "[p", move("{"), { expr = true, desc = "previous paragraph" })

-- Space mode
local L = "<leader>"
map("n", L .. "f", picker("files", function() return { cwd = root() } end), { desc = "file picker" })
map("n", L .. "F", picker("files"), { desc = "file picker (cwd)" })
map("n", L .. "b", picker("buffers"), { desc = "buffer picker" })
map("n", L .. "j", picker("jumps"), { desc = "jumplist picker" })
map("n", L .. "s", picker("lsp_symbols"), { desc = "symbol picker" })
map("n", L .. "S", picker("lsp_workspace_symbols"), { desc = "workspace symbol picker" })
map("n", L .. "d", picker("diagnostics_buffer"), { desc = "diagnostic picker" })
map("n", L .. "D", picker("diagnostics"), { desc = "workspace diagnostic picker" })
map("n", L .. "g", picker("git_status"), { desc = "changed file picker" })
map("n", L .. "'", picker("resume"), { desc = "last picker" })
map("n", L .. "/", picker("grep", function() return { cwd = root() } end), { desc = "global search" })
map("n", L .. "?", picker("keymaps"), { desc = "command palette" })
map("n", L .. "e", function() Snacks.explorer({ cwd = root() }) end, { desc = "file explorer" })
map("n", L .. "E", function() Snacks.explorer({ cwd = vim.fn.expand("%:p:h") }) end, { desc = "file explorer (buffer dir)" })
map(nx, L .. "a", vim.lsp.buf.code_action, { desc = "code action" })
map("n", L .. "k", function() vim.lsp.buf.hover({ border = "rounded" }) end, { desc = "hover" })
map("n", L .. "r", vim.lsp.buf.rename, { desc = "rename symbol" })
map("n", L .. "h", vim.lsp.buf.document_highlight, { desc = "highlight references" })
map(nx, L .. "c", toggle_comment, { desc = "toggle comment" })
map(nx, L .. "C", toggle_comment, { desc = "toggle block comment" })
map("n", L .. "w", "<C-w>", { remap = true, desc = "window" })
map("n", L .. "y", '"+yl', { desc = "yank to clipboard" })
map("x", L .. "y", '"+ygv', { desc = "yank to clipboard" })
map("n", L .. "Y", '"+yl', { desc = "yank main selection to clipboard" })
map("x", L .. "Y", '"+ygv', { desc = "yank main selection to clipboard" })
map("n", L .. "p", '"+p', { desc = "paste clipboard after" })
map("x", L .. "p", '<Esc>`>"+p', { desc = "paste clipboard after" })
map("n", L .. "P", '"+P', { desc = "paste clipboard before" })
map("x", L .. "P", '<Esc>`<"+P', { desc = "paste clipboard before" })
map("n", L .. "R", 'v"+P', { desc = "replace with clipboard" })
map("x", L .. "R", '"+P', { desc = "replace with clipboard" })

-- Debug mode (space G)
local function dap(fn, ...)
    local args = { ... }
    return function() require("dap")[fn](unpack(args)) end
end
local function widget(name)
    return function() local w = require("dap.ui.widgets"); w.centered_float(w[name]) end
end
map("n", L .. "Gl", dap("continue"), { desc = "launch debug target" })
map("n", L .. "Gr", dap("restart"), { desc = "restart debug session" })
map("n", L .. "Gb", dap("toggle_breakpoint"), { desc = "toggle breakpoint" })
map("n", L .. "Gc", dap("continue"), { desc = "continue" })
map("n", L .. "Gh", dap("pause"), { desc = "pause" })
map("n", L .. "Gi", dap("step_into"), { desc = "step in" })
map("n", L .. "Go", dap("step_out"), { desc = "step out" })
map("n", L .. "Gn", dap("step_over"), { desc = "step to next" })
map("n", L .. "Gv", widget("scopes"), { desc = "list variables" })
map("n", L .. "Gt", dap("terminate"), { desc = "end debug session" })
map("n", L .. "G<C-c>", function() require("dap").set_breakpoint(vim.fn.input("Condition: ")) end, { desc = "breakpoint condition" })
map("n", L .. "G<C-l>", function() require("dap").set_breakpoint(nil, nil, vim.fn.input("Log message: ")) end, { desc = "log point" })
map("n", L .. "Gst", widget("threads"), { desc = "switch thread" })
map("n", L .. "Gsf", widget("frames"), { desc = "switch stack frame" })
map("n", L .. "Ge", function() require("dap.ui.widgets").hover() end, { desc = "evaluate under cursor" })

-- Insert mode extras (helix defaults)
map("i", "<C-k>", "<C-o>D", { desc = "delete to line end" })
map("i", "<M-d>", "<C-o>dw", { desc = "delete word forward" })
map("i", "<C-d>", "<Del>", { desc = "delete char forward" })
map("i", "<C-s>", "<C-g>u", { desc = "commit undo checkpoint" })

-- Typable commands that helix has and vim spells differently
local function abbrev(lhs, rhs)
    vim.cmd(("cnoreabbrev <expr> %s (getcmdtype() ==# ':' && getcmdline() ==# '%s') ? '%s' : '%s'"):format(lhs, lhs, rhs, lhs))
end
abbrev("fmt", "lua require('conform').format({ lsp_format = 'fallback' })")
abbrev("bc", "bdelete")
abbrev("bco", "%bdelete\\|edit#\\|bdelete#")
abbrev("rl", "edit!")
abbrev("o", "edit")
abbrev("lr", "lsp restart")

return M
