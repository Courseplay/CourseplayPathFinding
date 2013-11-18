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
	self.route = { from = { x = 2, z = 2 }, to = { x =  10, z = 30 } }; --f17
	self.hjsRoute = { from = { x = 140, z = -145 }, to = { x =  200, z = 0 } }; --f17

	self.tileSize = 5;
	self.walkable = 0;
	self.unwalkable = 1;

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
	
	local hasFruit = courseplay:area_has_fruit(x, y, nil, grid.tileSize/2, grid.tileSize/2); --TODO: current fruit --> e.g. combine.grainTankFillType --> FruitUtil.fillTypeToFruitType[fillType]
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
		
		local hjsGrid = cppf.Grid:new(5, course.waypoints, 'cx', 'cz');
		hjsGrid:setEvaluationFunction(myEvalFunc);
		hjsGrid:evaluate();
		print('Ecke 1: ' .. tostring(hjsGrid:getX(1)) .. ' / ' .. tostring(hjsGrid:getY(1)) );
		print('Ecke 3: ' .. tostring(hjsGrid:getX(#hjsGrid.map[1])) .. ' / ' .. tostring(hjsGrid:getY(#hjsGrid.map)) );
		local hjsFinder = cppf.Pathfinder:new(hjsGrid, 'HJS');		
		local hjsPath = hjsFinder:getPath(self.hjsRoute.from.x, self.hjsRoute.from.z, self.hjsRoute.to.x, self.hjsRoute.to.z)
		
--		self.map,self.mapCoords = self:createGridMapFromCourse(course);
--		if self.map == nil or #self.map == 0 then
--			self:debug("CPPF: map for \"" .. self.testCourse .. "\" could not be created");
--			return;
--		end;
--
--		local grid = cppf.Grid:new(self.map);
--		local myFinder = cppf.Pathfinder:new(grid, 'JPS', 0);
--
--		-- Calculates the path, and its length
--		local path = myFinder:getPath(self.route.from.x, self.route.from.z, self.route.to.x, self.route.to.z)
		local path = hjsPath;
		if path then
			self.displayPathNodes = {};

			print(('Path found! Length: %.2f'):format(path:getLength()))
			for node, count in path:nodes() do
				--print(('Step: %d - x: %d - y: %d'):format(count, node:getX(), node:getY()))
				print(('Step: %d - x,y=%d,%d - cat=%d'):format(count, node.x, node.y, node.category))
				--self.map[node.y][node.x] = count;
				
				-- todo: fix
--				self.map[node.y][node.x] = self.pathPointsVis[count];

				local p = {};
				p.x = hjsFinder.grid:getX(node.x);
				p.z = hjsFinder.grid:getY(node.y);
--				p.x = self.mapCoords[node.y][node.x].x;
--				p.z = self.mapCoords[node.y][node.x].z;
				p.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, p.x, 300, p.z) + 3;
				self.displayPathNodes[count] = p;
			end
			-- todo fix
--			self:debug(self:printMap(self.map));
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

function cppf:createGridMapFromCourse(course)
	self.mapData = {};
	self.mapData.xValues, self.mapData.zValues = {}, {};
	self.mapData.minX, self.mapData.maxX, self.mapData.minZ, self.mapData.maxZ = 999999, -999999, 999999, -999999;
	for i,wp in pairs(course.waypoints) do  --actually this is not a good way to go through the waypoints, one should use ipairs. With pairs, there is no guaranty that the waypoints come in the right order (which is defently needed here for Polygon operations!)
		if wp.cx < self.mapData.minX then self.mapData.minX = wp.cx; end;
		if wp.cx > self.mapData.maxX then self.mapData.maxX = wp.cx; end;
		if wp.cz < self.mapData.minZ then self.mapData.minZ = wp.cz; end;
		if wp.cz > self.mapData.maxZ then self.mapData.maxZ = wp.cz; end;
		table.insert(self.mapData.xValues, wp.cx);--why just saving it again?
		table.insert(self.mapData.zValues, wp.cz);
	end;
	self.mapData.width, self.mapData.height = self.mapData.maxX - self.mapData.minX, self.mapData.maxZ - self.mapData.minZ;
	self:debug(string.format("minX,maxX,width=%s,%s,%s / minZ,maxZ,height=%s,%s,%s", tostring(self.mapData.minX),tostring(self.mapData.maxX),tostring(self.mapData.width),tostring(self.mapData.minZ),tostring(self.mapData.maxZ),tostring(self.mapData.height)));
	self.mapData.numXtilesNeeded = math.ceil(self.mapData.width/self.tileSize);
	self.mapData.numZtilesNeeded = math.ceil(self.mapData.height/self.tileSize);
	self:debug(string.format("numXtilesNeeded, numZtilesNeeded = %s, %s", tostring(self.mapData.numXtilesNeeded),tostring(self.mapData.numZtilesNeeded)));

	local map = {};
	local mapCoords = {};
	for line=1,self.mapData.numZtilesNeeded do
		local z = self.mapData.minZ - self.tileSize/2 + (line*self.tileSize);
		if line == self.mapData.numZtilesNeeded then
			local prevZ = (self.mapData.minZ - self.tileSize/2 + ((line-1)*self.tileSize));
			z = prevZ + (self.mapData.maxZ - prevZ)/2;
		end;
		map[line] = {};
		mapCoords[line] = {};

		for col=1,self.mapData.numXtilesNeeded do
			local x = self.mapData.minX - self.tileSize/2 + (col*self.tileSize);
			if col == self.mapData.numXtilesNeeded then
				local prevX = (self.mapData.minX - self.tileSize/2 + ((col-1)*self.tileSize));
				x = prevX + (self.mapData.maxX - prevX)/2;
			end;
			local point = { x = x, z = z };
			mapCoords[line][col] = point;

			--WALKABLE vs. UNWALKABLE
			map[line][col] = self.walkable;
			local isInPoly = cppf:pointInPolygon_v2(course.waypoints, self.mapData.xValues, self.mapData.zValues, x, z);
			local hasFruit = courseplay:area_has_fruit(x, z, FruitUtil.fruitTypes["wheat"].index, self.tileSize/2, self.tileSize/2); --TODO: current fruit --> e.g. combine.grainTankFillType --> FruitUtil.fillTypeToFruitType[fillType]
			if not isInPoly or hasFruit then
				map[line][col] = self.unwalkable;
			end;
		end;
	end;
	--self:debug(self:tableShow(map, self.testCourse .. ": map"));
	--self:debug(self:tableShow(mapCoords, self.testCourse .. ": mapCoords"));
	--self:debug(self:printMap(map));

	return map, mapCoords;
end;

function cppf:printMap(map)
	local str = "RESULTMAP = {\r";
	for z=1,#map do
		str = str .. "\t{";
		for x=1,#map[z] do
			if map[z][x] == self.walkable then
				str = str .. " ";
			elseif map[z][x] == self.unwalkable then
				str = str .. "x";
			else
				str = str .. map[z][x];
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

function cppf:pointInPolygon_v2(polygon, xValues, zValues, x, z) --@src: http://www.ecse.rpi.edu/Homepages/wrf/Research/Short_Notes/pnpoly.html
	--nvert: Number of vertices in the polygon. Whether to repeat the first vertex at the end.
	--vertx, verty: Arrays containing the x- and y-coordinates of the polygon's vertices.
	--testx, testy: X- and y-coordinate of the test point.

	local nvert = #polygon;
	local vertx, verty = xValues, zValues;
	local testx, testy = x, z;

	local i, j;
	local c = false;

	for i=1, nvert do
		if i == 1 then
			j = nvert;
		else
			j = i - 1;
		end;

		if ((verty[i]>testy) ~= (verty[j]>testy)) and (testx < (vertx[j]-vertx[i]) * (testy-verty[i]) / (verty[j]-verty[i]) + vertx[i]) then
			c = not c;
		end;
	end;
	return c;
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
