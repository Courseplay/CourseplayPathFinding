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

function cppf.Finders.HJS(finder, startNode, endNode, toClear, tunnel)

end

