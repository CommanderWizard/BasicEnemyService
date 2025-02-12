local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Component = require(ReplicatedStorage.Packages.Component)
local EnemyAI = require(script.EnemyAI)

local EnemyService = Knit.CreateService {
    Name = "EnemyService";
    Client = {
        EnemyKilled = Knit.CreateSignal(),
    };
    EnemyTable = {};
    EnemyTypes = {};
}

EnemyService.EnemyKilled = Signal.new()

function EnemyService:ReturnEnemyfromModel(model: Model)
    return self.EnemyTable[model]
end

function EnemyService:KnitStart()
    EnemyService.HitboxService = Knit.GetService("HitboxService")
    task.spawn(function()
        -- Load all enemy types
        for i,v in script.EnemyAI:GetChildren() do -- Preload all the custom enemy type modules
            if v:IsA("ModuleScript") then
                local enemy = require(v)
                self.EnemyTypes[v.Name] = enemy
            end
        end

        local function setupSpawn(mobSpawn) -- Setup a mob based on the mob spawn attributes
            if mobSpawn:IsDescendantOf(workspace) then
                local mobType = mobSpawn:GetAttribute("EnemyType")

                if self.EnemyTypes[mobType] then
                    local enemy, model = self.EnemyTypes[mobType].new(mobSpawn, EnemyService)
                    self.EnemyTable[model] = enemy
                else
                    warn("Invalid enemy type: " .. mobType)
                end
            end
        end

        CollectionService:GetInstanceAddedSignal("mobSpawn"):Connect(function(mobSpawn)
            setupSpawn(mobSpawn)
        end)
        
        for _,mobSpawn in CollectionService:GetTagged("mobSpawn") do
            setupSpawn(mobSpawn)
        end
    end)
end

function EnemyService:KnitInit()
end

return EnemyService