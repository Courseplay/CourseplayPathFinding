--NODE

--- Internal `node` Class
-- @class table
-- @name node
-- @field x the x-coordinate of the node on the collision map
-- @field y the y-coordinate of the node on the collision map
cppf.Node = {}
cppf.Node.__index = cppf.Node

--- Inits a new `node` object
-- @class function
-- @name node:new
-- @tparam int x the x-coordinate of the node on the collision map
-- @tparam int y the y-coordinate of the node on the collision map
-- @treturn node a new `node` object
function cppf.Node:new(x,y)
	return setmetatable({x = x, y = y}, cppf.Node)
end

-- Enables the use of operator '<' to compare nodes.
-- Will be used to sort a collection of nodes in a binary heap on the basis of their F-cost
function cppf.Node.__lt(A,B)
	return (A.f < B.f)
end
