--[[--
 String buffers.

 Prototype Chain
 ---------------

      table
       `-> Object
            `-> StrBuf

 @classmod std.strbuf
]]

local base   = require "std.base"
local debug  = require "std.debug"

local Object = require "std.object" {}

local M, StrBuf


--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


local function X (decl, fn)
  return debug.argscheck ("std.strbuf." .. decl, fn)
end


M = {
  --- Add a string to a buffer.
  -- @static
  -- @function concat
  -- @string s string to add
  -- @treturn StrBuf modified buffer
  -- @usage
  -- buf = concat (buf, "append this")
  concat = X ("concat (StrBuf, string)", base.insert),
}



--[[ ============= ]]--
--[[ Deprecations. ]]--
--[[ ============= ]]--


local DEPRECATED = debug.DEPRECATED

M.tostring = DEPRECATED ("41.1", "std.strbuf.tostring",
                         "use 'tostring (strbuf)' instead",
	                 X ("tostring (StrBuf)", table.concat))


--[[ ================== ]]--
--[[ Type Declarations. ]]--
--[[ ================== ]]--


--- StrBuf prototype object.
--
-- Set also inherits all the fields and methods from
-- @{std.object.Object}.
-- @object StrBuf
-- @string[opt="StrBuf"] _type object name
-- @see std.object.__call
-- @usage
-- local std = require "std"
-- local StrBuf = std.strbuf {}
-- local buf = StrBuf {"initial buffer contents"}
-- buf = buf .. "append to buffer"
-- print (buf) -- implicit `tostring` concatenates everything
-- os.exit (0)
StrBuf = Object {
  _type = "StrBuf",

  __index = M,

  --- Support concatenation to StrBuf objects.
  -- @function __concat
  -- @tparam StrBuf buffer object
  -- @string s a string
  -- @treturn StrBuf modified *buf*
  -- @see concat
  -- @usage
  -- buf = buf .. str
  __concat = base.insert,

  --- Support fast conversion to Lua string.
  -- @function __tostring
  -- @tparam StrBuf buffer object
  -- @treturn string concatenation of buffer contents
  -- @see tostring
  -- @usage
  -- str = tostring (buf)
  __tostring = table.concat,
}


return StrBuf
