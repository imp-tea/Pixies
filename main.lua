function love.load()
	pixelSize = 2

	mutationRate = 0.01

	geneSize = 10
	bpMaxSize = 10
	geneCount = 13

	baseRadius = 4
	currentCell = nil
	cellID = 1
	speciesID = 1
	numCells = 0
	startingEnergy = 1000
	collisionAge = 100
	cellList = {}

	speciesList = {}
	speciesColors = {}

	WIDTH = 1200
	HEIGHT = 800

	gridSize = 10
	cellGrids = {}
	for i=1,gridSize,1 do
		cellGrids[i] = {}
		for j=1,gridSize,1 do
			cellGrids[i][j] = {}
		end
	end
	foodGrids = {}
	for i=1,gridSize,1 do
		foodGrids[i] = {}
		for j=1,gridSize,1 do
			foodGrids[i][j] = {}
		end
	end

	foodSize = 5
	foodEnergy = 150
	maxFood = 150
	numFood = 0
	foodID = 0
	foodList = {}
	for i=1,maxFood,1 do
		newFood()
	end

	love.window.setMode(WIDTH, HEIGHT, {centered=true, msaa=0,resizable=false, vsync=false, minwidth=800, minheight=600})
	math.randomseed(os.time())
	--math.randomseed(1)

	startTime = love.timer.getTime()
	ticksPerSecond = 120
	tickCounter = 0

	love.graphics.setPointSize(pixelSize)
	showStats = false

	for i=1,50,1 do
		newCell(math.random(10,WIDTH-10),math.random(10,HEIGHT-10),math.random(1,4),startingEnergy)
	end
	--newCell(100,100,1)
	--newCell(200,300,2)

	collided = false
	fps = 0
	tmpTime = 0
	tmpFrame = 0
end

function love.update(dt)
	tmpTime = tmpTime + dt
	tmpFrame = tmpFrame + 1
	if tmpFrame > 30 then
		fps = tmpFrame/tmpTime
		tmpFrame = 0
		tmpTime = 0
	end
	local currentTime = love.timer.getTime()
	local tick = false
	if currentTime - startTime >= 1/ticksPerSecond then
		startTime = currentTime
		tick = true
		tickCounter = tickCounter + 1
	end
	if tick then
		if tickCounter%2 == 1 then
			if numFood < maxFood then
				newFood()
			end
			for i=1,table.getn(cellList),1 do
				local c = cellList[i]
				c.age = c.age+1
				if math.random()<0.03 then
					rotateCell(c,math.random(-1,1))
				end
				moveCell(c,1)
				if c.energy >= c.breedingEnergy then
					if c.damage>0 then
						repairSelf(c)
					end
					if c.energy >= c.breedingEnergy then
						newCell(c.x,c.y,1,c.energy/2,c,cross(c,c,c.x,c.y))
						c.energy = c.energy/2
					end
				end
			end
			checkFoodCollisions()
		else
			checkCollisions()
			for i=1,table.getn(cellList),1 do
				local c = cellList[i]
				if cellList[i] ~= nil then
					checkHeartDamage(c)
				end
			end
		end
		if tickCounter%10 == 0 then
			if numCells < 50 then
				newCell(math.random(10,WIDTH-10),math.random(10,HEIGHT-10),math.random(1,4),startingEnergy)
			end
		end
	end
end

function love.keypressed(key)
	if key == "space" then
		for i,c in pairs(cellList) do
			moveCell(c,2)
			--break
			--checkCollisions(c)
		end
	end
	if key=="up" then
		ticksPerSecond = math.floor(ticksPerSecond*2)+1
	end
	if key == "down" then
		ticksPerSecond = math.floor(ticksPerSecond/2)
	end
end

function love.draw()
	love.graphics.setColor(1,1,1,1)
	love.graphics.print(math.floor(fps+0.5),50,50)
	for i,c in pairs(cellList) do
		drawCell(c)
	end
	for i,f in pairs(foodList) do
		drawFood(f)
	end
	if showStats then
		printCellStatBox(currentCell)
	end
	drawStats(10, HEIGHT-190)
end

function newCell(_x,_y,direction,energy,parent,genome)
	local cell = {}
	numCells = numCells + 1
	cell.id = "cell"..tostring(cellID)
	cellID = cellID + 1


	cell.x = math.floor(_x/pixelSize)*pixelSize
	cell.y = math.floor(_y/pixelSize)*pixelSize
	cell.age = 0
	cell.facing = direction -- 1:right, 2:down, 3:left 4:up
	cell.radius = baseRadius
	cell.resolution = 1500
	cell.energy = energy
	cell.generation = 0
	if parent == nil then
		cell.genes = {}
		for i=1,geneCount,1 do
			cell.genes[i] = {}
			for j=1,geneSize,1 do
				cell.genes[i][j] = math.random(1,bpMaxSize)
			end
		end
		cell.r,cell.g,cell.b = setCellColor(cell)
		cell.species = "S"..tostring(speciesID)
		speciesList[cell.species] = 1
		speciesColors[cell.species] = {cell.r,cell.g,cell.b}
		speciesID = speciesID + 1
	else
		cell.genes = genome
		cell.species = parent.species
		cell.generation = parent.generation + 1
		speciesList[cell.species] = speciesList[cell.species] + 1
		cell.r,cell.g,cell.b = setCellColor(cell)
	end
	cell.wallRadius = cellWallFunction(cell)
	cell.peaks,cell.lowestTrough,cell.highestPeak = generatePeaks(cell)
	cell.body = generateCellBody(cell)
	cell.w = table.getn(cell.body[1])
	cell.h = table.getn(cell.body)
	cell.mass = getMass(cell.body)
	cell.breedingEnergy = cell.mass*6 + 200
	cell.markedForDeath = false
	table.insert(cellList,cell)
	cell.gridX,cell.gridY = getGrid(cell.x,cell.y)
	cell.damage = 0
	cell.moveCost =  ((cell.mass + cell.w*cell.h)/2)*0.004
	setGrids(cell)
	return cell
end

function cross(c1,c2,_x,_y)
	local genes = {}
	for i=1,geneCount,1 do
		genes[i]={}
		if math.random() > 0.5 then
			for j=1,geneSize,1 do
				genes[i][j] = c1.genes[i][j]
				if math.random() < mutationRate then
					genes[i][j] = mutate(genes[i][j],3)
				end
			end
		else
			for j=1,geneSize,1 do
				genes[i][j] = c2.genes[i][j]
				if math.random() < mutationRate then
					genes[i][j] = mutate(genes[i][j],3)
				end
			end
		end
	end
	return genes
end

function cellWallFunction(cell)
	local start = 6
	local g=cell.genes
	local radii = {}
	local angleRange = (g[5][1]+math.sqrt(g[5][2]))
	local angleIncrement = angleRange / cell.resolution
	local scale = math.sqrt(cell.radius*g[5][3]) / (2+g[5][4]/5)

	--local scale = d[1]*(cell.age+1)/26
	for angle=0,angleRange,angleIncrement do
		local r = 0
		r = r + (0.5*math.asin(math.cos(angle*g[start][1]/g[start][2]))*g[start][3]/g[start][4])*(g[start][5]%3)
		r = r + (0.5*math.acos(math.sin(angle*g[start+1][1]/g[start+1][2]))*g[start+1][3]/g[start+1][4])*(g[start+1][5]%3)
		r = r + (math.cos(angle*g[start+2][1]/g[start+2][2])*(g[start+2][3]/g[start+2][4]))*(g[start+2][5]%3)
		r = r + (math.abs(math.sin(angle*g[start+3][1]/g[start+3][2])*g[start+3][3]/g[start+3][4]) - math.cos(angle*g[start+3][5]/g[start+3][6])*g[start+3][7]/g[start+3][8])*(g[start+3][9]%3)
		r = r + ((1-math.abs(math.cos(angle*g[start+4][1]/g[start+4][2])))*(g[start+4][3]/g[start+4][4]))*(g[start+4][5]%3)
		r = r + (math.cos((g[start+5][1]*0.5)*angle)^(g[start+5][2]+1))*(g[start+5][3]-g[start+5][4])*(g[start+5][5]%3)
		r = r - (math.sin(angle*g[start+6][1]/g[start+6][2])*(g[start+6][3]/2/g[start+6][4]))*(g[start+6][5]%3)
		r = math.abs(r*scale + cell.radius) + g[5][5]/2
		table.insert(radii,r)
	end
	for i=1,cell.resolution-1,1 do
		radii[i+cell.resolution] = radii[cell.resolution-i]
	end
	return radii
end

function generateCellBody(cell)
	local wr = cell.wallRadius
	local body = {}
	local xCoords = {}
	local yCoords = {}
	local step = math.pi/cell.resolution
	local highestX,lowestX,highestY,lowestY = 0,0,0,0
	local cellAngle = (cell.facing-1)*math.pi/2
	for i = 0,table.getn(wr)-1,1 do
		local x = math.floor((math.cos(i*step+cellAngle)*wr[i+1])/pixelSize)
		local y = math.floor((math.sin(i*step+cellAngle)*wr[i+1])/pixelSize)
		if x > highestX then
			highestX = x
		elseif x < lowestX then
			lowestX = x
		end
		if y > highestY then
			highestY = y
		elseif y < lowestY then
			lowestY = y
		end
		table.insert(xCoords,x)
		table.insert(yCoords,y)
	end
	local h = (highestY-lowestY)+4
	local w = (highestX-lowestX)+4
	for i =1,h,1 do
		body[i] = {}
		for j = 1,w,1 do
			body[i][j] = 0
		end
	end
	for i=1,table.getn(xCoords),1 do
		if body[yCoords[i]-lowestY+2] ~= nil and body[yCoords[i]-lowestY+2][xCoords[i]-lowestX+2] ~= nil then
			body[yCoords[i]-lowestY+2][xCoords[i]-lowestX+2] = 1
		end
	end
	body = trimArray(body)
	local cy = math.ceil(table.getn(body)/2)
	local cx = math.ceil(table.getn(body[1])/2)
	local toCheck = {{cx,cy}}
	local maxY = table.getn(body)-1
	local maxX = table.getn(body[1])-1
	while table.getn(toCheck) > 0 do
		local x,y=toCheck[1][1],toCheck[1][2]
		body[y][x]=1
		if y>=maxY or y<=1 or x>=maxX or x<=1 then goto continue end
		if body[y][x+1] == 0 then
			body[y][x+1] = 1
			table.insert(toCheck,{x+1,y})
		end
		if body[y][x-1] == 0 then
			body[y][x-1] = 1
			table.insert(toCheck,{x-1,y}) end
		if body[y+1][x] == 0 then
			body[y+1][x] = 1
			table.insert(toCheck,{x,y+1})
		end
		if body[y-1][x] == 0 then
			body[y-1][x] = 1
			table.insert(toCheck,{x,y-1})
		end
		::continue::
		table.remove(toCheck,1)
	end
	for i=2,table.getn(body)-1,1 do
		for j=2,table.getn(body[1])-1,1 do
			if body[i][j]==0 then
				if body[i][j+1]==1 and body[i][j-1]==1 and body[i+1][j]==1 and body[i-1][j]==1 then
					body[i][j]=1
				end
			end
		end
	end
	body[cy][cx]=2
	if body[cy][cx+1] ~= nil then body[cy][cx+1]=2 end
	if body[cy][cx-1] ~= nil then body[cy][cx-1]=2 end
	if body[cy+1] ~= nil then body[cy+1][cx]=2 end
	if body[cy-1] ~= nil then body[cy-1][cx]=2 end
	return body
end

function drawCell(cell)
	for y = 1,cell.h,1 do
		for x = 1,cell.w,1 do
			local _x = cell.x+math.floor(x-cell.w/2)*pixelSize
			local _y = cell.y+math.floor(y-cell.h/2)*pixelSize
			if cell.body[y][x] == 1 then
				love.graphics.setColor(cell.r,cell.g,cell.b,1)
				if math.random()>cell.age/collisionAge then
					love.graphics.setColor(cell.r,cell.g,cell.b,0.25)
				end
				--if cell.age<collisionAge then
				--	love.graphics.setColor(cell.r,cell.g,cell.b,cell.age/collisionAge)
				--end
				love.graphics.points(_x,_y)
			end
			if cell.body[y][x] == 2 then
				love.graphics.setColor(cell.r*1.5,cell.g*1.5,cell.b*1.5,1)
				love.graphics.points(_x,_y)
			end
			if cell.body[y][x] == -1 then
				love.graphics.setColor(1,1,1,0.1)
				love.graphics.points(_x,_y)
			end
		end
	end
	--love.graphics.setColor(1,1,1,1)
	--love.graphics.points(cell.x,cell.y)
end

function generatePeaks(cell)
	local peaks = {}
	local highestPeak = 0
	local lowestTrough = cell.radius*0.75
	peaks[1]=1
	for i=2,table.getn(cell.wallRadius)-1,1 do
		peaks[i] = 0
		if cell.wallRadius[i-1] < cell.wallRadius[i] and cell.wallRadius[i+1] < cell.wallRadius[i] then
			peaks[i] = 1
			if cell.wallRadius[i] > highestPeak then
				highestPeak = cell.wallRadius[i]
			end
		elseif cell.wallRadius[i-1] > cell.wallRadius[i] and cell.wallRadius[i+1] > cell.wallRadius[i] then
			peaks[i] = -1
			if cell.wallRadius[i] < lowestTrough then
				lowestTrough = cell.wallRadius[i]
			end
		end
	end
	peaks[table.getn(cell.wallRadius)] = 1
	peaks[math.floor(table.getn(cell.wallRadius)/2)] = 1
	return peaks,lowestTrough,highestPeak
end

function setCellColor(cell)
	local r = (cell.genes[1][1]+cell.genes[1][2]+cell.genes[1][3])/(3*bpMaxSize)
	local g = (cell.genes[2][1]+cell.genes[2][2]+cell.genes[2][3])/(3*bpMaxSize)
	local b = (cell.genes[3][1]+cell.genes[3][2]+cell.genes[3][3])/(3*bpMaxSize)
	return r,g,b
end

function printGenotype(x,y,cell,name)
	love.graphics.print(name.." Genome:",x,y)
	for i=1,table.getn(cell.genes),1 do
		local _y = y+i*15
		love.graphics.print(tostring(i)..":",x+20,_y)
		for j=1,table.getn(cell.genes[i]),1 do
			local _x = x+j*20
			love.graphics.print(tostring(cell.genes[i][j]),_x+30,_y)
		end
	end
end

function printGridCells(x,y,cell)
	local _y=y
	for i,c in pairs(cellGrids[cell.gridY][cell.gridX]) do
		_y = _y + 20
		love.graphics.print(tostring(c.id),x+20,_y)
	end
end

function getClosestCell(x,y)
	local cell = nil
	local closestDistance = 10000000
	for i,c in pairs(cellList) do
		local d = (c.x-x)^2 + (c.y-y)^2
		if d<closestDistance then
			closestDistance = d
			cell = c
		end
	end
	return cell
end

function love.mousepressed(x, y, button, istouch)
	currentCell = getClosestCell(x,y)
   	if button == 1 then
	   	if showStats==true then
		   showStats = false
	   	else
		   showStats = true
	   	end
   	end
   	if button == 3 then
	   newCell(x,y,math.random(1,4),startingEnergy*1.5)
   	end
end

function love.mousereleased(x, y, button, isTouch)
end

function love.mousemoved(x, y, dx, dy, istouch)
end

function love.wheelmoved(x, y)

end

function love.resize(w, h)
  WIDTH = w
  HEIGHT = h
end

function sum(t)
    local sum = 0
    for k,v in pairs(t) do
        sum = sum + v
    end
    return sum
end

function trimEmptyRows(array)
	for i = table.getn(array),1,-1 do
		if sum(array[i]) == 0 then
			table.remove(array,i)
		end
	end
	return array
end

function trimArray(array)
	array = trimEmptyRows(array)
	array = rotateLeft(array)
	array = trimEmptyRows(array)
	array = rotateRight(array)
	return array
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function printControls(x,y)
	love.graphics.setColor(1, 1, 1, 1)
	local controls = {}
	for i=1,table.getn(controls),1 do
		love.graphics.print(controls[i],x,y+i*40)
	end
end

function rotateRight(oldArray)
	local w = table.getn(oldArray[1])
	local h = table.getn(oldArray)
	local newArray = {}
	for i = 1,w,1 do
		newArray[i] = {}
		for j=1,h,1 do
			newArray[i][j] = oldArray[h-(j-1)][i]
		end
	end
	return newArray
end

function rotateLeft(oldArray)
	local w = table.getn(oldArray[1])
	local h = table.getn(oldArray)
	local newArray = {}
	for i = 1,w,1 do
		newArray[i] = {}
		for j=1,h,1 do
			newArray[i][j] = oldArray[j][w-(i-1)]
		end
	end
	return newArray
end

function rotateCell(cell,direction)
	if direction == 1 then
		cell.body=rotateRight(cell.body)
	elseif direction == -1 then
		cell.body=rotateLeft(cell.body)
	end
	cell.w = table.getn(cell.body[1])
	cell.h = table.getn(cell.body)
	cell.facing = cell.facing+direction
	if cell.facing < 1 then cell.facing=4 end
	if cell.facing > 4 then cell.facing=1 end
end

function moveCell(cell,v)
	local moveTable = {{1,0},{0,1},{-1,0},{0,-1}}
	local vx,vy = moveTable[cell.facing][1]*v,moveTable[cell.facing][2]*v
	cell.x = cell.x+vx*pixelSize
	cell.y = cell.y+vy*pixelSize
	if cell.x>WIDTH-2 then cell.x=2 end
	if cell.x<2 then cell.x=WIDTH-2 end
	if cell.y>HEIGHT-2 then cell.y=2 end
	if cell.y<2 then cell.y=HEIGHT-2 end
	local oldGX,oldGY = cell.gridX,cell.gridY
	local newGX,newGY = getGrid(cell.x,cell.y)
	if oldGX ~= newGX or oldGY ~= newGY then
		cell.gridX,cell.gridY = newGX,newGY
		setGrids(cell)
	end
	cell.energy = cell.energy-(v*v*cell.moveCost)
end

function compareGenomes(g1,g2)
	local difference = 0
	local maxDifference = geneCount*geneSize*9
	for i=1,table.getn(g1),1 do
		for j=1,table.getn(g1[1]) do
			difference = difference + math.abs(g1[i][j]-g2[i][j])
		end
	end
	return difference/maxDifference
end

function mutateValue(value, percentage)
	local maxDrift = value*percentage
	local direction = 1
	if math.random() >= 0.5 then
		direction = -1
	end
	local drift = maxDrift*math.random()*direction
	return value+drift
end

function getMass(body)
	local mass = 0
	for i=1,table.getn(body),1 do
		for j=1,table.getn(body[i]),1 do
			if body[i][j] == 1 then
				mass = mass+1
			end
		end
	end
	return mass
end

function killCell(cell)
	speciesList[cell.species] = speciesList[cell.species] - 1
	if speciesList[cell.species] == 0 then
		table.removekey(speciesList,cell.species)
		table.removekey(speciesColors,cell.species)
	end
	for i=1,gridSize,1 do
		for j=1,gridSize,1 do
			if cellGrids[i][j][cell.id] ~= nil then
				table.removekey(cellGrids[i][j],cell.id)
			end
		end
	end
	for i=1,table.getn(cellList),1 do
		if cellList[i] == cell then table.remove(cellList,i) end
	end
	cell.id = nil
	cell = nil
	numCells = numCells - 1
end

function table.removekey(table, key)
    local element = table[key]
    table[key] = nil
    return element
end

function getGrid(x,y)
	local gridWidth = WIDTH/gridSize
	local gridHeight = HEIGHT/gridSize
	local gridX = math.ceil(x/gridWidth)
	local gridY = math.ceil(y/gridHeight)
	if gridX < 1 then gridX=1 end
	if gridX > gridSize then gridX = gridSize end
	if gridY < 1 then gridY=1 end
	if gridY > gridSize then gridY = gridSize end
	return gridX,gridY
end

function setGrids(cell)
	--Clear old grids
	for i=1,gridSize,1 do
		for j=1,gridSize,1 do
			if cellGrids[i][j][cell.id] ~= nil then
				table.removekey(cellGrids[i][j],cell.id)
			end
		end
	end
	--Add to new grids
	local gridX,gridY = cell.gridX,cell.gridY
	local minY,maxY,minX,maxX = gridY,gridY,gridX,gridX
	if gridY>1 then minY = gridY-1 end
	if gridY<gridSize then maxY = gridY+1 end
	if gridX>1 then minX = gridX-1 end
	if gridX<gridSize then maxX = gridX+1 end
	for Y = minY,maxY,1 do
		for X = minX,maxX,1 do
			if cellGrids[Y] ~= nil and cellGrids[Y][X] ~= nil and cell.id ~= nill then
				cellGrids[Y][X][cell.id] = cell
			end
		end
	end
end

function checkCollisions()
	for i=1,table.getn(cellList)-2,1 do
		local c1 = cellList[i]
		for j = i+1,table.getn(cellList),1 do
			local c2 = cellList[j]
			if c2.id ~= c1.id and c1.age > collisionAge and c2.age > collisionAge then
				local dx = (c2.x - c1.x)/pixelSize
				local dy = (c2.y - c1.y)/pixelSize
				local collisionWidth = math.ceil((c1.w + c2.w)/2)
				local collisionHeight = math.ceil((c1.h + c2.h)/2)
				if math.abs(dx) < collisionWidth and math.abs(dy) < collisionHeight then
					local overlapX = math.abs(collisionWidth-dx)
					local overlapY = math.abs(collisionHeight-dy)
					collide(c1,c2,overlapX,overlapY)
				end
			end
		end
	end
end

function collide(c1,c2,dx,dy)
	local minX_1 = 1
	local maxX_1 = c1.w
	local minY_1 = 1
	local maxY_1 = c1.h

	local minX_2 = 1
	local maxX_2 = c2.w
	local minY_2 = 1
	local maxY_2 = c2.h

	if c2.x>c1.x then
		minX_1 = c1.w-dx
		maxX_2 = dx
	else
		maxX_1 = dx
		minX_2 = c2.w-dx
	end

	if c2.y>c1.y then
		minY_1 = c1.h-dy
		maxY_2 = dy
	else
		maxY_1 = dy
		minY_2 = c2.h-dy
	end

	local coordinateTable = {}
	for y=minY_1,maxY_1,1 do
		for x=minX_1,maxX_1,1 do
			if c1.body[y]~=nil and c1.body[y][x]~=nil and c1.body[y][x] > 0 then
				local _x = math.floor((c1.x/pixelSize)+(x-math.ceil(c1.w/2))+0.5)
				local _y = math.floor((c1.y/pixelSize)+(y-math.ceil(c1.h/2))+0.5)
				local coordID = tostring(_y).."_"..tostring(_x)
				coordinateTable[coordID] = {y,x,c1.body[y][x]}
			end
		end
	end
	for y=minY_2,maxY_2,1 do
		for x=minX_2,maxX_2,1 do
			if c2.body[y]~=nil and c2.body[y][x]~=nil and c2.body[y][x] > 0 then
				local _x = math.floor((c2.x/pixelSize)+(x-math.ceil(c2.w/2))+0.5)
				local _y = math.floor((c2.y/pixelSize)+(y-math.ceil(c2.h/2))+0.5)
				local coordID = tostring(_y).."_"..tostring(_x)
				if coordinateTable[coordID] ~= nil then
					if c1.body[coordinateTable[coordID][1]][coordinateTable[coordID][2]] == 2 then
						c2.energy = c2.energy+c1.energy
						c1.energy = 0
						c1.markedForDeath = true
					end
					if c2.body[y][x] == 2 then
						c1.energy = c1.energy+c2.energy
						c2.energy = 0
						c2.markedForDeath = true
					end
					c1.body[coordinateTable[coordID][1]][coordinateTable[coordID][2]] = -1
					c2.body[y][x] = -1
					c1.damage = c1.damage + 1
					c2.damage = c2.damage + 1
				end
			end
		end
	end
end

function checkHeartDamage(cell)
	local x = math.ceil(cell.w/2)
	local y = math.ceil(cell.h/2)
	if cell.body[y][x] == 0 then
		killCell(cell)
		return
	end
	if cell.markedForDeath==true then
		killCell(cell)
		return
	end
	if cell.energy < 0 then
		killCell(cell)
		return
	end
end

function newFood()
	local food = {}
	food.x = math.floor(math.random(20,WIDTH-20)/pixelSize)*pixelSize
	food.y = math.floor(math.random(20,HEIGHT-20)/pixelSize)*pixelSize
	food.gridX,food.gridY = getGrid(food.x,food.y)
	numFood = numFood + 1
	foodID = foodID+1
	food.id = "food"..tostring(foodID)
	setFoodGrids(food)
	table.insert(foodList,food)
end

function drawFood(f)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setPointSize(foodSize)
	love.graphics.points(f.x,f.y)
	love.graphics.setPointSize(pixelSize)
end

function checkFoodCollisions()
	for i=table.getn(foodList),1,-1 do
		local f = foodList[i]
		for k,c in pairs(cellGrids[f.gridY][f.gridX]) do
			local dx = (c.w*pixelSize)/2
			local dy = (c.h*pixelSize)/2
			if math.abs(c.x-f.x) < dx and math.abs(c.y-f.y) < dy then
				c.energy = c.energy+foodEnergy
				table.remove(foodList,i)
				numFood = numFood-1
				for i=1,gridSize,1 do
					for j=1,gridSize,1 do
						if foodGrids[i][j][f.id] ~= nil then
							table.removekey(foodGrids[i][j],f.id)
						end
					end
				end
				if c.energy > c.breedingEnergy/2 and math.random()>0.1 then
					repairSelf(c)
				end
				break
			end
		end
	end
end

function setFoodGrids(f)
	--Add to new grids
	local gridX,gridY = f.gridX,f.gridY
	local minY,maxY,minX,maxX = gridY,gridY,gridX,gridX
	if gridY>1 then minY = gridY-1 end
	if gridY<gridSize then maxY = gridY+1 end
	if gridX>1 then minX = gridX-1 end
	if gridX<gridSize then maxX = gridX+1 end
	for Y = minY,maxY,1 do
		for X = minX,maxX,1 do
			if foodGrids[Y] ~= nil and foodGrids[Y][X] ~= nil and f.id ~= nill then
				foodGrids[Y][X][f.id] = f
			end
		end
	end
end

function getSenses(c)
	c.senses[1] = c.energy
	c.senses[2] = c.damage

	--1: right, 2:down, 3:left, 4:up
	for k,c2 in pairs(cellGrids[c.gridY][c.gridX]) do
		for i=1,4,1 do
			local signal = 0
			c.senses[table.getn(c.senses)+1]=signal
		end
	end
	for k,f in pairs(foodGrids[c.gridY][c.gridX]) do
		for i=1,4,1 do
			local signal = 0
			c.senses[table.getn(c.senses)+1]=signal
		end
	end
end

function compareGenetics(c1,c2)
	local diff = 0
	local avgDiff = 3.3*geneSize*5
	for i=1,geneCount,1 do
		for j=1,5,1 do
			diff = diff + math.abs(c1.genes[i][j] - c2.genes[i][j])
		end
	end
end

function drawStats(x,y)
	local tmpList = {}
	local barMaxHeight = 150
	local barWidth = 20
	for s,n in pairs(speciesList) do
		table.insert(tmpList,{n,s})
	end
	table.sort(tmpList, compare)

	for i=1,table.getn(tmpList),1 do
		if tmpList[i][1] > 1 then
			local _x = x + i*barWidth*2
			--local h = (tmpList[i][1]/numCells)*barMaxHeight
			local color=speciesColors[tmpList[i][2]]
			love.graphics.setColor(color[1], color[2], color[3], 0.5)
			love.graphics.rectangle("fill", _x, y+barMaxHeight, barWidth, (tmpList[i][1]/numCells)*barMaxHeight*-1)
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.print(tmpList[i][2],_x,y+barMaxHeight+10,0,1,1)
		end
	end
end

function compare(a,b)
  return a[1] > b[1]
end

function printCellStatBox(cell)
	local dy = (HEIGHT/2)-cell.y
	local dx = (WIDTH/2)-cell.x
	local angle = math.atan2(dy,dx)
	local distance = 100
	local xoffset = cell.x + math.cos(angle)*distance-60
	local yoffset = cell.y + math.sin(angle)*distance-40
	love.graphics.setColor(1,1,1,0.5)
	love.graphics.circle("line", cell.x, cell.y, cell.highestPeak+10, 20)
	love.graphics.setColor(0.2,0.2,0.2,0.75)
	love.graphics.rectangle("fill", xoffset, yoffset, 120, 105)
	love.graphics.setColor(1,1,1,1)
	love.graphics.rectangle("line", xoffset, yoffset, 120, 105)
	love.graphics.print(currentCell.species,xoffset+10,yoffset+10)
	love.graphics.print("Generation: "..tostring(currentCell.generation),xoffset+10,yoffset+25)
	love.graphics.print("Energy: "..tostring(math.floor(currentCell.energy)),xoffset+10,yoffset+40)
	love.graphics.print("Mass: "..tostring(currentCell.mass),xoffset+10,yoffset+55)
	love.graphics.print("Mitosis: "..tostring(currentCell.breedingEnergy),xoffset+10,yoffset+70)
	love.graphics.print("Damage: "..tostring(currentCell.damage),xoffset+10,yoffset+85)
end

function mutate(value,n)
	local drift = math.random(0,math.floor(math.abs(n)))
	local direction = 1
	if math.random()<0.5 then direction = -1 end
	if value+drift<1 then return 1 end
	if value+drift>10 then return 10 end
	return value+drift
end

function repairSelf(cell)
	for i=1,table.getn(cell.body),1 do
		for j=1,table.getn(cell.body[1]),1 do
			if cell.body[i][j] == -1 then
				cell.body[i][j] = 1
			end
		end
	end
	cell.energy = cell.energy - cell.damage*4
	cell.damage = 0
end
