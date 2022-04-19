-- mod-version:2 -- lite-xl 2.0
--
-- Markdown previewer
--

local core = require "core"
local keymap = require "core.keymap"
local command = require "core.command"
local style = require "core.style"
local View = require "core.view"
local common = require "core.common"

local utils = require "utils" or require "plugins.markdown-xl.utils"
local md = require "luamd" or require "plugins.markdown-xl.luamd"
local treeview_loaded, treeview = core.try(require, "plugins.treeview")

local main = {}
-- Set this to true so you can see luamd tree printed in console.
-- it has some side effects like view not drawing properly
-- this is to prevent tree printing to not spam console
local DEBUG = true
-- Log both lite-xl log builtin and console
local function log(logtext, format)
  core.log(logtext, format)
  print(logtext)
end

---@alias corestyle unknown
---@type number SCALE


---@class mdStyle
---@field name string
---@field font corestyle
---@field color corestyle
---@field prefix string
---@field sufix string
---@field padding {x: number, y: number}
---@field attributes? any

---@type mdStyle[]
local markdown_types = {
  { name = "ol>li", font = style.font, color = style.text, prefix = " 1 ", sufix = "", padding = { x = 0, y = 0 } },
  { name = "ul>li", font = style.font, color = style.text, prefix = "  • ", sufix = "", padding = { x = 0, y = 0 } },
  { name = "code", font = style.code_font:copy(13 * SCALE), color = style.text, padding = { x = 0, y = 0 } },
  { name = "h1", font = style.font:copy(32 * SCALE), color = style.text, prefix = "", sufix = "", padding = { x = 0, y = 0 } },
  { name = "h2", font = style.font:copy(24 * SCALE), color = style.text, prefix = "", sufix = "", padding = { x = 0, y = 0 } },
  { name = "h3", font = style.font:copy(19 * SCALE), color = style.text, prefix = "", sufix = "", padding = { x = 0, y = 0 } },
  { name = "h4", font = style.font:copy(16 * SCALE), color = style.text, prefix = "", sufix = "", padding = { x = 0, y = 0 } },
  { name = "h5", font = style.font:copy(13 * SCALE), color = style.text, prefix = "", sufix = "", padding = { x = 0, y = 0 } },
  { name = "h6", font = style.font:copy(12 * SCALE), color = style.text, prefix = "", sufix = "", padding = { x = 0, y = 0 } },
  { name = "p", font = style.font, color = style.text },
}

---Find a markdown type by name
---@param name string
---@return table mdStyle
local function find_markdown_type(name)
  assert(type(name) == "string", "'name' parameter should be a string, got " .. type(name))
  for _, type in ipairs(markdown_types) do
    -- set default properties
    ---@type mdStyle
    type.name = type.name or "p"
    type.font = type.font or style.font
    type.color = type.color or style.text
    type.prefix = type.prefix or ""
    type.sufix = type.sufix or ""
    type.padding = type.padding or {x = 0,y = 0}
    if type.name == name then return type end
  end
end

local MarkdownView = View:extend()

function MarkdownView:new()
  MarkdownView.super.new(self)
  self.target_size = 500 * SCALE
  self.initial_active_view = core.active_view
  self.text_content = ""
  self.content = {}
  self.treeview_target_size = treeview.target_size
  self.need_draw = false
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
  if not DEBUG then self.need_draw = true end
  return self.scrollable_size + self.size.y
end

function MarkdownView:update(...)
  -- Get Doc contents
  local new_content = self.initial_active_view.doc:get_text(1, 1, math.huge, math.huge)
  -- TODO: Sync Doc scroll position with the view
  -- self.scroll.to.y = self.initial_active_view.doc.scroll.y

  -- Update view only if the doc has been modified
  if (type(new_content) == "string" and self.text_content ~= new_content) then
    self.text_content = new_content
    local success, tree, links = core.try(function() return md.read(self.text_content) end)
    if success then
    if DEBUG then
      utils.print_table(self.content)
    end
      self.content = tree
      self.need_draw = true
    else
      log("Markdown-xl: error while trying to tokenize (temporary error)")
    end
  end
  MarkdownView.super.update(self, ...)
end

---@class NodeConfig
---@field top number
---@field left number
---@field depth number recursion depth
---@field total_scrollable_size number
---@field style mdStyle style used in render

--- Recursive tree renderer
---@param node table markdown tree generated with `luamd`
---@param cfg? NodeConfig
---@return NodeConfig
local function render_node(node, cfg)
  if not cfg then cfg = {} end
  if not cfg.top then cfg.top = 0 end
  if not cfg.left then cfg.left = 0 end
  if not cfg.total_scrollable_size then cfg.total_scrollable_size = 0 end
  if not cfg.depth then cfg.depth = 0 end

  local outer_i = 0
  local _print = function(text)
    if not DEBUG then return end
    local pre = string.rep("│   ", cfg.depth)
    if cfg.depth > 0 then
      pre = pre .. ((outer_i == #node and "└──") or "├──")
    else 
      pre = "├──"
    end
    print(pre .. text)
  end
  _print("node LUA type: " .. type(node))

  for i, childnode in ipairs(node) do
    outer_i = i
    
    local child_type = type(childnode)
    if child_type == "string" then
      ---@type string
      local text = cfg.style.prefix .. childnode .. cfg.style.sufix
      _print("childnode LUA type: text -> rendering '".. text:gsub("\n", "\\n") .."'")
      if text:match("\n") then
        text = ((DEBUG and "BREAKLINE | DEPTH: " .. cfg.depth) or " ")
        local tmp_style = find_markdown_type("p")
        common.draw_text(
          tmp_style.font, style.syntax["comment"], text,
          "left", cfg.left, cfg.top, tmp_style.font:get_height(), tmp_style.font:get_height()
        )
        cfg.top = cfg.top + tmp_style.font:get_height()
        cfg.total_scrollable_size = cfg.total_scrollable_size + tmp_style.font:get_height()
      else
        common.draw_text(
          cfg.style.font, cfg.style.color, text,
          "left", cfg.left + style.padding.x * cfg.depth, cfg.top, cfg.style.font:get_height(), cfg.style.font:get_height()
        )
        cfg.top = cfg.top + cfg.style.font:get_height()
        cfg.total_scrollable_size = cfg.total_scrollable_size + cfg.style.font:get_height()
      end
      
    elseif child_type == "table" then
      if childnode.type then
        _print("childnode MD type: " .. childnode.type)
        cfg.style = find_markdown_type(childnode.type) or find_markdown_type("p") -- 'p' used as fallback
        cfg.style.attributes = childnode.attributes or nil
      end
      cfg.depth = cfg.depth + 1
      cfg = render_node(childnode, cfg)
      cfg.depth = cfg.depth - 1
    else
      _print("childnode LUA type: " .. type(childnode) .. " -> ignoring")
    end
  end
  return cfg
end

function MarkdownView:draw()
  if not self.need_draw then
    self:draw_scrollbar()
    return
  end
  
  self:draw_background(style.background)
  -- Visible top-left View corner
  local ox, oy = self:get_content_offset()

  local top = oy
  local left = ox + style.padding.x
  
  local cfg = render_node(self.content, { top = top, left = left })
  self.scrollable_size = cfg.total_scrollable_size
  self:draw_scrollbar()
  self.need_draw = false
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
  end,
  ["markdown:toggle debug"] = function ()
    DEBUG = not DEBUG
    log("Markdown DEBUG " .. ((DEBUG and "enabled") or "disabled"))
  end
})

keymap.add {
  ["alt+shift+m"] = "markdown:show"
}

return main
