AddCSLuaFile()

ENT.Base = "base_nextbot"
ENT.Spawnable = true

function ENT:Initialize()
    self:SetModel("models/abyssal.mdl")
    self:SetSpawnEffect(false)
    self:SetCollisionBounds(Vector(-1, -1, 0), Vector(1, 1, 1))
    self:SetSolid(0)
    self:SetCollisionGroup(10) --. wrong collision group? another might be better?
    if SERVER then
        self:SetMaxHealth(999999999)
    end
    self:SetHealth(999999999)
    self.LoseTargetDist = 9999999
    self.SearchRadius = 9999999
    self.waiting = false
    self.walking = false
    self.stalking = true
    self.chasing = false
    self.ambushing = false
    self.enraged = false
    self.chasefunctionactive = false
    
    self.escapedchases = 0
    
    self.loaded_amb_sounds = {}
    self.loaded_amb_sounds[1] = CreateSound(game.GetWorld(), "AbyssalChasingAmbience.wav")
    self.loaded_amb_sounds[2] = CreateSound(self, "AbyssalStalking.wav")
    
    self.loaded_sounds = {}
    self.loaded_sounds[1] = CreateSound(self, "AbyssalChasing.wav")
    self.loaded_sounds[2] = CreateSound(game.GetWorld(), "AbyssalDeathNoise.wav")
    self.loaded_sounds[3] = CreateSound(game.GetWorld(), "AbyssalChasingAmbienceEnd.wav")
    
    self.enrage_sounds = {}
    self.enrage_sounds[1] = CreateSound(game.GetWorld(), "AbyssalEnraged.wav")
    self.enrage_sounds[2] = CreateSound(game.GetWorld(), "AbyssalEnragedEnd.wav")
end

local trace = {
	mask = MASK_SOLID_BRUSHONLY
}

--will set enemy variable
function ENT:SetEnemy(ent)
	self.Enemy = ent
end

--gets the currently set enemy
function ENT:GetEnemy()
	return self.Enemy
end

--checks if we have an enemy, if we don't, it will try to find a new one and return true or false if it found one or not. else, it will return true.
function ENT:HaveEnemy()
	if ( self:GetEnemy() and IsValid(self:GetEnemy()) ) then
		if ( self:GetRangeTo(self:GetEnemy():GetPos()) > self.LoseTargetDist ) then
			return self:FindEnemy()
		elseif ( self:GetEnemy():IsPlayer() and !self:GetEnemy():Alive() ) then
			return self:FindEnemy()
		end
		return true
	else
		return self:FindEnemy()
	end
end

--will return true and set enemy if one is found. searches in a sphere(but the search is limited by time rather than range)
function ENT:FindEnemy()
	local _ents = ents.FindInSphere( self:GetPos(), self.SearchRadius )
	for k,v in ipairs( _ents ) do
		if ( v:IsPlayer() ) then
			self:SetEnemy(v)
			return true
        end
	end
    print("couldn't find enemy")
	self:SetEnemy(nil)
	return false
end

--adding the run behavior
function ENT:RunBehaviour()

    if (self:HaveEnemy()) then
        self:TeleportToRandom()
    end

    while (true) do
        if (self:HaveEnemy() and !self.waiting) then
            print("STARTED STALK"); --. uncommented this
            self:StalkEnemy()
        else
            print("WAITING OR NO ENEMY"); --. uncommented this
        end

        coroutine.wait(2)
    end
end

-- if this function is called when the player is touching the enemy, they die and the enemy wanders off
function ENT:InstaGib()
    if (self:VectorDistance(self:GetEnemy():GetPos(), self:GetPos()) < 50 and self:GetEnemy():Alive()) then --. decrease or increase the hitbox here
        self:GetEnemy():Kill()
        print("Killed player")
        self.loaded_sounds[2]:Stop()
        self.loaded_sounds[2]:SetSoundLevel(0)
        self.loaded_sounds[2]:Play()
        if self.chasing then
            self.loaded_amb_sounds[1]:Stop()
            self.loaded_sounds[3]:Stop()
            self.loaded_sounds[3]:SetSoundLevel(0)
            self.loaded_sounds[3]:Play()
            print("Played AbyssalChasingAmbienceEnd.wav")
            if self.enraged then
                self.enrage_sounds[1]:Stop()
                self.enrage_sounds[2]:Stop()
                self.enrage_sounds[2]:SetSoundLevel(0)
                self.enrage_sounds[2]:Play()
                print("Played AbyssalEnragedEnd.wav")
            end
        end
        if self.chasefunctionactive then
            print("Killed whilst Abyssal was chasing or whilst relocating after a kill, setting self.escapedchases to -1")
            self.escapedchases = -1 --. ChasePlayer() increments self.escapedchases by 1 as one of its last actions, correcting this variable to 0 in the process
        else
            print("Killed whilst Abyssal was not chasing and not relocating after a kill, setting self.escapedchases to 0")
            self.escapedchases = 0 --. if a player is killed whilst ChasePlayer() is not being executed self.escapedchases will never be incremented - setting to 0 is appropriate for these cases
        end
        self.stopchasing = true
        self:GoToRandomPoint()
    end
end

-- return the distance between two vectors
function ENT:VectorDistance(v1, v2)
    return math.sqrt((((v1.x)-(v2.x))*((v1.x)-(v2.x))) + (((v1.y)-(v2.y))*((v1.y)-(v2.y))) + (((v1.z)-(v2.z))*((v1.z)-(v2.z))))
end

function ENT:GetPlayerVisible()
    return self:GetEnemy():Visible(self)
end

function ENT:StalkEnemy( options )
    print("Stalking player")

    self.waiting = true
    self.stalking = true
    self.chasing = false
    self.walking = false

    --how long he waits before stalking
    self.pre_stalk_time = 15
    self.pre_stalk_timer = 0

    self.loco:SetAcceleration(200) --. original: 200
    self.loco:SetDesiredSpeed(300) --. original: 300

	local options = options or {}
	self.path = Path("Chase")
	self.path:SetMinLookAheadDistance( options.lookahead or 300 )
	self.path:SetGoalTolerance( options.tolerance or 20 )
	self.path:Compute(self, self:GetEnemy():GetPos())

    local stalking_timer = 0
    local stalking_time = 120 --. how long (in seconds) abyssal stalks for before teleporting to a random location.

    -- if his path is invalid, return false out of the function
	if !self.path:IsValid() then
        print('Stalk failed')
        return "failed"
    end

    self.LastPathRecompute = 0

	while self.path:IsValid() and self:HaveEnemy() and self.stalking do
        self:InstaGib()
        self.pre_stalk_timer = self.pre_stalk_timer + FrameTime()

        if !self:GetPlayerVisible() then
            if (self.pre_stalk_timer > self.pre_stalk_time) then
                if ( self.path:GetAge() > 0.1 ) then
                    self.path:Compute(self, self:GetEnemy():GetPos())
                end
                self.path:Update( self )

                if (CurTime() - self.LastPathRecompute > 0.1) then
                    self.LastPathRecompute = CurTime()
                    self:RecomputeTargetPath(self:GetEnemy():GetPos())
                end

                if options.draw then self.path:Draw() end

                local stuckTimer = 0
                local stuckTime = 1
                stuckTimer = stuckTimer + FrameTime()

                if (stuckTimer > stuckTime) then
                    self:UnstickFromCeiling()
                    stuckTimer = 0
                end
                
                stalking_timer = stalking_timer + FrameTime()
                if (stalking_timer > stalking_time) then
                    stalking_timer = 0
                    self:TeleportToRandom()
                end
            end
        else
            print("STALK ENDED: SEEN BY PLAYER")
            self:RandBehaviour() --. if the player is spotted, choose a behaviour. in Terminus, this is a coin flip between hiding (to later stalk) and chasing
        end
        self:Sounds()
        coroutine.yield()
	end
	return "ok"
end

function ENT:AmIEnraged() --. see documentation for the effect of this function (explanation yet to be added, will be available later). may edit the ragecalc conditions later based on gameplay
    print("AmIEnraged function called")
    local ragecalc = math.random(1,20)
    print("ragecalc is", ragecalc)
    if self.escapedchases == 0 and ragecalc == 1 then --. 0.05 chance of becoming enraged
        print("ragecalc == 1, returning true")
        return true
    elseif self.escapedchases == 1 and ragecalc <= 2 then --. 0.1 chance of becoming enraged
        print("ragecalc <= 2, returning true")
        return true
    elseif self.escapedchases == 2 and ragecalc <= 6 then --. 0.3 chance of becoming enraged
        print("ragecalc <= 6, returning true")
        return true
    elseif self.escapedchases == 3 and ragecalc <= 12 then --. 0.6 chance of becoming enraged
        print("ragecalc <= 12, returning true")
        return true
    elseif self.escapedchases == 4 and ragecalc <= 16 then --. 0.8 chance of becoming enraged
        print("ragecalc <= 16, returning true")
        return true
    elseif self.escapedchases == 5 and ragecalc <= 18 then --. 0.9 chance of becoming enraged
        print("ragecalc <= 18, returning true")
        return true
    elseif self.escapedchases == 6 then --. 100% chance of becoming enraged
        print("6 escaped chases, returning true")
        return true
    else
        print("ragecalc too high, returning false. Pairs escapedchases:condition are 0:1, 1:2, 2:6, 3:12, 4:16, 5:18, 6:20")
        return false
    end
end

function ENT:ChasePlayer()
    self.chasefunctionactive = true
    
    local slowchoice = math.random(0, 3)
    print("Chasing player, if 1 then Abyssal will slow down when close ", slowchoice) --. i.e. 25% chance of "playing" with player
    print("Current escaped chase count: ", self.escapedchases)

    self.waiting = true
    self.chasing = true
    self.stalking = false
    self.walking = false

    self.stopchasing = false

    if self:AmIEnraged() then
        self.enraged = true
        print("Enraged mode activated")
        print("Setting self.escapedchases to -1")
        self.escapedchases = -1 --. will be corrected to 0 at the end of this function
    end

    if !self.enraged then
        self.loco:SetAcceleration(1200) --. original: 375
        self.loco:SetDesiredSpeed(500) --. original: 1000
    else --. i.e. enraged
        self.loco:SetAcceleration(1400) --. original: 700
        self.loco:SetDesiredSpeed(3000) --. original: 2000
    end

    local options = options or {}
	self.path = Path("Chase")
	self.path:SetMinLookAheadDistance( options.lookahead or 300 )
	self.path:SetGoalTolerance( options.tolerance or 20 )
	self.path:Compute(self, self:GetEnemy():GetPos())

	if !self.path:IsValid() then
        return "failed"
    end

    local chasing_time = 25
    local chasing_timer = 0

    self.LastPathRecompute = 0

	while (self.path:IsValid() and !self.stopchasing) do

        self:InstaGib()

        chasing_timer = chasing_timer + FrameTime()
        if ( self.path:GetAge() > 0.1 ) then
            self.path:Compute(self, self:GetEnemy():GetPos())
        end
        self.path:Update( self )

        if (CurTime() - self.LastPathRecompute > 0.1) then
            self.LastPathRecompute = CurTime()
            self:RecomputeTargetPath(self:GetEnemy():GetPos())
        end

        if ( options.draw ) then self.path:Draw() end

        /* rolls a dice as to whether or not the enemy will slow down 
        when too close to give the player some room during a chase */
        
        if slowchoice == 1 then
            if self:VectorDistance(self:GetPos(), self:GetEnemy():GetPos()) < 450 and !self.enraged then
                self.loco:SetDesiredSpeed(350) --. original: 400
            else
                self.loco:SetDesiredSpeed(500) --. maintain normal chase speed, original: 1000
            end
        end
        
        if (!self:GetPlayerVisible() and chasing_timer > chasing_time) then
            self.stopchasing = true
        end

        local stuckTimer = 0
        local stuckTime = 1
        stuckTimer = stuckTimer + FrameTime()

        if (stuckTimer > stuckTime) then
            self:UnstickFromCeiling()
            stuckTimer = 0
        end

        self:Sounds()
        coroutine.yield()
	end
    
    print("Stopping chase")
    self.escapedchases = self.escapedchases + 1
    print("Increasing escaped chases count, new:", self.escapedchases)
    
    self.enraged = false
    self:TeleportToRandom()
    self.chasefunctionactive = false
	return "ok"
end

local stalk_close_sound_clock = 0
local stalk_close_sound_time = 0
local amb_chase_sound_clock = 0
local amb_chase_sound_time = 0
local chase_sound_clock = 0
local chase_sound_time = 0
local enraged_sound_clock = 0
local enraged_sound_time = 0

function ENT:Sounds()
    
    amb_chase_sound_clock = amb_chase_sound_clock + FrameTime()
    chase_sound_clock = chase_sound_clock + FrameTime()
    enraged_sound_clock = enraged_sound_clock + FrameTime()
    stalk_close_sound_clock = stalk_close_sound_clock + FrameTime()
    
    if (self.stalking or self.walking) then
        if (stalk_close_sound_clock > stalk_close_sound_time) then
            stalk_close_sound_clock = 0
            self.loaded_amb_sounds[2]:Stop()
            self.loaded_amb_sounds[2]:SetSoundLevel(70)
            self.loaded_amb_sounds[2]:Play()
            stalk_close_sound_time = SoundDuration("AbyssalStalking.wav")
            print("Played AbyssalStalking.wav")
        end
    end
    
    if (self.chasing) then
        if (amb_chase_sound_clock > amb_chase_sound_time) then
            self:StopAllAmbSounds()
            amb_chase_sound_clock = 0
            self.loaded_amb_sounds[1]:Stop()
            self.loaded_amb_sounds[1]:SetSoundLevel(0)
            self.loaded_amb_sounds[1]:Play()
            amb_chase_sound_time = SoundDuration("AbyssalChasingAmbience.wav")
            print("Played AbyssalChasingAmbience.wav")
        end
        if (chase_sound_clock > chase_sound_time) then
            chase_sound_clock = 0
            self.loaded_sounds[1]:Stop()
            self.loaded_sounds[1]:SetSoundLevel(70)
            self.loaded_sounds[1]:Play()
            chase_sound_time = SoundDuration("AbyssalChasing.wav")
            print("Played AbyssalChasing.wav")
        end
    end
    
    if (self.enraged) then
        if (enraged_sound_clock > enraged_sound_time) then
            enraged_sound_clock = 0
            self.enrage_sounds[1]:Stop()
            self.enrage_sounds[1]:SetSoundLevel(0)
            self.enrage_sounds[1]:Play()
            enraged_sound_time = SoundDuration("AbyssalEnraged.wav")
            print("Played AbyssalEnraged.wav")
        end
    end
    
end

function ENT:StopAllAmbSounds()
    for k,v in pairs(self.loaded_amb_sounds) do
        v:Stop()
    end
end

function ENT:StopAllSelfSounds()
    for k,v in pairs(self.loaded_sounds) do
        v:Stop()
    end
end

function ENT:GoToRandomPoint()

    print("GoToRandomPoint called")

    self.waiting = true
    self.walking = true
    self.chasing = false
    self.stalking = false
    
    self.loco:SetAcceleration(900) --. original: 400
    self.loco:SetDesiredSpeed(700) --. original: 700
    
    local options = options or {}
	self.path = Path("Chase")
	self.path:SetMinLookAheadDistance( options.lookahead or 500 )
	self.path:SetGoalTolerance( options.tolerance or 10 )
    local spot_options = {pos = self:GetEnemy():GetPos(), radius = 10000, stepup = 5000, stepdown = 5000}
    local spot = self:FindSpot('random', spot_options)

    --print ("spot is at "..spot.x.." "..spot.y.." "..spot.z.." and player is at "..self:GetEnemy():GetPos().x.." "..self:GetEnemy():GetPos().y.." "..self:GetEnemy():GetPos().z)

	self.path:Compute(self, spot)

	if ( !self.path:IsValid() ) then
        --print('failed')
        return "failed"
    end

    local walking_time = 90
    local walking_timer = 0
    self.LastPathRecompute = 0
    local wait_to_tp = 0
    local wait_time = 15

	while ( self.path:IsValid() and self:HaveEnemy() and self.walking) do

        self:InstaGib()

        --print("WALKING AWAY")
            
        self.path:Update( self )

        if (CurTime() - self.LastPathRecompute > 0.1) then
            self.LastPathRecompute = CurTime()
            self:RecomputeTargetPath(spot)
        end

        if ( options.draw ) then self.path:Draw() end

        local stuckTimer = 0
        local stuckTime = 1
        stuckTimer = stuckTimer + FrameTime()

        if (stuckTimer > stuckTime) then
            self:UnstickFromCeiling()
            stuckTimer = 0
        end

        if ( self.loco:IsStuck() ) then
            --print("stuck")
            --return "stuck"
        end

        walking_timer = walking_timer + FrameTime()
        if (walking_timer > walking_time) then
            walking_timer = 0
            TeleportToRandom()
        end

        if (!self:GetEnemy():Visible(self)) then
            wait_to_tp = wait_to_tp + FrameTime()
            if (wait_to_tp > wait_time) then
                self:TeleportToRandom()
            end
        end

        self:Sounds()

        coroutine.yield()
	end

    self.walking = false
    self.waiting = false

	return "ok"
end

local VECTOR_HIGH = Vector(0, 0, 16384)
ENT.LastPathingInfraction = 0

function ENT:RecomputeTargetPath(path_target)
	if (CurTime() - self.LastPathingInfraction < 5) then
		return
	end

	local targetPos = path_target

	-- Run toward the position below the entity we're targetting, since we can't fly.
	trace.start = targetPos
	trace.endpos = targetPos - VECTOR_HIGH
	trace.filter = self:GetEnemy()
	local tr = util.TraceEntity(trace, self:GetEnemy())

	-- Of course, we sure that there IS a "below the target."
	if (tr.Hit and util.IsInWorld(tr.HitPos)) then
		targetPos = tr.HitPos
	end

	local rTime = SysTime()
	self.path:Compute(self, targetPos)

	if (SysTime() - rTime > 0.005) then
		self.LastPathingInfraction = CurTime()
	end
end

function ENT:RandBehaviour()
    self.waiting = true
    self.stalking = false
    local choice = math.random(-1, 2) --. surely this could be math.random(0, 1)? still works the same though.

    if choice > 0 then
        self:Hide()
    else
        self:ChasePlayer()
    end

end

function ENT:Hide()
    print("Hiding")
    self:GoToRandomPoint()

    local choice = math.random(1, 2)

    -- roll a dice between going back to stalking or ambushing
    if choice == 2 then
        self:Ambush()
    end

end

function ENT:Ambush()
    print("Decided to ambush, ambush at ", self:GetPos())
    self.ambushing = true
    self.loco:SetDesiredSpeed(0) --. don't think this is necessary.
    self:StopAllAmbSounds()
    self:StopAllSelfSounds()

    local ambushcounter = 0
    while self.ambushing do
        ambushcounter = ambushcounter + FrameTime()

        if ambushcounter > 25 then
            print("Ambush timer expired, now stalking ")
            self:StalkEnemy()
        end

        if self:GetPlayerVisible() then
            self.ambushing = false
            self:ChasePlayer()
        end
        coroutine.yield()
    end

end

function ENT:TeleportToRandom()
    local spot_options = {pos = self:GetEnemy():GetPos(), radius = 10000, stepup = 5000, stepdown = 5000}
    local spot = nil
    local lookForSpot = true
    self.path = Path("Chase")
	self.path:SetMinLookAheadDistance(300)
	self.path:SetGoalTolerance(20)
    while (lookForSpot) do
        self.path:Compute(self, self:GetEnemy():GetPos())
        lookForSpot = false
        spot = self:FindSpot('random', spot_options)
        if (spot == nil) then lookForSpot = true end
        if (!self.path:IsValid()) then lookForSpot = true end
        coroutine.wait(0.1)
    end
    
    self:SetPos(spot)

    print("Teleported to spot "..spot.x.." "..spot.y.." "..spot.z)

    self.waiting = false
    self.walking = false
    self.chasing = false
    self.stalking = false
end

function ENT:UnstickFromCeiling()
	if (self:IsOnGround()) then return end

	local myPos = self:GetPos()
	local myHullMin, myHullMax = self:GetCollisionBounds()
	local myHull = (myHullMax - myHullMin)
	local myHullTop = myPos + vector_up * myHull.z
	trace.start = myPos
	trace.endpos = myHullTop
	trace.filter = self
	local upTrace = util.TraceLine(trace, self)

	if (upTrace.Hit and upTrace.HitNormal ~= vector_origin and upTrace.Fraction > 0.5) then
		local unstuckPos = myPos + upTrace.HitNormal * (myHull.z * (1 - upTrace.Fraction))
		self:SetPos(unstuckPos)
	end
end

ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
local terminusMaterial = Material("abyssal/npc_abyssal.png", "smooth mips")
local draw_offset = Vector(0, 0, 64)

function ENT:RenderOverride()
    self:SetRenderBounds(Vector(-80, -80, 0), Vector(80, 80, 80))
	render.SetMaterial(terminusMaterial)
	render.DrawSprite(self:GetPos() + draw_offset, 128, 128)
end

list.Set("NPC", "npc_abyssal", {
    Name = "Abyssal",
    Class = "npc_abyssal",
    Category = "Abyss Nextbots"
})
