-- mod-version:3 -- lite-xl 2.0
--
-- Markdown previewer
--

local core = require "core"
local keymap = require "core.keymap"
local command = require "core.command"
local style = require "core.style"
local View = require "core.view"
local common = require "core.common"

local treeview_loaded, treeview = core.try(require, "plugins.treeview")

local main = {}
local markdown_types = {
  { name = "ol>li", exp = "^%d+[.- ]%s*([%w].*)", font = style.font, color = style.text, prefix = " 1 ", sufix = "", padding = { x = 0, y = 0 } },
  { name = "ul>li", exp = "^%-%s*(%w[%w%s]*)", font = style.font, color = style.text, prefix = "  • ", sufix = "", padding = { x = 0, y = 0 } },
  { name = "code", exp = "^%s%s%s%s(.*)$", font = style.code_font:copy(13 * SCALE), color = style.text, padding = { x = 0, y = 0 } },
  { name = "h1", exp = "^%s*#%s*([%w%.,_].*)$", font = style.font:copy(32 * SCALE), color = style.text, padding = { x = 0, y = 0 } },
  { name = "h2", exp = "^%s*##%s*([%w%.,_].*)$", font = style.font:copy(24 * SCALE), color = style.text, padding = { x = 0, y = 0 } },
  { name = "h3", exp = "^%s*###%s*([%w%.,_].*)$", font = style.font:copy(19 * SCALE), color = style.text, padding = { x = 0, y = 0 } },
  { name = "h4", exp = "^%s*####%s*([%w%.,_].*)$", font = style.font:copy(16 * SCALE), color = style.text, padding = { x = 0, y = 0 } },
  { name = "h5", exp = "^%s*#####%s*([%w%.,_].*)$", font = style.font:copy(13 * SCALE), color = style.text, padding = { x = 0, y = 0 } },
  { name = "h6", exp = "^%s*######%s*([%w%.,_].*)$", font = style.font:copy(12 * SCALE), color = style.text, padding = { x = 0, y = 0 } },
  { name = "p", exp = "(.*)", font = style.font, color = style.text },
}

-- Log both lite-xl log builtin and console
local function log(logtext, format)
  core.log(logtext, format)
  print(logtext, format)
end

---Find a markdown type by name
---@param name string
---@return table markdown_type
local function find_markdown_type(name)
  assert(type(name) == "string", "'name' parameter should be a string, got " .. type(name))
  for _, type in ipairs(markdown_types) do
    if type.name == name then return type end
  end
end

---@param text string
---@param return_table boolean
local function lines(text, return_table)
  if return_table then
    local res = {}
    for match in (text .. "\n"):gmatch("(.-)\n") do
      table.insert(res, match)
    end
    return res
  end
  return (text .. "\n"):gmatch("(.-)\n")
end

---@param line string
local function infer_type(line)
  -- TODO: add user custom types
  for _, type in ipairs(markdown_types) do
    local exp = type.exp
    local match = string.match(line, exp)
    if match then return match, type.name end
  end
end

---@param content string text from the active doc file
---@return table md_lines
local function parse_content(content)
  local md_lines = {}
  for line in lines(content) do
    local text, type = infer_type(line)
    if text then
      table.insert(md_lines, {
        text = text,
        type = type
      })
    else
      table.insert(md_lines, {
        text = line,
        type = "p"
      })
    end
  end
  return md_lines
end

local MarkdownView = View:extend()

function MarkdownView:new()
  MarkdownView.super.new(self)
  self.target_size = 500 * SCALE
  self.initial_active_view = core.active_view
  self.text_content = ""
  self.content = {}
  self.treeview_target_size = treeview.target_size

  -- 'View' class properties
  self.scrollable = true
  self.scrollable_size = 0
end

function MarkdownView:get_name()
  local initial_view = self.initial_active_view or core.active_view
  return "Preview " .. (initial_view.doc.abs_name or initial_view.doc:get_name())
end

function MarkdownView:set_target_size(axis, value)
  if axis == "x" then
    self.target_size = value
    self.treeview_target_size = treeview.target_size
    return true
  end
end

function MarkdownView:try_close(...)
  MarkdownView.super.try_close(self, ...)
  main.view = nil
end

function MarkdownView:get_scrollable_size()
  -- self.scrollable_size is calculated when drawing lines
  return self.scrollable_size + self.size.y
end

function MarkdownView:update(...)
  -- Get Doc contents
  local new_content = self.initial_active_view.doc:get_text(1, 1, math.huge, math.huge)

  -- TODO: Sync Doc scroll position with the view
  -- self.scroll.to.y = self.initial_active_view.doc.scroll.y

  -- Update view only if the doc has been modified
  if (self.text_content ~= new_content) then
    self.content = parse_content(new_content)
    self.text_content = new_content
  end
  MarkdownView.super.update(self, ...)
end

function MarkdownView:draw()
  self:draw_background(style.background)

  -- Visible top-left View corner
  local ox, oy = self:get_content_offset()

  local top = oy
  local left = ox + style.padding.x

  local total_scrollable_size = 0
  for i, line in ipairs(self.content) do
    local config = find_markdown_type(line.type)

    -- Debug "tokenizer" -> local text = (line.type or "unknown") .. "(" .. (line.text or "NO_CONTENT!") .. ")"
    local text = (config.prefix or "") .. line.text

    common.draw_text(
      config.font, config.color, text,
      "left", left, top, config.font:get_height(), config.font:get_height()
    )
    -- Draw next line below so it doesn't overlaps
    top = top + config.font:get_height()

    -- Calculates scrollaable max size (used when draw_scrollbar View method is called)
    total_scrollable_size = total_scrollable_size + config.font:get_height()
  end
  self.scrollable_size = total_scrollable_size
  self:draw_scrollbar()
end

function main.start_markdown()
  main.view = MarkdownView()
  local node = core.root_view:get_active_node()
  node:split("right")

  -- Split the root_view and add the MarkdownView as a doc (with tab)
  node = core.root_view:get_active_node_default()
  node:add_view(main.view)
  core.root_view.root_node:update_layout()

  function main.view:update(...)
    local dest = (self.target_size or 0) + self.treeview_target_size

    self:move_towards(self.size, "x", dest)
    MarkdownView.update(self, ...)
  end
end

command.add(nil, {
  ["markdown:show"] = function()
    -- Allow only 1 Markdown preview View
    if main.view == nil then
      log("Markdown View initialized")
      main.start_markdown()
    else
      log("Markdown View already initialized")
    end
  end
})

keymap.add {
  ["alt+shift+m"] = "markdown:show"
}

return main