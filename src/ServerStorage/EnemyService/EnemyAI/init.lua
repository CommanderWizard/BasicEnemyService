local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)
local TweenService = require(ReplicatedStorage.Libraries.TweenService)

local EnemyConfig = require(script.Parent.EnemyConfig)
local mobFolder = ServerStorage:WaitForChild("Assets"):WaitForChild("MobFolder")

local function UpdateHealthUI(model, health, maxHealth)
    local HealthUI = model.HPPart.BillboardGui.Frame
    HealthUI.Health.Text = health .. "/" .. maxHealth
    HealthUI.Frame.Size = UDim2.new(health / maxHealth, 0, 1, 0)
end

local EnemyAI = {}
EnemyAI.__index = EnemyAI

function EnemyAI:ToggleSleep(setSleepState: boolean) -- Disable AI Loop while no players are nearby
    self.Sleep = setSleepState

    if setSleepState then
        self:StopMovement()
    end
end

function EnemyAI:Patrol(setPatrolState: boolean) -- Move to a random point within a radius of the spawn point
    if self.Patrolling == setPatrolState then return end
    if self.PatrolTask then
        task.cancel(self.PatrolTask)
    end
    self.Patrolling = setPatrolState
    if not setPatrolState then 
        self:StopMovement()
        return
    end

    local hub = self.SpawnCFrame

    self.PatrolTask = task.spawn(function()
        self:Move(hub.Position)
        self.Humanoid.MoveToFinished:Wait()
    
        while self.Patrolling do
            local PatrolDistance = self.Config.PatrolDistance
            local x = math.random(-PatrolDistance, PatrolDistance)
            local z = math.sqrt(PatrolDistance*PatrolDistance - x*x)

            local targetCFrame = hub * CFrame.new(x, 0, z)
            self:Move(targetCFrame.Position)

            self.Humanoid.MoveToFinished:Wait()
            task.wait(3)
        end
    end)
end

function EnemyAI:Move(position: Vector3, speed: number?) -- Move mob object to specific location
    if self.CanMove and self.Alive then
        self.Humanoid.WalkSpeed = speed or self.Config.MovementSpeed
        self.Humanoid:MoveTo(position)

        return true
    end

    return false, "CantMove"
end

function EnemyAI:StopMovement(preventMoving: boolean)
    self.Humanoid:MoveTo(self.Model.PrimaryPart.Position)
    self.Humanoid.WalkSpeed = 0

    if preventMoving then
        self.CanMove = false
    end
end

function EnemyAI:AllowMoving()
    self.CanMove = true
end

function EnemyAI.ReturnNearestPlayer(self) -- Returns the nearest player to the target
    local range = self.Config.Range
    local HRP = self.Model.HumanoidRootPart

    local List = {}
	local Target = nil
	local Distance = nil
	for _,v in game.Players:GetPlayers() do
		local dist = v:DistanceFromCharacter(HRP.position)
		if dist <= range then
			table.insert(List, {dist, v})
		end
	end
		
	table.sort(List, function(A, B)
		return A[1] < B[1]
	end)
	
	pcall(function()
		Target = List[1][2]
		Distance = List[1][1]
	end)
	
	return Target, Distance
end

function EnemyAI:FaceTarget(target: Model | {Position: Vector3}, tweenTime: number?) -- Rotates mob towards target
    if not target then return end
    if typeof(target) == "Instance" and not self.Alive then return end

    local targetPosition = if typeof(target) == "table" then target.Position else target.HumanoidRootPart.Position
    targetPosition = targetPosition * Vector3.new(1,0,1) + Vector3.new(0, self.Model:GetPivot().Position.Y, 0)

    -- Avoid NaN
    if (self.Model.PrimaryPart.Position - targetPosition).Magnitude < 0.1 then return false end

    local goalCFrame = CFrame.new(
        self.Model.PrimaryPart.Position,
        targetPosition
    )

    if tweenTime then
        local tween = TweenService.tween(self.Model.PrimaryPart, {
            CFrame = goalCFrame
        }, {Time = tweenTime, Style = "Sine", Dir = "Out"})

        self.trove:Add(tween)
        tween.Completed:Wait()
    else
        self.Model.PrimaryPart.CFrame = goalCFrame
    end

    return true
end

function EnemyAI:OnDeath()
    if not self.Alive then return end
    self.Alive = false
    self.trove:Clean()
end

function EnemyAI:IsAlive()
    return self.Alive    
end

function EnemyAI:DealDamage(targets: {Model}, damage: number)
    for _,target in targets do
        if not target or not target:FindFirstChild("Humanoid") then continue end
        local humanoid = target:FindFirstChild("Humanoid")
        humanoid:TakeDamage(damage)
    end
end

function EnemyAI:UpdateHealth(amount) -- Simple function to handle mob health and updating the UI
    if not self.Alive then return end
    self.Health = math.clamp(self.Health + amount, 0, self.MaxHealth)
    UpdateHealthUI(self.Model, self.Health, self.MaxHealth)
end

function EnemyAI:TakeDamage(amount)
    self:UpdateHealth(-amount)

    if self.Health <= 0 then
        self:OnDeath()
    end
end

function EnemyAI:Heal(amount)
    self:UpdateHealth(amount)
end

function EnemyAI:StartBehavior() -- Start the basic enemy behavior
    self:BaseMovement()

    self.LastAttack = 0
    while self.Alive do
        if self.Target then -- Loop to see if the enemy can attack a player / target
            if (tick() - self.LastAttack) >= self.Config.AttackCooldown and (self.Target.Character.PrimaryPart.Position - self.Model.PrimaryPart.Position).Magnitude <= self.Config.AttackRange then
                self:Attack(self.Target.Character)
            end

            task.wait(0.2)
        end
        task.wait(0.3)
    end
end

function EnemyAI:BaseMovement() -- Handle mob movement logic
    task.spawn(function()
        while self.Alive do
            task.wait()
            if self.Sleep then continue end -- Prevent movement while in sleep state

            local success, err = pcall(function()
                local target, distance = self.ReturnNearestPlayer(self) -- Find the nearest target
                if target then
                    self.Model.HumanoidRootPart:SetNetworkOwner(target)
                end
                if target == nil or distance == nil or not target.Character or (target.Character.HumanoidRootPart.Position - self.SpawnCFrame.Position).Magnitude > self.Config.MaxDistanceFromSpawn then  -- No target found
                    self.Target = nil
                    self:Patrol(true) -- Patrol the area if there is no target
                    return 
                end
                
                self:Patrol(false)

                if self.Target and self.Target.Character and (self.Target.Character.PrimaryPart.Position - self.Model.PrimaryPart.Position).Magnitude < self.Config.Range then
                    self.Target = self.Target
                else
                    self.Target = target
                end
                
                if distance <= self.Config.AttackRange/2 then
                    self:StopMovement() -- Target in range for an attack so stop the movement
                else
                    self:Move(target.Character:GetPivot().Position) -- Move towards the target
                end
            end)

            if not success then
                warn(err)
            end
        end
    end)
end

function EnemyAI.new(spawnPoint, mobType, enemyService, customConfig)
    local newAI = setmetatable({}, EnemyAI)

    local enemyModel = mobFolder[mobType]:Clone()
    if not enemyModel then
        warn("Invalid enemy type: " .. mobType)
        return
    end

    CollectionService:AddTag(enemyModel, "Enemy") -- Add an enemy tag to make handling multiple enemies easier
    enemyModel:SetPrimaryPartCFrame(spawnPoint.CFrame + Vector3.new(0, 3, 0))
    enemyModel.Parent = workspace

    -- Load the config
    if customConfig then
        newAI.Config = customConfig
    elseif EnemyConfig[mobType] then
        newAI.Config = EnemyConfig[mobType]
    else
        warn("Invalid enemy type: " .. mobType)
        return
    end

    -- Setup enemy values based on Config as well as other preset values
    newAI.SpawnPoint = spawnPoint
    newAI.SpawnCFrame = spawnPoint.CFrame
    newAI.Model = enemyModel
    newAI.Humanoid = enemyModel.Humanoid
    newAI.MaxHealth = newAI.Config.MaxHealth
    newAI.Health = newAI.MaxHealth
    newAI.Damage = newAI.Config.Damage
    newAI.Alive = true
    newAI.EnemyService = enemyService
    newAI.CanMove = true
    newAI.trove = Trove.new()

    UpdateHealthUI(enemyModel, newAI.Health, newAI.MaxHealth)
    task.spawn(function()
        newAI:StartBehavior()
    end)

    return newAI, enemyModel
end

return EnemyAI