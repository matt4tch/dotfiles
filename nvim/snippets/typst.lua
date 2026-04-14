local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local d = ls.dynamic_node
local sn = ls.snippet_node

local function grid_n(args)
  local n = tonumber(args[1][1]) or 1
  local nodes = {}
  for r = 1, n do
    local cells = {}
    for _ = 1, n do
      cells[#cells + 1] = "$$"
    end
    local line = "  " .. table.concat(cells, ", ")
    if r < n then
      nodes[#nodes + 1] = t({ line .. ",", "" })
    else
      nodes[#nodes + 1] = t({ line .. "," })
    end
  end
  return sn(nil, nodes)
end

local function grid_nm(args)
  local n = tonumber(args[1][1]) or 1
  local m = tonumber(args[2][1]) or 1
  local nodes = {}
  for r = 1, m do
    local cells = {}
    for _ = 1, n do
      cells[#cells + 1] = "$$"
    end
    local line = "  " .. table.concat(cells, ", ")
    if r < m then
      nodes[#nodes + 1] = t({ line .. ",", "" })
    else
      nodes[#nodes + 1] = t({ line .. "," })
    end
  end
  return sn(nil, nodes)
end

ls.add_snippets("typst", {
  s("pre", {
    t('#import "preamble.typ" : *'),
    t({ "", "#show: preamble" }),
  }),
  s("ctable", {
    t("#cayley-table("),
    i(1, "1"),
    t(", (", ""),
    t({ "", "" }),
    d(2, grid_n, { 1 }),
    t({ "", "))" }),
  }),
  s("gtable", {
    t("#grid-table("),
    i(1, "1"),
    t(", "),
    i(2, "1"),
    t(", (", ""),
    t({ "", "" }),
    d(3, grid_nm, { 1, 2 }),
    t({ "", "))" }),
  }),
})
