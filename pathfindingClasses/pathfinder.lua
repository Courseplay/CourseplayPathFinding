-- Is arg a grid object
local function isAGrid(grid)
--print("isAGrid: " .. tostring(getmetatable(grid)))
return getmetatable(grid) and getmetatable(getmetatable(grid)) == cppf.Grid
end


-- Collect keys in an array
local function collect_keys(t)
	local keys = {}
	for k,v in pairs(t) do keys[#keys+1] = k end
	return keys
end

-- Will keep track of all nodes expanded during the search
-- to easily reset their properties for the next pathfinding call
local toClear = {}

-- Resets properties of nodes expanded during a search
-- This is a lot faster than resetting all nodes
-- between consecutive pathfinding requests
local function reset()
	for node in pairs(toClear) do
	  node.g, node.h, node.f = nil, nil, nil
	  node.opened, node.closed, node.parent = nil, nil, nil
	end
	toClear = {}
end

-- Keeps track of the last computed path cost
local lastPathCost = 0

-- Availables search modes
local searchModes = {['DIAGONAL'] = true, ['ORTHOGONAL'] = true}

-- Performs a traceback from the goal node to the start node
-- Only happens when the path was found
local function traceBackPath(finder, node, startNode)
	local path = cppf.Path:new()
	path.grid = finder.grid
	lastPathCost = node.f or path:getLength()

	while true do
		if node.parent then
			table.insert(path,1,node)
			node = node.parent
		else
			table.insert(path,1,startNode)
			return path
		end
	end
end

--- The `pathfinder` class
-- @class table
-- @name pathfinder
cppf.Pathfinder = {}
cppf.Pathfinder.__index = cppf.Pathfinder

--- Inits a new `pathfinder` object
-- @class function
-- @name pathfinder:new
-- @tparam grid grid a `grid` object
-- @tparam[opt] string finderName the name of the `finder` (search algorithm) to be used for further searches.
-- Defaults to `ASTAR` when not given. Use @{pathfinder:getFinders} to get the full list of available finders..
-- @tparam[optchain] string|int|function walkable the value for walkable nodes on the passed-in map array.
-- If this parameter is a function, it should be prototyped as `f(value)`, returning a boolean:
-- `true` when value matches a *walkable* node, `false` otherwise.
-- @treturn pathfinder a new `pathfinder` object
function cppf.Pathfinder:new(grid, finderName, walkable)
	local newPathfinder = {}
	setmetatable(newPathfinder, cppf.Pathfinder)
	newPathfinder:setGrid(grid)
	newPathfinder:setFinder(finderName)
	newPathfinder:setWalkable(walkable)
	newPathfinder:setMode('DIAGONAL')
	newPathfinder:setHeuristic('MANHATTAN')
	newPathfinder.openList = cppf.Heap:new()
	return newPathfinder
end

--- Sets a `grid` object. Defines the `grid` on which the `pathfinder` will make path searches.
-- @class function
-- @name pathfinder:setGrid
-- @tparam grid grid a `grid` object
function cppf.Pathfinder:setGrid(grid)
	--assert(isAGrid(grid), 'Bad argument #1. Expected a \'grid\' object') --TODO
	self.grid = grid
	self.grid.__eval = self.walkable and type(self.walkable) == 'function'
	return self
end

--- Returns the `grid` object. Returns a reference to the internal `grid` object used by the `pathfinder` object.
-- @class function
-- @name pathfinder:getGrid
-- @treturn grid the `grid` object
function cppf.Pathfinder:getGrid()
return self.grid
end

--- Sets the `walkable` value or function.
-- @class function
-- @name pathfinder:setWalkable
-- @tparam string|int|function walkable the value for walkable nodes on the passed-in map array.
-- If this parameter is a function, it should be prototyped as `f(value)`, returning a boolean:
-- `true` when value matches a *walkable* node, `false` otherwise.
function cppf.Pathfinder:setWalkable(walkable)
	--assert(('stringintfunctionnil'):match(type(walkable)), ('Bad argument #2. Expected \'string\', \'number\' or \'function\', got %s.'):format(type(walkable))) --TODO
	self.walkable = walkable
	self.grid.__eval = type(self.walkable) == 'function'
	return self
end

--- Gets the `walkable` value or function.
-- @class function
-- @name pathfinder:getWalkable
-- @treturn string|int|function the `walkable` previously set
function cppf.Pathfinder:getWalkable()
	return self.walkable
end

--- Sets a finder. The finder refers to the search algorithm used by the `pathfinder` object.
-- The default finder is `ASTAR`. Use @{pathfinder:getFinders} to get the list of available finders.
-- @class function
-- @name pathfinder:setFinder
-- @tparam string finderName the name of the finder to be used for further searches.
-- @see pathfinder:getFinders
function cppf.Pathfinder:setFinder(finderName)
	local finderName = finderName
	if not finderName then
		if not self.finder then 
			finderName = 'ASTAR' 
		else return 
		end
	end
	assert(cppf.Finders[finderName],'Not a valid finder name!')
	self.finder = finderName
	return self
end

--- Gets the name of the finder being used. The finder refers to the search algorithm used by the `pathfinder` object.
-- @class function
-- @name pathfinder:getFinder
-- @treturn string the name of the finder to be used for further searches.
function cppf.Pathfinder:getFinder()
	return self.finder
end

--- Gets the list of all available finders names.
-- @class function
-- @name pathfinder:getFinders
-- @treturn {string,...} array of finders names.
function cppf.Pathfinder:getFinders()
	return collect_keys(cppf.Finders)
end

--- Set a heuristic. This is a function internally used by the `pathfinder` to get the optimal path during a search.
-- Use @{pathfinder:getHeuristics} to get the list of all available heuristics. One can also defined
-- his own heuristic function.
-- @class function
-- @name pathfinder:setHeuristic
-- @tparam function|string heuristic a heuristic function, prototyped as `f(dx,dy)` or a string.
-- @see pathfinder:getHeuristics
function cppf.Pathfinder:setHeuristic(heuristic)
	assert(cppf.Heuristics[heuristic] or (type(heuristic) == 'function'), 'Not a valid heuristic!');
	self.heuristic = cppf.Heuristics[heuristic] or heuristic
	return self
end

--- Gets the heuristic used. Returns the function itself.
-- @class function
-- @name pathfinder:getHeuristic
-- @treturn function the heuristic function being used by the `pathfinder` object
function cppf.Pathfinder:getHeuristic()
	return self.heuristic
end

--- Gets the list of all available heuristics.
-- @class function
-- @name pathfinder:getHeuristics
-- @treturn {string,...} array of heuristic names.
function cppf.Pathfinder:getHeuristics()
	return collect_keys(cppf.Heuristics)
end

--- Changes the search mode. Defines a new search mode for the `pathfinder` object.
-- The default search mode is `DIAGONAL`, which implies 8-possible directions when moving (north, south, east, west and diagonals).
-- In `ORTHOGONAL` mode, only 4-directions are allowed (north, south, east and west).
-- Use @{pathfinder:getModes} to get the list of all available search modes.
-- @class function
-- @name pathfinder:setMode
-- @tparam string mode the new search mode.
-- @see pathfinder:getModes
function cppf.Pathfinder:setMode(mode)
	assert(searchModes[mode],'Invalid mode')
	self.allowDiagonal = (mode == 'DIAGONAL')
	return self
end

--- Gets the search mode.
-- @class function
-- @name pathfinder:getMode
-- @treturn string the current search mode
function cppf.Pathfinder:getMode()
	return (self.allowDiagonal and 'DIAGONAL' or 'ORTHOGONAL')
end

--- Gets the list of all available search modes.
-- @class function
-- @name pathfinder:getModes
-- @treturn {string,...} array of search modes.
function cppf.Pathfinder:getModes()
	return collect_keys(searchModes)
end

--- Returns version and release date.
-- @class function
-- @name pathfinder:version
-- @treturn string the version of the current implementation
-- @treturn string the release of the current implementation
function cppf.Pathfinder:version()
	return _VERSION, _RELEASEDATE
end

--- Calculates a path. Returns the path from location `<startX, startY>` to location `<endX, endY>`.
-- Both locations must exist on the collision map.
-- @class function
-- @name pathfinder:getPath
-- @tparam number startX the x-coordinate for the starting location
-- @tparam number startY the y-coordinate for the starting location
-- @tparam number endX the x-coordinate for the goal location
-- @tparam number endY the y-coordinate for the goal location
-- @tparam[opt] bool tunnel Whether or not the pathfinder can tunnel though walls diagonally (not compatible with `Jump Point Search`)
-- @treturn {node,...} a path (array of `nodes`) when found, otherwise `nil`
-- @treturn number the path length when found, `0` otherwise
function cppf.Pathfinder:getPath(startX, startY, endX, endY, tunnel)
	reset();
	local startNode = self.grid:getNodeAt(startX, startY);
	local endNode = self.grid:getNodeAt(endX, endY);
	assert(startNode, ('Invalid location [%d, %d]'):format(startX, startY));
	assert(endNode and self.grid:isWalkableAt(endX, endY), ('Invalid or unreachable location [%d, %d]'):format(endX, endY));
	local _endNode = cppf.Finders[self.finder](self, startNode, endNode, toClear, tunnel)
	if _endNode then 
		return traceBackPath(self, _endNode, startNode), lastPathCost  --  lastPathCost seems to be global
	end
	lastPathCost = 0
	return nil, lastPathCost
end
