local hell = require "specl.shell"

local LUA = "lua"

if _G.arg ~= nil then
  local i = 0
  while _G.arg[i - 1] ~= nil do
    i = i - 1
    LUA = _G.arg[i]
  end
end

local function mkscript (code)
  local f = os.tmpname ()
  local h = io.open (f, "w")
  h:write (code)
  h:close ()
  return f
end

local function tabulate_output (code)
  local f = mkscript (code)
  local proc = hell.spawn {
    LUA, f;
    env = { LUA_PATH=package.path, LUA_INIT="", LUA_INIT_5_2="" },
  }
  os.remove (f)
  if proc.status ~= 0 then return error (proc.errout) end
  local r = {}
  proc.output:gsub ("(%S*)[%s]*",
    function (x)
      if x ~= "" then r[x] = true end
    end)
  return r
end


--- Show changes to tables wrought by a require statement.
-- There are a few modes to this function, controlled by what named
-- arguments are given.  Lists new keys in T1 after `require "import"`:
--
--     show_apis {added_to=T1, by=import}
--
-- List keys returned from `require "import"`, which have the same
-- value in T1:
--
--     show_apis {from=T1, used_by=import}
--
-- List keys from `require "import"`, which are also in T1 but with
-- a different value:
--
--     show_apis {from=T1, enhanced_by=import}
--
-- List keys from T2, which are also in T1 but with a different value:
--
--     show_apis {from=T1, enhanced_in=T2}
--
-- @tparam table argt one of the combinations above
-- @treturn table a list of keys according to criteria above
function show_apis (argt)
  local added_to, from, not_in, enhanced_in, enhanced_after, by =
    argt.added_to, argt.from, argt.not_in, argt.enhanced_in,
    argt.enhanced_after, argt.by

  if added_to and by then
    return tabulate_output ([[
      local before, after = {}, {}
      for k in pairs (]] .. added_to .. [[) do
        before[k] = true
      end

      local M = require "]] .. by .. [["
      for k in pairs (]] .. added_to .. [[) do
        after[k] = true
      end

      for k in pairs (after) do
        if not before[k] then print (k) end
      end
    ]])

  elseif from and not_in then
    return tabulate_output ([[
      local from = ]] .. from .. [[
      local M = require "]] .. not_in .. [["

      for k in pairs (M) do
        if from[k] ~= M[k] then print (k) end
      end
    ]])

  elseif from and enhanced_in then
    return tabulate_output ([[
      local from = ]] .. from .. [[
      local M = require "]] .. enhanced_in .. [["

      for k, v in pairs (M) do
        if from[k] ~= M[k] and from[k] ~= nil then print (k) end
      end
    ]])

  elseif from and enhanced_after then
    return tabulate_output ([[
      local before, after = {}, {}
      local from = ]] .. from .. [[

      for k, v in pairs (from) do before[k] = v end
      ]] .. enhanced_after .. [[
      for k, v in pairs (from) do after[k] = v end

      for k, v in pairs (before) do
        if after[k] ~= nil and after[k] ~= v then print (k) end
      end
    ]])
  end

  assert (false, "missing argument to show_apis")
end


-- Not local, so that it is available in spec examples.
totable = (require "std.table").totable


-- Custom matcher for set membership.

local set      = require "std.set"
local util     = require "specl.util"
local matchers = require "specl.matchers"

local Matcher, matchers, q =
      matchers.Matcher, matchers.matchers, matchers.stringify

matchers.have_member = Matcher {
  function (actual, expect)
    return set.member (actual, expect)
  end,

  actual = "set",

  format_expect = function (expect)
    return " a set containing " .. q (expect) .. ", "
  end,

  format_any_of = function (alternatives)
    return " a set containing any of " ..
           util.concat (alternatives, util.QUOTED) .. ", "
  end,
}
