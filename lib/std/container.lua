--[[--
 Container prototype.

 This module supplies the root prototype object from which every other
 object is descended.  There are no classes as such, rather new objects
 are created by cloning an existing object, and then changing or adding
 to the clone. Further objects can then be made by cloning the changed
 object, and so on.

 The functionality of a container based object is entirely defined by its
 *meta*methods. However, since we can store *any* object in a container,
 we cannot rely on the `__index` metamethod, because it is only a
 fallback for when that key is not already in the container itself. Of
 course that does not entirely preclude the use of `__index` with
 containers, so long as this limitation is observed.

 When making your own prototypes, derive from @{std.container.prototype}
 if you want to access the contents of your containers with the `[]`
 operator, otherwise from @{std.object.prototype} if you want to access
 the functionality of your objects with named object methods.

 Prototype Chain
 ---------------

      table
       `-> Container

 @prototype std.container
]]


local _DEBUG = require "std.debug_init"._DEBUG

local std   = require "std.base"
local debug = require "std.debug"

local ipairs, tostring = std.ipairs, std.tostring
local mapfields = std.object.mapfields
local okeys = std.table.okeys



--[[ ================= ]]--
--[[ Helper Functions. ]]--
--[[ ================= ]]--


--- Instantiate a new object based on *proto*.
--
-- This is equivalent to:
--
--     table.merge (table.clone (proto), t or {})
--
-- Except that, by not typechecking arguments or checking for metatables,
-- it is slightly faster.
-- @tparam table proto base object to copy from
-- @tparam[opt={}] table t additional fields to merge in
-- @treturn table a new table with fields from proto and t merged in.
local function instantiate (proto, t)
  local obj = {}
  local k, v = next (proto)
  while k do
    obj[k] = v
    k, v = next (proto, k)
  end

  t = t or {}
  k, v = next (t)
  while k do
    obj[k] = v
    k, v = next (t, k)
  end
  return obj
end


--[[ ================= ]]--
--[[ Container Object. ]]--
--[[ ================= ]]--


--- Container prototype.
-- @object prototype
-- @string[opt="Container"] _type object name
-- @tfield[opt] table|function _init object initialisation
-- @usage
-- local Container = require "std.container".prototype
-- local Graph = Container { _type = "Graph" }
-- local function nodes (graph)
--   local n = 0
--   for _ in std.pairs (graph) do n = n + 1 end
--   return n
-- end
-- local g = Graph { "node1", "node2" }
-- assert (nodes (g) == 2)
local prototype = {
  _type = "Container",

  --- Metamethods
  -- @section metamethods

  --- Return a clone of this container and its metatable.
  --
  -- Like any Lua table, a container is essentially a collection of
  -- `field_n = value_n` pairs, except that field names beginning with
  -- an underscore `_` are usually kept in that container's metatable
  -- where they define the behaviour of a container object rather than
  -- being part of its actual contents.  In general, cloned objects
  -- also clone the behaviour of the object they cloned, unless...
  --
  -- When calling @{std.container.prototype}, you pass a single table
  -- argument with additional fields (and values) to be merged into the
  -- clone. Any field names beginning with an underscore `_` are copied
  -- to the clone's metatable, and all other fields to the cloned
  -- container itself.  For instance, you can change the name of the
  -- cloned object by setting the `_type` field in the argument table.
  --
  -- The `_init` private field is also special: When set to a sequence of
  -- field names, unnamed fields in the call argument table are assigned
  -- to those field names in subsequent clones, like the example below.
  --
  -- Alternatively, you can set the `_init` private field of a cloned
  -- container object to a function instead of a sequence, in which case
  -- all the arguments passed when *it* is called/cloned (including named
  -- and unnamed fields in the initial table argument, if there is one)
  -- are passed through to the `_init` function, following the nascent
  -- cloned object. See the @{mapfields} usage example below.
  -- @function prototype:__call
  -- @param ... arguments to prototype's *\_init*, often a single table
  -- @treturn prototype clone of this container, with shared or
  --   merged metatable as appropriate
  -- @usage
  -- local Cons = Container {_type="Cons", _init={"car", "cdr"}}
  -- local list = Cons {"head", Cons {"tail", nil}}
  __call = function (self, ...)
    local mt     = getmetatable (self)
    local obj_mt = mt
    local obj    = {}

    -- This is the slowest part of cloning for any objects that have
    -- a lot of fields to test and copy.
    local k, v = next (self)
    while (k) do
      obj[k] = v
      k, v = next (self, k)
    end

    if type (mt._init) == "function" then
      obj = mt._init (obj, ...)
    else
      obj = (self.mapfields or mapfields) (obj, (...), mt._init)
    end

    -- If a metatable was set, then merge our fields and use it.
    if next (getmetatable (obj) or {}) then
      obj_mt = instantiate (mt, getmetatable (obj))

      -- Merge object methods.
      if type (obj_mt.__index) == "table" and
        type ((mt or {}).__index) == "table"
      then
        obj_mt.__index = instantiate (mt.__index, obj_mt.__index)
      end
    end

    return setmetatable (obj, obj_mt)
  end,


  --- Return a string representation of this object.
  --
  -- First the container name, and then between { and } an ordered list
  -- of the array elements of the contained values with numeric keys,
  -- followed by asciibetically sorted remaining public key-value pairs.
  --
  -- This metamethod doesn't recurse explicitly, but relies upon
  -- suitable `__tostring` metamethods for non-primitive content objects.
  -- @function prototype:__tostring
  -- @treturn string stringified object representation
  -- @see tostring
  -- @usage
  -- assert (tostring (list) == 'Cons {car="head", cdr=Cons {car="tail"}}')
  __tostring = function (self)
    local n, k_ = 1, nil
    local buf = { getmetatable (self)._type, " {" }
    for _, k in ipairs (okeys (self)) do	-- for ordered public members
      local v = self[k]

      if k_ ~= nil then				-- | buffer separator
        if k ~= n and type (k_) == "number" and k_ == n - 1 then
          -- `;` separates `v` elements from `k=v` elements
          buf[#buf + 1] = "; "
        elseif k ~= nil then
	  -- `,` separator everywhere else
          buf[#buf + 1] = ", "
        end
      end

      if type (k) == "number" and k == n then	-- | buffer key/value pair
        -- render initial array-like elements as just `v`
        buf[#buf + 1] = tostring (v)
        n = n + 1
      else
        -- render remaining elements as `k=v`
        buf[#buf + 1] = tostring (k) .. "=" .. tostring (v)
      end

      k_ = k -- maintain loop invariant: k_ is previous key
    end
    buf[#buf + 1] = "}"				-- buffer object close

    return table.concat (buf)			-- stringify buffer
  end,
}


if _DEBUG.argcheck then
  local argcheck, argerror, extramsg_toomany =
      debug.argcheck, debug.argerror, debug.extramsg_toomany
  local __call = prototype.__call

  prototype.__call = function (self, ...)
    local mt = getmetatable (self)

    -- A function initialised object can be passed arguments of any
    -- type, so only argcheck non-function initialised objects.
    if type (mt._init) ~= "function" then
      local name, n = mt._type, select ("#", ...)
      -- Don't count `self` as an argument for error messages, because
      -- it just refers back to the object being called: `prototype {"x"}.
      argcheck (name, 1, "table", (...))
      if n > 1 then
        argerror (name, 2, extramsg_toomany ("argument", 1, n), 2)
      end
    end

    return __call (self, ...)
  end
end


return std.object.Module {
  prototype = setmetatable ({}, prototype),

  --- Functions
  -- @section functions

  --- Return *new* with references to the fields of *src* merged in.
  --
  -- This is the function used to instantiate the contents of a newly
  -- cloned container, as called by @{__call} above, to split the
  -- fields of a @{__call} argument table into private "_" prefixed
  -- field namess, -- which are merged into the *new* metatable, and
  -- public (everything else) names, which are merged into *new* itself.
  --
  -- You might want to use this function from `_init` functions of your
  -- own derived containers.
  -- @function mapfields
  -- @tparam table new partially instantiated clone container
  -- @tparam table src @{__call} argument table that triggered cloning
  -- @tparam[opt={}] table map key renaming specification in the form
  --   `{old_key=new_key, ...}`
  -- @treturn table merged public fields from *new* and *src*, with a
  --   metatable of private fields (if any), both renamed according to
  --   *map*
  -- @usage
  -- local Bag = Container {
  --   _type = "Bag",
  --   _init = function (new, ...)
  --     if type (...) == "table" then
  --       return container.mapfields (new, (...))
  --     end
  --     return functional.reduce (operator.set, new, ipairs, {...})
  --   end,
  -- }
  -- local groceries = Bag ("apple", "banana", "banana")
  -- local purse = Bag {_type = "Purse"} ("cards", "cash", "id")
  mapfields = debug.argscheck (
      "std.container.mapfields (table, table|object, ?table)", mapfields),
}
