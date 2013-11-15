--GRID
cppf.Grid = {};
cppf.Grid.__index = cppf.Grid;
--local Grid_mt = Class(cppf.Grid);

cppf.PreProcessGrid  = setmetatable({}, cppf.Grid);
cppf.PostProcessGrid = setmetatable({}, cppf.Grid);
cppf.PreProcessGrid.__index = cppf.PreProcessGrid;
cppf.PostProcessGrid.__index = cppf.PostProcessGrid;
cppf.PreProcessGrid.__call = function(self,x,y)
	return self:getNodeAt(x,y);
end;
cppf.PostProcessGrid.__call = function(self,x,y,create)
	if create then
		return self:getNodeAt(x,y);
	end;
	return self.nodes[y] and self.nodes[y][x];
end;

--- Inits a new `grid` object
function cppf.Grid:new(map, processOnDemand)
	--local self = {};
	--setmetatable(self, Grid_mt)
	self.map = cppf:type(map) == 'string' and cppf.Grid:parseStringMap(map) or map;
	assert(cppf.Grid:isMap(map) or cppf.Grid:isStringMap(map), ('Bad argument #1. Not a valid map'));
	assert(cppf:type(processOnDemand) == 'boolean' or not processOnDemand, ('Bad argument #2. Expected \'boolean\', got %s.'):format(cppf:type(processOnDemand)));
	if processOnDemand then
		return cppf.PostProcessGrid:new(map, walkable); --TODO: where does walkable come from?
	end;
	return cppf.PreProcessGrid:new(map, walkable); --TODO: where does walkable come from?
end;

--- Checks walkability. Tests if `node` [x,y] exists on the collision map and is walkable
function cppf.Grid:isWalkableAt(x, y, walkable)
	local nodeValue = self.map[y] and self.map[y][x];
	if nodeValue then
		if not walkable then return true end;
	else 
		return false
	end;
	if self.__eval then 
		return walkable(nodeValue);
	end;
	return (nodeValue == walkable);
end;

--- Gets the `grid` width.
-- @class function
-- @name grid:getWidth
-- @treturn int the `grid` object width
function cppf.Grid:getWidth()
	return self.width
end

--- Gets the `grid` height.
-- @class function
-- @name grid:getHeight
-- @treturn int the `grid` object height
function cppf.Grid:getHeight()
	return self.height
end

--- Gets the collision map.
-- @class function
-- @name grid:getMap
-- @treturn {{value},...} the collision map previously passed to the `grid` object on initalization
function cppf.Grid:getMap()
	return self.map
end

--- Gets the `grid` nodes.
-- @class function
-- @name grid:getNodes
-- @treturn {{node},...} the `grid` nodes
function cppf.Grid:getNodes()
	return self.nodes
end

--- Returns the neighbours of a given `node` on a `grid`
-- @class function
-- @name grid:getNeighbours
-- @tparam node node `node` object
-- @tparam string|int|function walkable the value for walkable nodes on the passed-in map array.
-- If this parameter is a function, it should be prototyped as `f(value)`, returning a boolean:
-- `true` when value matches a *walkable* node, `false` otherwise.
-- @tparam[opt] bool allowDiagonal whether or not adjacent nodes (8-directions moves) are allowed
-- @tparam[optchain] bool tunnel Whether or not the pathfinder can tunnel though walls diagonally
-- @treturn {node,...} an array of nodes neighbouring a passed-in node on the collision map
function cppf.Grid:getNeighbours(node, walkable, allowDiagonal, tunnel)
	local neighbours = {}
	for i = 1,#cppf.Grid.straightOffsets do
		local n = self:getNodeAt(node.x + cppf.Grid.straightOffsets[i].x, node.y + cppf.Grid.straightOffsets[i].y)
		if n and self:isWalkableAt(n.x, n.y, walkable) then
			neighbours[#neighbours+1] = n
		end
	end

	if not allowDiagonal then return neighbours end

	tunnel = not not tunnel
	for i = 1,#cppf.Grid.diagonalOffsets do
		local n = self:getNodeAt(node.x + cppf.Grid.diagonalOffsets[i].x, node.y + cppf.Grid.diagonalOffsets[i].y)
		if n and self:isWalkableAt(n.x, n.y, walkable) then
			if tunnel then
				neighbours[#neighbours+1] = n
			else
				local skipThisNode = false
				local n1 = self:getNodeAt(node.x+cppf.Grid.diagonalOffsets[i].x, node.y)
				local n2 = self:getNodeAt(node.x, node.y+cppf.Grid.diagonalOffsets[i].y)
				if ((n1 and n2) and not self:isWalkableAt(n1.x, n1.y, walkable) and not self:isWalkableAt(n2.x, n2.y, walkable)) then
					skipThisNode = true
				end
				if not skipThisNode then neighbours[#neighbours+1] = n end
			end
		end
	end

	return neighbours
end --END getNeightbours()

--- Iterates on nodes on the grid. When given no args, will iterate on every single node
-- on the grid, in case the grid is pre-processed. Passing `lx, ly, ex, ey` args will iterate
-- on nodes inside a bounding-rectangle delimited by those coordinates.
-- @class function
-- @name grid:iter
-- @tparam[opt] int lx the leftmost x-coordinate coordinate of the rectangle
-- @tparam[optchain] int ly the topmost y-coordinate of the rectangle
-- @tparam[optchain] int ex the rightmost x-coordinate of the rectangle
-- @tparam[optchain] int ey the bottom-most y-coordinate of the rectangle
-- @treturn node a node on the collision map, upon each iteration step
function cppf.Grid:iter(lx,ly,ex,ey)
	local min_x = lx or self.min_bound_x
	local min_y = ly or self.min_bound_y
	local max_x = ex or self.max_bound_x
	local max_y = ey or self.max_bound_y

	local x, y
	y = min_y
	return function()
		x = not x and min_x or x+1
		if x>max_x then
			x = min_x
			y = y+1
		end
		if y > max_y then
			y = nil
		end
		return self.nodes[y] and self.nodes[y][x] or self:getNodeAt(x,y)
	end
end

--- Each transformation. Executes a function on each `node` in the `grid`, passing the `node` as the first arg to function `f`.
-- @class function
-- @name grid:each
-- @tparam function f a function prototyped as `f(node,...)`
-- @tparam[opt] vararg ... args to be passed to function `f`
function cppf.Grid:each(f,...)
	for node in self:iter() do 
		f(node,...)
	end
end

--- Each in range transformation. Executes a function on each `node` in the range of a rectangle of cells, passing the `node` as the first arg to function `f`.
-- @class function
-- @name grid:eachRange
-- @tparam int lx the leftmost x-coordinate coordinate of the rectangle
-- @tparam int ly the topmost y-coordinate of the rectangle
-- @tparam int ex the rightmost x-coordinate of the rectangle
-- @tparam int ey the bottom-most y-coordinate of the rectangle
-- @tparam function f a function prototyped as `f(node,...)`
-- @tparam[opt] vararg ... args to be passed to function `f`
function cppf.Grid:eachRange(lx,ly,ex,ey,f,...)
	for node in self:iter(lx,ly,ex,ey) do
		f(node,...)
	end
end

--- Map transformation. Maps function `f(node,...)` on each `node` in a given range, passing the `node` as the first arg to function `f`. The passed-in function should return a `node` object.
-- @class function
-- @name grid:imap
-- @tparam function f a function prototyped as `f(node,...)`
-- @tparam[opt] vararg ... args to be passed to function `f`
function cppf.Grid:imap(f,...)
	for node in self:iter() do
		node = f(node,...)
	end
end

--- Map in range transformation. Maps `f(node,...)` on each `nod`e in the range of a rectangle of cells, passing the `node` as the first arg to function `f`. The passed-in function should return a `node` object.
-- @class function
-- @name grid:imapRange
-- @tparam int lx the leftmost x-coordinate coordinate of the rectangle
-- @tparam int ly the topmost y-coordinate of the rectangle
-- @tparam int ex the rightmost x-coordinate of the rectangle
-- @tparam int ey the bottom-most y-coordinate of the rectangle
-- @tparam function f a function prototyped as `f(node,...)`
-- @tparam[opt] vararg ... args to be passed to function `f`
function cppf.Grid:imapRange(lx,ly,ex,ey,f,...)
	for node in self:iter(lx,ly,ex,ey) do
		node = f(node,...)
	end
end


-- Specialized grids
-- Inits a preprocessed grid
function cppf.PreProcessGrid:new(map)
	local newGrid = {}
	newGrid.map = map
	newGrid.nodes, newGrid.min_bound_x, newGrid.max_bound_x, newGrid.min_bound_y, newGrid.max_bound_y = cppf.Grid:buildGrid(newGrid.map)
	newGrid.width = (newGrid.max_bound_x-newGrid.min_bound_x)+1
	newGrid.height = (newGrid.max_bound_y-newGrid.min_bound_y)+1
	return setmetatable(newGrid,cppf.PreProcessGrid)
end

-- Inits a postprocessed grid
function cppf.PostProcessGrid:new(map)
	local newGrid = {}
	newGrid.map = map
	newGrid.nodes = {}
	newGrid.min_bound_x, newGrid.max_bound_x, newGrid.min_bound_y, newGrid.max_bound_y = cppf.Grid:getBounds(newGrid.map)
	newGrid.width = (newGrid.max_bound_x-newGrid.min_bound_x)+1
	newGrid.height = (newGrid.max_bound_y-newGrid.min_bound_y)+1
	return setmetatable(newGrid,cppf.PostProcessGrid)
end

--- Returns the `node`[x,y] on a `grid`.
-- @class function
-- @name grid:getNodeAt
-- @tparam int x the x-coordinate coordinate
-- @tparam int y the y-coordinate coordinate
-- @treturn node a `node` object
-- Gets the node at location <x,y> on a preprocessed grid
function cppf.PreProcessGrid:getNodeAt(x,y)
	return self.nodes[y] and self.nodes[y][x] or nil
end

-- Gets the node at location <x,y> on a postprocessed grid
function cppf.PostProcessGrid:getNodeAt(x,y)
	if not x or not y then return end
	if cppf.Grid:outOfRange(x,self.min_bound_x,self.max_bound_x) then return end
	if cppf.Grid:outOfRange(y,self.min_bound_y,self.max_bound_y) then return end
	if not self.nodes[y] then self.nodes[y] = {} end
	if not self.nodes[y][x] then self.nodes[y][x] = cppf.Node:new(x,y) end
	return self.nodes[y][x]
end

---------------------------------------------------------------------

-- Real count of for values in an array
local size = function(t)
	local count = 0
	for k,v in pairs(t) do count = count+1 end
	return count
end

-- Checks array contents
local check_contents = function(t,...)
	local n_count = size(t)
	if n_count < 1 then return false end
	local init_count = t[0] and 0 or 1
	local n_count = (t[0] and n_count-1 or n_count)
	local types = {...}
	if types then types = table.concat(types) end
	for i=init_count,n_count,1 do
		if not t[i] then return false end
		if types then
			if not types:match(cppf:type(t[i])) then return false end
		end
	end
	return true
end

-- Checks if m is a regular map
function cppf.Grid:isMap(m)
	if not check_contents(m, 'table') then return false end
	local lsize = size(m[next(m)])
	for k,v in pairs(m) do
		if not check_contents(m[k], 'string', 'int') then return false end
		if size(v)~=lsize then return false end
	end
	return true
end

-- Is arg a valid string map
function cppf.Grid:isStringMap(s)
	if cppf:type(m) ~= 'string' then return false end
	local w
	for row in s:gmatch('[^\n\r]+') do
		if not row then return false end
		w = w or #row
		if w ~= #row then return false end
	end
	return true
end

-- Parses a map
function cppf.Grid:parseStringMap(str)
	local map = {}
	local w, h
	for line in str:gmatch('[^\n\r]+') do
		if line then
			w = not w and #line or w
			assert(#line == w, 'Error parsing map, rows must have the same size!')
			h = (h or 0) + 1
			map[h] = {}
			for char in line:gmatch('.') do 
				map[h][#map[h]+1] = char 
			end
		end
	end
	return map
end

-- Postprocessing : Get map bounds
function cppf.Grid:getBounds(map)
	local min_bound_x, max_bound_x
	local min_bound_y, max_bound_y

	for y in pairs(map) do
		min_bound_y = not min_bound_y and y or (y<min_bound_y and y or min_bound_y)
		max_bound_y = not max_bound_y and y or (y>max_bound_y and y or max_bound_y)
		for x in pairs(map[y]) do
			min_bound_x = not min_bound_x and x or (x<min_bound_x and x or min_bound_x)
			max_bound_x = not max_bound_x and x or (x>max_bound_x and x or max_bound_x)
		end
	end
	return min_bound_x,max_bound_x,min_bound_y,max_bound_y
end

-- Preprocessing
function cppf.Grid:buildGrid(map)
	local min_bound_x, max_bound_x
	local min_bound_y, max_bound_y

	local nodes = {}
	for y in pairs(map) do
		min_bound_y = not min_bound_y and y or (y<min_bound_y and y or min_bound_y)  -- Explanation 1; returns y when called the first time, returns y if y<min_bound_y, returns min_bound_y else
		max_bound_y = not max_bound_y and y or (y>max_bound_y and y or max_bound_y)
		nodes[y] = {}
		for x in pairs(map[y]) do
			min_bound_x = not min_bound_x and x or (x<min_bound_x and x or min_bound_x)
			max_bound_x = not max_bound_x and x or (x>max_bound_x and x or max_bound_x)
			nodes[y][x] = cppf.Node:new(x,y)
		end
	end
	return nodes, (min_bound_x or 0), (max_bound_x or 0), (min_bound_y or 0), (max_bound_y or 0)
end
--[[
Explanation 1:
	'not' is executed before 'and' is executed before 'or'
	not returns:
		true if input is nil or false
		false else
	and returns:	
		the left side if nil and false are at the sides
		nil if one side is nil and the other non-false and non-nil
		false if one side is false and the other non-false and non-nil
		the right side if both sides are non-nil and non-false
	or returns:
		nil if both sides are nil
		the non-nil side if one side is nil
		the non-false side if both sides are non-nil and one is false
		the left side if both sides are non-nil and non-false
		--> if left side is non-nil and non-false, right side will not be executed as it will return the left side anyway
--]]

-- Checks if a value is out of and interval [lowerBound,upperBound]
function cppf.Grid:outOfRange(i,lowerBound,upperBound)
	return (i< lowerBound or i > upperBound)
end

-- Offsets for straights moves
cppf.Grid.straightOffsets = {
	{x = 1, y = 0} --[[W]], {x = -1, y =  0}, --[[E]]
	{x = 0, y = 1} --[[S]], {x =  0, y = -1}, --[[N]]
}

-- Offsets for diagonal moves
cppf.Grid.diagonalOffsets = {
	{x = -1, y = -1} --[[NW]], {x = 1, y = -1}, --[[NE]]
	{x = -1, y =  1} --[[SW]], {x = 1, y =  1}, --[[SE]]
}

