local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyAI = require(script.Parent)
local Knit = require(ReplicatedStorage.Packages.Knit)
local mobType = "BasicEnemy"

local BasicEnemy = {}
BasicEnemy.__index = BasicEnemy
setmetatable(BasicEnemy, EnemyAI)

function BasicEnemy:Attack(target: Model)
    self:StopMovement(true)
    task.wait(self.Config.AttackPause)
    self:FaceTarget(target, 0.25) -- Face the target
    
    local enemyCFrame = self.Model:GetPivot() + Vector3.new(0,2,0)
	local attackSize = Vector2.new(self.Config.AttackSize.X,self.Config.AttackSize.Y)
	local attackCFrame = enemyCFrame + enemyCFrame.LookVector * (attackSize.Y/2)
    local timeUntilAttack = self.Config.AttackDelay

    -- Cast a visible hitbox so that players can see the attack
    self.EnemyService.HitboxService:VisualCubeCast(attackCFrame, Vector3.new(attackSize.X,0.5,attackSize.Y), timeUntilAttack, {
		HitboxProperties = {
			Color = Color3.fromRGB(255,50,50),
		}
	})

    task.wait(timeUntilAttack) -- Wait the attack delay time

    self.LastAttack = tick()

    -- Cast the spatial hitbox to deal damage
    local hitCharacters = self.EnemyService.HitboxService:CastCubeHitbox({
        CFrame = attackCFrame,
        Size = Vector3.new(
            attackSize.X,
            10,
            attackSize.Y
        ),
    })
    self:DealDamage(hitCharacters, self.Config.Damage)

    task.wait(self.Config.AttackRest)
    self:AllowMoving()
end

function BasicEnemy.new(spawnPoint, enemyService, customConfig) -- Class override function for creating new enemy object
    local enemy, model = EnemyAI.new(spawnPoint, mobType, enemyService, customConfig)
    setmetatable(enemy, BasicEnemy)

    return enemy, model
end

return BasicEnemy