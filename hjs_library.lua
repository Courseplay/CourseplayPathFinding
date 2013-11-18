-- Grid

-- Standard evaluation function
local function evalMapAt(x,y)
	return 1, true, {straight=1, diagonal=math.sqrt(2)};
end

--[[ Horoman's Grid:
grid.limits.minX
grid.limits.maxX
grid.limits.minY
grid.limits.maxY
grid.limits.maxIndexX
grid.limits.maxIndexY
grid.tileSize
grid.map[][] = {category, walkable, costs={straight, diagonal}}
grid._evaluationFunction
grid.polygon = {points, xName, yName}
--]]

cppf.Grid = {};
cppf.Grid.__index = cppf.Grid;

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

function cppf.Grid:new(tileSize, polygon, xName, yName)
	local newGrid = {polygon={}, map={}, limits={}, _evaluationFunction=evalMapAt};
	setmetatable(newGrid, self);
	--self.__index = self;
	
	newGrid.tileSize = tileSize or 1;
	newGrid.polygon.xName = xName or 'x';
	newGrid.polygon.yName = yName or 'y';
	newGrid.polygon.points = polygon;
	newGrid:findLimits();
		
	return newGrid;
end

function cppf.Grid:getIndexAt(x, y)
	local indexX = Utils.clamp(math.ceil((x - self.limits.minX) / self.tileSize), 1, self.limits.maxIndexX);
	local indexY = Utils.clamp(math.ceil((y - self.limits.minY) / self.tileSize), 1, self.limits.maxIndexY);
	return indexX, indexY;
end

function cppf.Grid:getX(IndexX)
	local x;
	if IndexX > 0 and IndexX < self.limits.maxIndexX then
		x = self.limits.minX - self.tileSize/2 + (IndexX*self.tileSize);
	elseif IndexX == self.limits.maxIndexX then
		local prevX = (self.limits.minX - self.tileSize/2 + ((IndexX-1)*self.tileSize));
		x = prevX + (self.limits.maxX - prevX)/2;
	end
	return x
end

function cppf.Grid:getY(IndexY)
	local y;
	if IndexY > 0 and IndexY < self.limits.maxIndexY then
		y = self.limits.minY - self.tileSize/2 + (IndexY*self.tileSize);
	elseif IndexY == self.limits.maxIndexY then
		local prevY = (self.limits.minY - self.tileSize/2 + ((IndexY-1)*self.tileSize));
		y = prevY + (self.limits.maxY - prevY)/2;
	end
	return y
end

function cppf.Grid:findLimits()
	local minX, maxX
	local minY, maxY
	local x, y

	for k, point in pairs(self.polygon.points)
		x = point[self.polygon.xName];
		y = point[self.polygon.yName];
		minX = not minX and x or (x<minX and x or minX)
		maxX = not maxX and x or (x>maxX and x or maxX)
		minY = not minY and y or (y<minY and y or minY)
		maxY = not maxY and y or (y>maxY and y or maxY)
	end
	
	self.limits.minX = minX;
	self.limits.maxX = maxX;
	self.limits.minY = minY;
	self.limits.maxY = maxY;
	self.limits.maxIndexX = math.ceil((maxX-minX)/self.tileSize);
	self.limits.maxIndexY = math.ceil((maxY-minY)/self.tileSize);
end

function cppf.Grid:isPointInPolygon(x,y)
--@src: http://www.ecse.rpi.edu/Homepages/wrf/Research/Short_Notes/pnpoly.html
		
	local j;
	local point = self.polygon.points;
	local N = #point;
	local xName, yName = self.polygon.xName, self.polygon.yName;
	local inside = false;
	
	for i = 1, N do
		j = i == 1 and N or i-1;
		xi, yi = point[i][xName], point[i][yName];
		xj, yj = point[j][xName], point[j][yName];
		if ( (yi > y) ~= (yj > y) ) and (x < (xj-xi]) * (y-yi) / (yj-yi) + xi) then
			inside = not inside;
		end
	end
end

function cppf.Grid:setEvaluationFunction(evalFunction)
	self._evaluationFunction = evalFunction;
end

function cppf.Grid:evaluate()
	local category, wakable, costs;
	local x, y;
	for indexY = 1,self.limits.maxIndexY do
		y = self:getY(indexY);
		if not self.map[indexY] then
			self.map[indexY] = {};
		end
		for indexX = 1,self.limits.maxIndexX do
			x = self:getX(indexX);
			if self:isPointInPolygon(x,y) then
				category, wakable, costs = self:_evaluationFunction(x, y);
			else
				category, wakable, costs = 1, false, {straight=1, diagonal=math.sqrt(2)}
			end
			self.map[indexY][indexX] = {category, wakable, costs};
		end
	end
end

function cppf.Grid:getCategoryAt(indexX, indexY)
	return self.map[indexY][indexX].category;
end

function cppf.Grid:getNodeAt(indexX, indexY)
	local category = self:getCategoryAt(indexX, indexY);
	return cppf.NodeClass:new(indexX, indexY, category);
end

function cppf.Grid:getNeighbours(node, allowDiagonal, tunnel)
	local neighbours = {};
	for i = 1,#cppf.Grid.straightOffsets do
		local n = self:getNodeAt(node.x + cppf.Grid.straightOffsets[i].x, node.y + cppf.Grid.straightOffsets[i].y);
		if n and self:isWalkableAt(n.x, n.y) then
			neighbours[#neighbours+1] = n;
		end
	end

	if allowDiagonal then
		tunnel = not not tunnel;
		for i = 1,#cppf.Grid.diagonalOffsets do
			local n = self:getNodeAt(node.x + cppf.Grid.diagonalOffsets[i].x, node.y + cppf.Grid.diagonalOffsets[i].y);
			if n and self:isWalkableAt(n.x, n.y) then
				if tunnel then
					neighbours[#neighbours+1] = n;
				else
					-- avoid this situation:
					--  nw  w
					--  w   nw
					local skipThisNode = false;
					local n1 = self:getNodeAt(node.x+cppf.Grid.diagonalOffsets[i].x, node.y);
					local n2 = self:getNodeAt(node.x, node.y+cppf.Grid.diagonalOffsets[i].y);
					if ((n1 and n2) and not self:isWalkableAt(n1.x, n1.y) and not self:isWalkableAt(n2.x, n2.y)) then
						skipThisNode = true;
					end
					if not skipThisNode then neighbours[#neighbours+1] = n; end
				end
			end
		end
	end

	return neighbours
end

--===================================================================================
--***********************************************************************************
--===================================================================================

--PATHFINDER
--local function isAGrid(grid)
--	return getmetatable(grid) and getmetatable(getmetatable(grid)) == cppf.Grid
--end

local function collect_keys(t)
	local keys = {}
	for k,v in pairs(t) do keys[#keys+1] = k end
	return keys
end

local toClear = {}

local function reset()
	for node in pairs(toClear) do
	  node.g, node.h, node.f = nil, nil, nil
	  node.opened, node.closed, node.parent = nil, nil, nil
	end
	toClear = {}
end

local searchModes = {['DIAGONAL'] = true, ['ORTHOGONAL'] = true}

local function traceBackPath(finder, node, startNode)
	local path = cppf.Path:new()
	path.grid = finder.grid
	local lastPathCost = node.f or path:getLength()

	while node.parent do
		table.insert(path,1,node)
		node = node.parent
	end
	table.insert(path,1,startNode)
	return path lastPathCost
end

cppf.Pathfinder = {}
cppf.Pathfinder.__index = cppf.Pathfinder

function cppf.Pathfinder:new(grid, finderName, walkable)
	local newPathfinder = {}
	setmetatable(newPathfinder, cppf.Pathfinder)
	newPathfinder:setGrid(grid)
	newPathfinder:setFinder(finderName)
--	newPathfinder:setWalkable(walkable)
	newPathfinder:setMode('DIAGONAL')
	newPathfinder:setHeuristic('EUCLIDIAN')
	newPathfinder.openList = cppf.multiHeap:new()
	return newPathfinder
end

function cppf.Pathfinder:setGrid(grid)
	--assert(isAGrid(grid), 'Bad argument #1. Expected a \'grid\' object') --TODO !!!
	self.grid = grid
	self.grid.__eval = self.walkable and type(self.walkable) == 'function'
	return self
end

function cppf.Pathfinder:getGrid()
	return self.grid
end

function cppf.Pathfinder:setWalkable(walkable)
	--assert(('stringintfunctionnil'):match(type(walkable)), ('Bad argument #2. Expected \'string\', \'number\' or \'function\', got %s.'):format(type(walkable))) --TODO !!!
	self.walkable = walkable
	self.grid.__eval = type(self.walkable) == 'function'
	return self
end

function cppf.Pathfinder:getWalkable()
	return self.walkable
end

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

function cppf.Pathfinder:getFinder()
	return self.finder
end

function cppf.Pathfinder:getFinders()
	return collect_keys(cppf.Finders)
end

function cppf.Pathfinder:setHeuristic(heuristic)
	assert(cppf.Heuristics[heuristic] or (type(heuristic) == 'function'), 'Not a valid heuristic!');
	self.heuristic = cppf.Heuristics[heuristic] or heuristic
	return self
end

function cppf.Pathfinder:getHeuristic()
	return self.heuristic
end

function cppf.Pathfinder:getHeuristics()
	return collect_keys(cppf.Heuristics)
end

function cppf.Pathfinder:setMode(mode)
	assert(searchModes[mode],'Invalid mode')
	self.allowDiagonal = (mode == 'DIAGONAL')
	return self
end

function cppf.Pathfinder:getMode()
	return (self.allowDiagonal and 'DIAGONAL' or 'ORTHOGONAL')
end

function cppf.Pathfinder:getModes()
	return collect_keys(searchModes)
end

function cppf.Pathfinder:version()
	return _VERSION, _RELEASEDATE
end

function cppf.Pathfinder:getPath(startX, startY, endX, endY, tunnel)
--	reset();
	local startIndexX, startIndexY = self.grid:getIndexAt(startX, startY);
	local endIndexX, endIndexY = self.grid:getIndexAt(endX, endY);
	
	local startNode = self.grid:getNodeAt(startIndexX, startIndexY);
	local endNode = self.grid:getNodeAt(endIndexX, endIndexY);
	assert(startNode, ('Invalid location [%d, %d]'):format(startX, startY));
	assert(endNode and self.grid:isWalkableAt(endX, endY), ('Invalid or unreachable location [%d, %d]'):format(endX, endY));
	local _endNode = cppf.Finders[self.finder](self, startNode, endNode, toClear, tunnel);
	if _endNode then 
		return traceBackPath(self, _endNode, startNode);
	end
	
	return nil, 0
end

--===================================================================================
--***********************************************************************************
--===================================================================================

--HEAP
local floor = math.floor

-- Lookup for value in a table
local indexOf = function(t,v)
	for i = 1,#t do
		if t[i] == v then return i end
	end
	return nil
end

-- Default comparison function
local function f_min(a,b) 
	return a < b 
end

-- Percolates up
local function percolate_up(heap, index)
	if index == 1 then return end
	local pIndex
	if index <= 1 then return end
	if index%2 == 0 then
		pIndex =  index/2
	else
		pIndex = (index-1)/2
	end
	if not heap.sort(heap.__heap[pIndex], heap.__heap[index]) then
		heap.__heap[pIndex], heap.__heap[index] = 
		heap.__heap[index], heap.__heap[pIndex]
		percolate_up(heap, pIndex)
	end
end

local function percolate_down(heap,index)
	local lfIndex,rtIndex,minIndex
	lfIndex = 2*index
	rtIndex = lfIndex + 1
	if rtIndex > heap.size then
		if lfIndex > heap.size then
			return
		else 
			minIndex = lfIndex
		end
	else
		if heap.sort(heap.__heap[lfIndex],heap.__heap[rtIndex]) then
			minIndex = lfIndex
		else
			minIndex = rtIndex
		end
	end
	if not heap.sort(heap.__heap[index],heap.__heap[minIndex]) then
		heap.__heap[index],heap.__heap[minIndex] = heap.__heap[minIndex],heap.__heap[index]
		percolate_down(heap,minIndex)
	end
end

cppf.Heap = {};
cppf.Heap.__index = cppf.Heap

function cppf.Heap:new(template,comp)
	--return setmetatable({__heap = {}, sort = comp or f_min, size = 0}, template)
	return setmetatable({__heap = {}, sort = comp or f_min, size = 0}, template or cppf.Heap)
end

function cppf.Heap:empty()
	return (self.size==0)
end

function cppf.Heap:clear()
	self.__heap = {}
	self.size = 0
	self.sort = self.sort or f_min
	return self
end

function cppf.Heap:push(item)
	if item then
		self.size = self.size + 1
		self.__heap[self.size] = item
		percolate_up(self, self.size)
	end
  return self
end

function cppf.Heap:pop()
	local root
	if self.size > 0 then
		root = self.__heap[1]
		self.__heap[1] = self.__heap[self.size]
		self.__heap[self.size] = nil
		self.size = self.size-1
		if self.size>1 then
			percolate_down(self, 1)
		end
	end
	return root
end

function cppf.Heap:heapify(item)
	if item then
		local i = indexOf(self.__heap,item)
		if i then 
			percolate_down(self, i)
			percolate_up(self, i)
		end
		return
	end
	for i = floor(self.size/2),1,-1 do
		percolate_down(self,i)
	end
	return self
end


--[[===================================================================================--]]
--[[***********************************************************************************--]]

cppf.multiHeap = {}

function cppf.multiHeap:new(template,comp)
	local mH = {__heap = {}, sort = comp or f_min, maxHeapNr = 0, nrHeaps = 0, size = 0};
	setmetatable(mH, template or self);
	self.__index = self;
	return mH;
end

function cppf.multiHeap:empty()
	return (self.size==0);
end

function cppf.multiHeap:clear()
	self.__heap = {};
	self.sort = self.sort or f_min;	
	self.maxHeapNr = 0;
	self.nrHeaps = 0;
	self.size = 0;
	return self;
end

function cppf.multiHeap:createHeap(heapNr)
	if not self.__heap[heapNr] then
		if maxHeapNr < heapNr then
			maxHeapNr = heapNr
		end
		self.__heap[heapNr] = cppf.Heap:new(nil, self.sort);
		self.nrHeaps = self.nrHeaps + 1;
	end
end

function cppf.multiHeap:push(item, heapNr)
	if not heapNr then
		heapNr = 1;
	end
	if item then		
		if not self.__heap[heapNr] then
			self:createHeap(heapNr);
		end
		self.__heap[heapNr]:push(item);
		self.size = self.size + 1
	end
  	return self;
end
 
function cppf.multiHeap:pop(heapNr)
	local root;
	if self.size > 0 then
		if heapNr then
			if (not self.__heap[heapNr]) or self.__heap[heapNr]:empty() then
				return;
			end
		else
			heapNr = 1;
			while ( (not self.__heap[heapNr]) or self.__heap[heapNr]:empty() ) and heapNr <= self.maxHeapNr do
				heapNr = heapNr + 1;
			end
		end	
			
		if heapNr <= self.maxHeapNr then
			root = self.__heap[heapNr]:pop();
			self.size = self.size - 1;
		end
	end
	return root;
end

--===================================================================================
--***********************************************************************************
--===================================================================================

--HEURISTICS
local abs = math.abs
local sqrt = math.sqrt
local sqrt2 = sqrt(2)
local max, min = math.max, math.min

cppf.Heuristics = {}
function cppf.Heuristics.MANHATTAN(dx,dy) return abs(dx)+abs(dy) end
function cppf.Heuristics.EUCLIDIAN(dx,dy) return sqrt(dx*dx+dy*dy) end
function cppf.Heuristics.DIAGONAL(dx,dy) return max(abs(dx),abs(dy)) end
function cppf.Heuristics.CARDINTCARD(dx,dy) 
	dx, dy = abs(dx), abs(dy)
	return min(dx,dy) * sqrt2 + max(dx,dy) - min(dx,dy)
end


--===================================================================================
--***********************************************************************************
--===================================================================================

-- Nodes

cppf.NodeClass = {};

function cppf.NodeClass:new(x,y,category)
	local newNode = {x=x, y=y, category=category, inBin=false, parent=nil, h=0, f=math.huge, g={} };
	setmetatable(newNode, self);
	self.__index = self;
	
	return newNode;
end

function cppf.NodeClass.__lt(A,B)
	return (A.f < B.f)
end

--[[===================================================================================--]]

--[[ Yonaba's finder:
finder.grid
finder.openList
finder.walkable
finder.allowDiagonal
finder.heuristic
--]]


--[[
Horoman Jump Search:
Algorithm developed by Roman Hofstetter (horoman) in 2013

This algorithm solves a shortest path problem on a two dimensional discrete map
where each node belongs to a category and 
has some straight and diagonal crossing costs assigned which are grater or equal the Euclidean distance.
The categories are prioritized and the algorithm does not care about the costs of a category as long as the costs of the higher priority categories are minimized.

The algorithm is thought to be used on grid maps with areas of nodes of the same category and costs.
It is built on the so called Jump Point Search which itself has it seeds in the label correcting algorithm, in particular on the A*-algorithm.
--]]

local function findNeighbours(finder,node, tunnel)
	if node.parent then
	  local neighbours = {}
	  local x,y = node.x, node.y
	  -- Node have a parent, we will prune some neighbours
	  -- Gets the direction of move
	  local dx = (x-node.parent.x)/max(abs(x-node.parent.x),1)
	  local dy = (y-node.parent.y)/max(abs(y-node.parent.y),1)

		-- Diagonal move case
	  if dx~=0 and dy~=0 then
		local walkY, walkX

		-- Natural neighbours
		if finder.grid:isWalkableAt(x,y+dy,finder.walkable) then
		  neighbours[#neighbours+1] = finder.grid:getNodeAt(x,y+dy)
		  walkY = true
		end
		if finder.grid:isWalkableAt(x+dx,y,finder.walkable) then
		  neighbours[#neighbours+1] = finder.grid:getNodeAt(x+dx,y)
		  walkX = true
		end
		if walkX or walkY then
		  neighbours[#neighbours+1] = finder.grid:getNodeAt(x+dx,y+dy)
		end

		-- Forced neighbours
		if (not finder.grid:isWalkableAt(x-dx,y,finder.walkable)) and walkY then
		  neighbours[#neighbours+1] = finder.grid:getNodeAt(x-dx,y+dy)
		end
		if (not finder.grid:isWalkableAt(x,y-dy,finder.walkable)) and walkX then
		  neighbours[#neighbours+1] = finder.grid:getNodeAt(x+dx,y-dy)
		end

	  else
		-- Move along Y-axis case
		if dx==0 then
		  local walkY
		  if finder.grid:isWalkableAt(x,y+dy,finder.walkable) then
			neighbours[#neighbours+1] = finder.grid:getNodeAt(x,y+dy)

			-- Forced neighbours are left and right ahead along Y
			if (not finder.grid:isWalkableAt(x+1,y,finder.walkable)) then
			  neighbours[#neighbours+1] = finder.grid:getNodeAt(x+1,y+dy)
			end
			if (not finder.grid:isWalkableAt(x-1,y,finder.walkable)) then
			  neighbours[#neighbours+1] = finder.grid:getNodeAt(x-1,y+dy)
			end
		  end
		  -- In case diagonal moves are forbidden : Needs to be optimized
		  if not finder.allowDiagonal then
			if finder.grid:isWalkableAt(x+1,y,finder.walkable) then
			  neighbours[#neighbours+1] = finder.grid:getNodeAt(x+1,y)
			end
			if finder.grid:isWalkableAt(x-1,y,finder.walkable)
			  then neighbours[#neighbours+1] = finder.grid:getNodeAt(x-1,y)
			end
		  end
		else
		-- Move along X-axis case
		  if finder.grid:isWalkableAt(x+dx,y,finder.walkable) then
			neighbours[#neighbours+1] = finder.grid:getNodeAt(x+dx,y)

			-- Forced neighbours are up and down ahead along X
			if (not finder.grid:isWalkableAt(x,y+1,finder.walkable)) then
			  neighbours[#neighbours+1] = finder.grid:getNodeAt(x+dx,y+1)
			end
			if (not finder.grid:isWalkableAt(x,y-1,finder.walkable)) then
			  neighbours[#neighbours+1] = finder.grid:getNodeAt(x+dx,y-1)
			end
		  end
		  -- : In case diagonal moves are forbidden
		  if not finder.allowDiagonal then
			if finder.grid:isWalkableAt(x,y+1,finder.walkable) then
			  neighbours[#neighbours+1] = finder.grid:getNodeAt(x,y+1)
			end
			if finder.grid:isWalkableAt(x,y-1,finder.walkable) then
			  neighbours[#neighbours+1] = finder.grid:getNodeAt(x,y-1)
			end
		  end
		end
	  end
	  return neighbours
	end

	-- Node do not have parent, we return all neighbouring nodes
	return finder.grid:getNeighbours(node, finder.walkable, finder.allowDiagonal, tunnel)
end

local function jump(finder, node, parent, endNode)
	if not node then return end

	local x,y = node.x, node.y
	local dx, dy = x - parent.x,y - parent.y

	-- If the node to be examined is unwalkable, return nil
	if not finder.grid:isWalkableAt(x,y,finder.walkable) then return end

	-- If the node to be examined is the endNode, return this node
	if node == endNode then return node end

	-- Diagonal search case
	if dx~=0 and dy~=0 then
		-- Current node is a jump point if one of his leftside/rightside neighbours ahead is forced
		if (finder.grid:isWalkableAt(x-dx,y+dy,finder.walkable) and (not finder.grid:isWalkableAt(x-dx,y,finder.walkable))) or
		(finder.grid:isWalkableAt(x+dx,y-dy,finder.walkable) and (not finder.grid:isWalkableAt(x,y-dy,finder.walkable))) then
			return node
		end
	else

		-- Search along X-axis case
		if dx~=0 then
			if finder.allowDiagonal then
				-- Current node is a jump point if one of his upside/downside neighbours is forced
				if (finder.grid:isWalkableAt(x+dx,y+1,finder.walkable) and (not finder.grid:isWalkableAt(x,y+1,finder.walkable))) or
				(finder.grid:isWalkableAt(x+dx,y-1,finder.walkable) and (not finder.grid:isWalkableAt(x,y-1,finder.walkable))) then
					return node
				end
			else
				-- : in case diagonal moves are forbidden
				if finder.grid:isWalkableAt(x+1,y,finder.walkable) or finder.grid:isWalkableAt(x-1,y,finder.walkable) then return node end
			end
		else
			-- Search along Y-axis case
			-- Current node is a jump point if one of his leftside/rightside neighbours is forced
			if finder.allowDiagonal then
				if (finder.grid:isWalkableAt(x+1,y+dy,finder.walkable) and (not finder.grid:isWalkableAt(x+1,y,finder.walkable))) or
				(finder.grid:isWalkableAt(x-1,y+dy,finder.walkable) and (not finder.grid:isWalkableAt(x-1,y,finder.walkable))) then
					return node
				end
			else
				-- : in case diagonal moves are forbidden
				if finder.grid:isWalkableAt(x,y+1,finder.walkable) or finder.grid:isWalkableAt(x,y-1,finder.walkable) then return node end
			end
		end
	end

	-- Recursive horizontal/vertical search
	if dx~=0 and dy~=0 then
		if jump(finder,finder.grid:getNodeAt(x+dx,y),node,endNode) then return node end
		if jump(finder,finder.grid:getNodeAt(x,y+dy),node,endNode) then return node end
	end

	-- Recursive diagonal search
	if finder.allowDiagonal then
		if finder.grid:isWalkableAt(x+dx,y,finder.walkable) or finder.grid:isWalkableAt(x,y+dy,finder.walkable) then
			return jump(finder,finder.grid:getNodeAt(x+dx,y+dy),node,endNode)
		end
	end
end

local function identifySuccessors(finder,node,endNode,toClear, tunnel)
	-- Gets the valid neighbours of the given node
	-- Looks for a jump point in the direction of each neighbour
	local neighbours = findNeighbours(finder,node, tunnel)
	for i = #neighbours,1,-1 do
		local skip = false
		local neighbour = neighbours[i]
		local jumpNode = jump(finder,neighbour,node,endNode)

		-- : in case a diagonal jump point was found in straight mode, skip it.
		if jumpNode and not finder.allowDiagonal then
			if ((jumpNode.x ~= node.x) and (jumpNode.y ~= node.y)) then skip = true end
		end

		--[[
		-- Hacky trick to discard "tunneling" in diagonal mode search for the first step
		if jumpNode and finder.allowDiagonal and not step_first then
			if jumpNode.x == endNode.x and jumpNode.y == endNode.y then
				step_first = true
				if not skip then
					skip = testFirstStep(finder, jumpNode, node)
				end
			end
		end
		--]]

		-- Performs regular A-star on a set of jump points
		if jumpNode and not skip then
			-- Update the jump node and move it in the closed list if it wasn't there
			if not jumpNode.closed then
				local extraG = cppf.Heuristics.EUCLIDIAN(jumpNode.x-node.x,jumpNode.y-node.y)
				local newG = node.g + extraG
				if not jumpNode.opened or newG < jumpNode.g then
					toClear[jumpNode] = true -- Records this node to reset its properties later.
					jumpNode.g = newG
					jumpNode.h = jumpNode.h or (finder.heuristic(jumpNode.x-endNode.x,jumpNode.y-endNode.y))
					jumpNode.f = jumpNode.g+jumpNode.h
					jumpNode.parent = node
					if not jumpNode.opened then
						finder.openList:push(jumpNode)
						jumpNode.opened = true
						if not step_first then step_first = true end
					else
						finder.openList:heapify(jumpNode)
					end
				end
			end
		end
	end
end

function cppf.Finders.HJS(finder, startNode, endNode, toClear, tunnel)
	step_first = false
	startNode.g, startNode.f = 0,0
	finder.openList:clear()
	finder.openList:push(startNode)
	startNode.opened = true
	toClear[startNode] = true

	local node
	while not finder.openList:empty() do
		-- Pops the lowest F-cost node, moves it in the closed list
		node = finder.openList:pop()
		node.closed = true
		-- If the popped node is the endNode, return it
		if node == endNode then
			return node
		end
		-- otherwise, identify successors of the popped node
		identifySuccessors(finder, node, endNode, toClear, tunnel)
	end

	-- No path found, return nil
	return nil
end

