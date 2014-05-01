--[[--
 Submodule lazy loader.

 After requiring this module, simply referencing symbols in the submodule
 hierarchy will load the necessary modules on demand.

 Clients of older releases might be surprised by this new-found hygiene,
 expecting the various changes that used to be automatically installed as
 global symbols, or monkey patched into the core module tables and
 metatables.  Sometimes, it's still convenient to do that... when using
 stdlib from the REPL, or in a prototype where you want to throw caution
 to the wind and compatibility with other modules be damned, for example.
 In that case, you can give stdlib permission to scribble all over your
 namespaces with:

   local std = require "std".monkey_patch ()

 @todo Write a style guide (indenting/wrapping, capitalisation,
   function and variable names); library functions should call
   error, not die; OO vs non-OO (a thorny problem).
 @todo Add tests for each function immediately after the function;
   this also helps to check module dependencies.
 @todo pre-compile.
 @module std
]]


local M -- forward declaration

--- Overwrite core methods and metamethods with `std` enhanced versions.
--
-- Loads all `std` submodules with a `monkey_patch` method, and runs
-- them.
-- @function monkey_patch
-- @tparam[opt=_G] table namespace where to install global functions
-- @treturn table the module table
local function monkey_patch (namespace)
  namespace = namespace or _G

  assert (type (namespace) == "table",
          "bad argument #1 to 'monkey_patch' (table expected, got " .. type (namespace) .. ")")

  require "std.io".monkey_patch (namespace)
  require "std.math".monkey_patch (namespace)
  require "std.string".monkey_patch (namespace)
  require "std.table".monkey_patch (namespace)

  return M
end


--- A [barrel of monkey_patches](http://dictionary.reference.com/browse/barrel+of+monkeys).
--
-- Scribble all over the given namespace, and apply all available
-- `monkey_patch` functions.
-- @function barrel
-- @tparam[opt=_G] table namespace where to install global functions
-- @treturn table module table
local function barrel (namespace)
  namespace = namespace or _G

  assert (type (namespace) == "table",
          "bad argument #1 to 'barrel' (table expected, got " .. type (namespace) .. ")")

  -- Older releases installed the following into _G by default.
  for _, v in pairs {
    "functional.bind", "functional.collect", "functional.compose",
    "functional.curry", "functional.eval", "functional.filter",
    "functional.fold", "functional.id", "functional.map",
    "functional.memoize", "functional.op",

    "io.die", "io.warn",

    "string.assert", "string.pickle", "string.prettytostring",
    "string.render", "string.require_version", "string.tostring",

    "table.metamethod", "table.pack", "table.ripairs",
    "table.totable",

    "tree.ileaves", "tree.inodes", "tree.leaves", "tree.nodes",
  } do
    local module, method = v:match "^(.*)%.(.-)$"
    namespace[method] = M[module][method]
  end

  return monkey_patch (namespace)
end


--- Module table.
--
-- Lazy load submodules into `std` on first reference.  On initial
-- load, `std` has the usual single `version` entry, but the `__index`
-- metatable will automatically require submodules on first reference:
--
--     local std = require "std"
--     local prototype = std.container.prototype
-- @table std
-- @field version release version string
local version = "General Lua libraries / 40"


M = {
  barrel       = barrel,
  monkey_patch = monkey_patch,
  version      = version,
}


--- Metamethods
-- @section Metamethods

return setmetatable (M, {
  --- Lazy loading of stdlib modules.
  -- Don't load everything on initial startup, wait until first attempt
  -- to access a submodule, and then load it on demand.
  -- @function __index
  -- @string name submodule name
  -- @return the submodule that was loaded to satisfy the missing `name`
  __index = function (self, name)
              local ok, t = pcall (require, "std." .. name)
              if ok then
		rawset (self, name, t)
		return t
	      end
	    end,
})
