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

local utils = require "plugins.markdown-xl.utils"
local md = require "plugins.markdown-xl.luamd"

local main = {}

local fonts = {
  bold = renderer.font.load(DATADIR .. "/fonts/FiraSans-Regular.ttf", 16 * SCALE, { bold = true, antialiasing = "grayscale" }),
  italic = renderer.font.load(DATADIR .. "/fonts/FiraSans-Regular.ttf", 15 * SCALE, { italic = true }),
  normal = renderer.font.load(DATADIR .. "/fonts/FiraSans-Regular.ttf", 15 * SCALE)
}
local markdown_types = {
  { name = "ol>li", font = fonts.normal, color = style.text, prefix = " 1 ", sufix = "", padding = { x = 0, y = 0 } },
  { name = "ul>li", font = fonts.normal, color = style.text, prefix = "  • ", sufix = "", padding = { x = 0, y = 0 } },
  { name = "pre", font = style.code_font:copy(13 * SCALE), color = style.text, padding = { x = 10, y = 10 }, margin = { x = 10, y = 10 } },
  { name = "code", font = style.code_font:copy(13 * SCALE), color = style.text, padding = { x = 0, y = 0 } },
  { name = "h1", font = style.font:copy(32 * SCALE), color = style.text, padding = { x = 0, y = 20 } },
  { name = "h2", font = style.font:copy(24 * SCALE), color = style.text, padding = { x = 0, y = 20 } },
  { name = "h3", font = style.font:copy(19 * SCALE), color = style.text, padding = { x = 0, y = 20 } },
  { name = "h4", font = style.font:copy(16 * SCALE), color = style.text, padding = { x = 0, y = 20 } },
  { name = "h5", font = style.font:copy(13 * SCALE), color = style.text, padding = { x = 0, y = 20 } },
  { name = "h6", font = style.font:copy(12 * SCALE), color = style.text, padding = { x = 0, y = 0 } },
  { name = "p", exp = "(.*)", font = style.font, color = style.text, padding = { x = 0, y = 10 } },
  { name = "strong", inline = true, font = fonts.bold, color = style.text, padding = { x = 0, y = 0 } },
  { name = "em", inline = true, font = fonts.italic, color = style.text, padding = { x = 0, y = 0 } },
  { name = "strike", inline = true, font = fonts.normal, color = style.dim, padding = { x = 0, y = 0 } }
}

-- Set this to true so you can see luamd tree printed in console.
-- it has some side effects like view not drawing properly
-- this is to prevent tree printing to not spam console
local DEBUG = true

-- Log both lite-xl log builtin and console
local function log(logtext, _format)
  core.log(logtext, _format)
  print(string.format(logtext, _format))
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

local MarkdownView = View:extend()

function MarkdownView:new()
  MarkdownView.super.new(self)
  self.initial_active_view = core.active_view
  self.text_content = ""
  self.content = {}

  -- 'View' class properties
  self.scrollable = true
  self.scrollable_size = 0
end

function MarkdownView:get_name()
  local initial_view = self.initial_active_view or core.active_view
  return "Preview " .. (initial_view.doc.abs_name or initial_view.doc:get_name())
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
  if (self.text_content ~= new_content) then
    self.text_content = new_content
    self.content = md.read(self.text_content)
    if DEBUG then
      utils.print_table(self.content)
      print(string.rep("---*", 20) .. "---")
    end
  end
  MarkdownView.super.update(self, ...)
end

--- @class RenderContext
--- @field view {bounds: {top: number, left: number}, size: { width: number, height: number}}
--- @field top number
--- @field left number

---@type RenderContext
local renderContext = {}

---@param line string[]
---@param styletype table
---@param sanitize_spaces boolean? force space between words to one
local function renderLine(line, styletype, sanitize_spaces)
  sanitize_spaces = sanitize_spaces or false

  local ctx = renderContext

  for i, text in ipairs(line) do
    if not sanitize_spaces then
      text = text .. (i ~= #line and " " or "")
    end

    local nextwidth = ctx.left + styletype.font:get_width(text)
    -- If the text being drawn has overflow, continue in the next line
    if i > 1 and nextwidth > ctx.view.size.x then
      local py = styletype.padding and styletype.padding.y or 0
      ctx.top = ctx.top + styletype.font:get_height() + py
      ctx.left = 0 + style.padding.x
    end

    common.draw_text(
      styletype.font, styletype.color, text,
      "left", ctx.left + ctx.view.bounds.left, ctx.top + ctx.view.bounds.top,
      styletype.font:get_width(text),
      styletype.font:get_height()
    )
    ctx.left = ctx.left + styletype.font:get_width(text)
  end
end

---@param content table
---@return table wordlist
local function calculate_content_size(content, styletype, context)
  local lines = { {} }
  local ctx = {
    top = context.top,
    left = context.left,
  }

  local i = 1
  for _, item in ipairs(content) do
    if type(item) == "string" then
      if item == "\n" then
        lines[#lines + 1] = {}
        i = 1
      else
        for space, str in string.gmatch(item, "(%s*)([^%s]*)") do
          print(string.format("space: '%s' | str: '%s'", space, str))
          local spacewidth = styletype.font:get_width(space)
          local strwidth = styletype.font:get_width(str)
          local nextwidth = ctx.left + spacewidth + strwidth

          -- If the text has overflow, continue in the next line
          if i > 1 and nextwidth > renderContext.view.size.x then
            lines[#lines + 1] = { str }
            i = 1
          end

          if #space > 0 then
            table.insert(lines[#lines], space)
            ctx.left = ctx.left + spacewidth
          end
          table.insert(lines[#lines], str)
          ctx.left = ctx.left + strwidth
          i = i + 1

        end
      end
    end
  end
  return lines
end

local specialRenders = {
  ["pre-"] = function(tree)
    local ctx = renderContext
    local styletype = find_markdown_type("pre")

    -- utils.print_table(tree)
    -- print(string.rep("~", 20))
    for _, subtree in ipairs(tree.content) do
      if subtree.type == "code" then
        local wordlist, n_lines = calculate_content_size(subtree.content, true)

        ctx.top = ctx.top + styletype.margin.y
        local bg_rect = {
          x1 = ctx.view.bounds.left + styletype.margin.x,
          y1 = ctx.view.bounds.top + ctx.top,
          x2 = main.view.size.x - styletype.margin.x * 2,
          y2 = n_lines * styletype.font:get_height() + styletype.padding.y
        }
        renderer.draw_rect(
          bg_rect.x1, bg_rect.y1,
          bg_rect.x2, bg_rect.y2,
          style.background2
        )

        -- padding
        ctx.top = ctx.top + styletype.padding.y
        ctx.left = 0 + styletype.padding.x + styletype.margin.x

        for _, text in ipairs(wordlist) do
          if text == "\n" then
            ctx.top = ctx.top + styletype.font:get_height()
            ctx.left = 0 + styletype.padding.x + styletype.margin.x
          else
            -- TODO: use Doc.highlighter
            common.draw_text(
              styletype.font, styletype.color, text,
              "left", ctx.left + ctx.view.bounds.left, ctx.top + ctx.view.bounds.top,
              styletype.font:get_width(text),
              styletype.font:get_height()
            )
            ctx.left = ctx.left + styletype.font:get_width(text)
          end
        end -- end for

        -- bottom margin
        ctx.top = ctx.top + styletype.margin.y
      end -- end if
    end --end for
  end -- end function
}

local function renderTree(tree)
  local ctx = renderContext

  -- Subtree render logic
  if tree.type then
    if not tree.content then return end -- Ignore not implemented types
    local render = specialRenders[tree.type]
    if render then
      render(tree)
      return
    end
    local styletype = find_markdown_type(tree.type)
    if not styletype then return find_markdown_type("p") end -- fallback to paragraph styletype

    for i, item in ipairs(tree.content) do
      if type(item) == "table" then
        -- render inline modifiers (like **bold**, *italic*, etc.) and other markdown types inserted in this subtree
        renderTree(item)
      elseif type(item) == "string" then
        if item == "\n" then
          ctx.top = ctx.top + styletype.font:get_height()
          ctx.left = 0 + style.padding.x
        else
          local wordlist = {}
          local match -- keep last match
          for match in string.gmatch(item, "([^" .. " " .. "]+)") do
            table.insert(wordlist, match)
          end
          if not match then
            table.insert(wordlist, "")
          end
          renderLine(wordlist, styletype)
        end
      else
        log("Markdown-xl [renderTree]: Unknown type: " .. type(item) .. "skiping")
      end
    end

    local py = styletype.padding and styletype.padding.y or 0
    if not styletype.inline then
      ctx.top = ctx.top + styletype.font:get_height() + py
      ctx.left = 0 + style.padding.x
    end
    return
  end

  -- Root tree
  for i = 1, #tree, 1 do
    local subtree = tree[i]
    if type(subtree) == "table" then
      renderTree(subtree)
    elseif type(subtree) == "string" then
      local text = subtree
      if text == "\n" then
        ctx.top = ctx.top + style.padding.y
        ctx.left = 0 + style.padding.x
      end
    end
  end

end

function MarkdownView:draw()
  self:draw_background(style.background)

  -- Visible top-left View corner
  local ox, oy = self:get_content_offset()

  renderContext = {
    view = {
      bounds = { top = oy, left = ox },
      size = { x = self.size.x, y = self.size.y }
    },
    top = 0,
    left = 0 + style.padding.x,
  }
  renderTree(self.content)

  self.scrollable_size = renderContext.top
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
  ["markdown:toggle debug"] = function()
    DEBUG = not DEBUG
    log("Markdown DEBUG " .. ((DEBUG and "enabled") or "disabled"))
  end
})

keymap.add {
  ["alt+shift+m"] = "markdown:show"
}

return main
