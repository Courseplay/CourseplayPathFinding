--[[
@title:       Courseplay Pathfinding
@description: ---
@author:      Jakob Tischler
@date:        28 Oct 2013
@version:     0.1
]]

cppf = {}
cppf.modDir = g_currentModDirectory;
cppf.modName = "Courseplay Pathfinding";
cppf.author = "Jakob Tischler";
cppf.version = 0.1;
cppf.debug = true;

function cppf:loadMap(name)
	print(string.format("## %s v%.1f by %s loaded", cppf.modName, cppf.version, cppf.author));

	if (self.initialized) then
		return;
	end;

	--self:loadFilesInDir(cppf.modDir .. "pathfindingClasses");
	source(cppf.modDir .. "hjs_library.lua");

	self.pathPointsVis = { "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","X","Y","Z" }
	self.testCourse = "f17";
	--self.route = { from = { x = 114, z = 42 }, to = { x =  71, z = 56 } }; --f9 umrand
	--self.route = { from = { x = 60, z = 56 }, to = { x =  71, z = 1 } }; --f9 umrand
	--self.route = { from = { x = 10, z = 1 }, to = { x =  34, z = 62 } }; --w1 umrand
--	self.route = { from = { x = 2, z = 2 }, to = { x =  10, z = 30 } }; --f17
	self.hjsRoute = { from = { x = 140, z = -145 }, to = { x =  200, z = 0 } }; --f17
	
	self.allowDiagonal = false;
	self.tileSize = 5;

	self.initialized = true;
end;

function cppf:loadFilesInDir(dir)
	--self:debug("loadFilesInDir(" .. tostring(dir) .. ")");
	local files = Files:new(dir);
	for k,file in ipairs(files.files) do
		if file.isDirectory then
			self:loadFilesInDir(dir .. "/" .. file.filename);
		else
			local path = dir .. "/" .. file.filename;
			if fileExists(path) then
				--self:debug("\tsource(" .. path .. ")");
				source(path);
			else
				--self:debug("\tError: file \"" .. path .. "\" could not be loaded!");
			end;
		end;
	end;
end;

function cppf:deleteMap()
	self.initialized = false;
end;

function cppf:keyEvent(unicode, sym, modifier, isDown)
end;

local function myEvalFunc(grid, x, y)
	local category, wakable, costs = 1, true, 1;
	
	local hasFruit = courseplay:area_has_fruit(x, y, nil, grid.tileSize/2, grid.tileSize/2);
	if hasFruit then
		category = 2;
	end;
	
	return category, wakable, costs;
end

function cppf:update(dt)
	if InputBinding.hasEvent(InputBinding.CPPF_HANDLEMARKERCOURSE) then
		local course = self:findCourseplayCourse(self.testCourse);
		if course == nil then
			self:debug("CPPF: course \"" .. self.testCourse .. "\" not found");
			return;
		end;
		
		-- create Grid
		local hjsGrid = cppf.Grid:new(self.tileSize, course.waypoints, 'cx', 'cz');
		hjsGrid:setEvaluationFunction(myEvalFunc);
		hjsGrid:evaluate();
		print('Ecke 1: ' .. tostring(hjsGrid:getX(1)) .. ' / ' .. tostring(hjsGrid:getY(1)) );
		print('Ecke 3: ' .. tostring(hjsGrid:getX(#hjsGrid.map[1])) .. ' / ' .. tostring(hjsGrid:getY(#hjsGrid.map)) );
		
		-- create Finder and search a path
		local hjsFinder = cppf.Pathfinder:new(hjsGrid, 'HJS');
		hjsFinder.allowDiagonal = self.allowDiagonal;
		local hjsPath = hjsFinder:getPath(self.hjsRoute.from.x, self.hjsRoute.from.z, self.hjsRoute.to.x, self.hjsRoute.to.z)
		
		local path = hjsPath;
		if path then
			self.displayPathNodes = {};

			print(('Path found! Length: %.2f'):format(path:getLength()))
			for node, count in path:nodes() do
				print(('Step: %d - x,y=%d,%d - cat=%d'):format(count, node.x, node.y, node.category))
				
				node.letter = self.pathPointsVis[count];

				local p = {};
				p.x = hjsFinder.grid:getX(node.x);
				p.z = hjsFinder.grid:getY(node.y);
				p.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, p.x, 300, p.z) + 3;
				self.displayPathNodes[count] = p;
			end
			self:debug(self:printMap(hjsGrid));
		else
			print('no path found!')
		end
	end;

	if self.displayPathNodes ~= nil then
		--self:debug(self:tableShow(self.displayPathNodes, "self.displayPathNodes"));
		self:drawDebugPoints();
	end;

	if InputBinding.hasEvent(InputBinding.CPPF_GETTILEFROMCOORDS) and self.map ~= nil and self.mapData ~= nil then
		local testX, testZ = 0, -1100;
		local tileX, tileZ = self:getTileFromCoords(testX, testZ);
		local tileCoords = self.mapCoords[tileZ][tileX];
		self:debug(string.format("tile at coords %d,%d is: tileX=%s,tileZ=%s, tileCoords=%s,%s", testX, testZ, tostring(tileX), tostring(tileZ), tostring(tileCoords.x), tostring(tileCoords.z)));
	end;
end;

function cppf:updateTick(dt)
end;

function cppf:draw()
end;

function cppf:mouseEvent(posX, posY, isDown, isUp, button)
end;

function cppf:getTileFromCoords(x, z)
	local tileX = Utils.clamp(math.ceil((x - self.mapData.minX) / self.tileSize), 1, self.mapData.numXtilesNeeded);
	local tileZ = Utils.clamp(math.ceil((z - self.mapData.minZ) / self.tileSize), 1, self.mapData.numZtilesNeeded);
	return tileX, tileZ;
end;

function cppf:drawDebugPoints()
	for i,node in pairs(self.displayPathNodes) do
		if i == 1 then
			drawDebugPoint(node.x, node.y, node.z, 0,1,0,1);
		elseif i == #self.displayPathNodes then
			drawDebugPoint(node.x, node.y, node.z, 1,0,0,1);
		else
			drawDebugPoint(node.x, node.y, node.z, 1,1,0,1);
		end;

		if i < #self.displayPathNodes then
			local nextNode = self.displayPathNodes[i+1];
			drawDebugLine(node.x,node.y,node.z, 0,0,1, nextNode.x,nextNode.y,nextNode.z, 0,0,1);
		end;
	end;
end;

function cppf:printMap(grid)
	local map = grid.map;
	local node;
	local str = "RESULTMAP = {\r";
	for z=1,#map do
		str = str .. "\t{";
		for x=1,#map[z] do	
			if grid:isWalkableAt(x, z) then
				node = grid:getNodeAt(x,z);
				if node.letter then
					str = str .. tostring(node.letter);
				else
					str = str .. tostring(grid:getCategoryAt(x,z));
				end				 
			else
				str = str .. "x";
			end;

			if x < #map[z] then
				str = str .. ",";
			end;
		end;
		str = str .. "},\r";
	end;
	str = str .. "};";
	return str;
end;

function cppf:findCourseplayCourse(name)
	if g_currentMission.cp_courses ~= nil then
		for k,course in pairs(g_currentMission.cp_courses) do
			if course.name:lower() == name:lower() then
				return course;
			end;
		end;
	end;
	return nil;
end;

function cppf:rgba(r, g, b, a)
	return { r/255, g/255, b/255, a };
end;

function cppf:debug(str)
	if cppf.debug then
		print(str);
	end;
end;

function cppf:tableShow(t, name, indent)
	local cart -- a container
	local autoref -- for self references

	--[[ counts the number of elements in a table
local function tablecount(t)
   local n = 0
   for _, _ in pairs(t) do n = n+1 end
   return n
end
]]
	-- (RiciLake) returns true if the table is empty
	local function isemptytable(t) return next(t) == nil end

	local function basicSerialize(o)
		local so = tostring(o)
		if type(o) == "function" then
			local info = debug.getinfo(o, "S")
			-- info.name is nil because o is not a calling level
			if info.what == "C" then
				return string.format("%q", so .. ", C function")
			else
				-- the information is defined through lines
				return string.format("%q", so .. ", defined in (" ..
						info.linedefined .. "-" .. info.lastlinedefined ..
						")" .. info.source)
			end
		elseif type(o) == "number" then
			return so
		else
			return string.format("%q", so)
		end
	end

	local function addtocart(value, name, indent, saved, field)
		indent = indent or ""
		saved = saved or {}
		field = field or name

		cart = cart .. indent .. field

		if type(value) ~= "table" then
			cart = cart .. " = " .. basicSerialize(value) .. ";\n"
		else
			if saved[value] then
				cart = cart .. " = {}; -- " .. saved[value]
						.. " (self reference)\n"
				autoref = autoref .. name .. " = " .. saved[value] .. ";\n"
			else
				saved[value] = name
				--if tablecount(value) == 0 then
				if isemptytable(value) then
					cart = cart .. " = {};\n"
				else
					cart = cart .. " = {\n"
					for k, v in pairs(value) do
						k = basicSerialize(k)
						local fname = string.format("%s[%s]", name, k)
						field = string.format("[%s]", k)
						-- three spaces between levels
						addtocart(v, fname, indent .. "\t", saved, field)
					end
					cart = cart .. indent .. "};\n"
				end
			end
		end
	end

	name = name or "__unnamed__"
	if type(t) ~= "table" then
		return name .. " = " .. basicSerialize(t)
	end
	cart, autoref = "", ""
	addtocart(t, name, indent)
	return cart .. autoref
end;

addModEventListener(cppf);
