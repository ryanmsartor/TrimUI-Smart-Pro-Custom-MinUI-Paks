pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- bas
-- by yokoboko

--disable btnp repeat
poke(0X5F5C, 255)

--game data
cartdata("bas_data_1")

function _init()
    current_scene=splash_scene:new()
end

function _update60()
    current_scene:update()
end

function _draw()
    current_scene:draw()
end


--class inheritance
function extend(class,baseclass)
    for k,v in pairs(baseclass) do
        class[k]=v
    end
end


splash_scene={}

function splash_scene:new(o)
    o=setmetatable(o or {},self)
    self.__index=self
    o.text="yokoboko"
    o.fading=0
    o.fadespeed=5
    o.start_fadeout=120
    o.count=0
    return o
end

function splash_scene:update()
    if self.count<self.start_fadeout then
        self.count+=1
        if (self.count==self.start_fadeout) self.fading=1
    end
    if self.fading==-1 and self.count==self.start_fadeout then
        current_scene=game_scene:new()
    end
end

function splash_scene:draw()
    cls()
    if (self.fading>0) self:_fadeout()
    if (self.fading<0) return
    local y=47
    spr(204,47,y,4,4)
    print(self.text,63-#self.text*2,y+34,15)
end

function splash_scene:_fadeout()
    local fade,c,p={[0]=0,17,18,19,20,16,22,6,24,25,9,27,28,29,29,31,0,0,16,17,16,16,5,0,2,4,0,3,1,18,2,4}
    self.fading+=1
    if self.fading%self.fadespeed==1 then
        for i=0,15 do
            c=peek(24336+i)
            if (c>=128) c-=112
            p=fade[c]
            if (p>=16) p+=112
            pal(i,p,1)
        end
        if self.fading==7*self.fadespeed+1 then
            cls()
            pal()
            self.fading=-1
        end
    end
end



game_scene={}

function game_scene:new(o)
    o=setmetatable(o or {},self)
    self.__index=self

    --constants
    o.tile_width = 16
    o.tile_height = 24

    --init
    o.state_initial="initial"
    o.state_playing="playing"
    o.state_will_die="will_die"
    o.state_dead="dead"
    o.state=o.state_initial
    o.buttons_cooldown=0
    o.transition_scene=false

    --layers
    o.background=background:new()
    o.columns=columns:new()
    o.trap=trap:new()
    o.player=player:new({tile_height=o.tile_height})
    o.score=score:new()
    o.game_initial=game_initial:new()
    o.game_over=game_over:new()
    o.transition=transition:new()
    o.camera=game_camera:new({y=o.player.pos.y})

    --music
    music(0,600)
    return o
end

function game_scene:update()
    --get button action
    local action_right=self:button_action_right()
    if self.buttons_cooldown>0 then
        self.buttons_cooldown-=1
        action_right=nil
    end

    --restart game
    if self.state==self.state_dead and action_right!=nil then
        self.transition_scene=true
        self.transition:start()
        return
    end

    --update layers
    if (self.state!=self.state_dead) self.player:update(action_right,self.trap.pos.y,self.state==self.state_will_die)
    if (self.state!=self.state_initial) self.trap:update(self.camera.y,self.score.score,self.state==self.state_dead)
    self.camera:update(self.player.pos.y)
    self.columns:update(self.tile_width,self.tile_height,self.camera.y,self.player,action_right,self.state==self.state_dead)
    self.background:update(self.camera.y)

    --update state
    if action_right!=nil and self.columns:will_collide(self.player) then
        self.state=self.state_will_die
        music(-1, 300)
        sfx(21)
    end
    if self.state==self.state_initial and action_right!=nil then
        self.state=self.state_playing
        self.game_initial:hide()
        music(2)
        sfx(26)
    elseif self.state!=self.state_dead and (self.columns:collide(self.player) or self.trap:collide(self.player)) then
        if (self.state!=self.state_will_die) sfx(21)
        sfx(27)
        self.buttons_cooldown=22
        self.state=self.state_dead
        music(-1, 300)
    end

    --update score
    if (self.state!=self.state_initial and self.state!=self.state_dead) self.score:update(self.camera.y,(action_right!=nil))

    --game initial
    if (self.game_initial!=nil and self.game_initial.anim_finished) self.game_initial=nil 
    if (self.game_initial!=nil) self.game_initial:update(self.camera.y)

    --game over
    if (self.state==self.state_dead) self.game_over:update(self.camera.y,self.player.pos,self.score.score)

    --transition
    if (self.state==self.state_dead and self.transition_scene and self.transition.transition==nil) current_scene=game_scene:new()
    self.transition:update(self.camera.y)
end

function game_scene:draw()
    cls()
    --fade out game scene if the player is dead
    if (self.state==self.state_dead) pal({0,1,3,2,5,13,6,8,4,10,11,12,1,14,9,0}, 0)
    self.camera:draw()
    self.background:draw()
    self.columns:draw(self.tile_width,self.tile_height)
    self.trap:draw()
    if (self.state!=self.state_initial and self.state!=self.state_dead) self.score:draw()
    if (self.game_initial!=nil) self.game_initial:draw()
    if (self.state!=self.state_dead and self.transition.anim_t>0) self.player:draw()
    pal()

    --game over
    if (self.state==self.state_dead) self.game_over:draw()

    --transition
    self.transition:draw()

    -- draw_stats(self.camera.y) --draw stats
end

function game_scene:button_action_right()
    --`true` if right button is pressed
    --`false` if left button is pressed
    --`nil` if no button is presed
    if (self.state==self.state_will_die or self.transition_scene) return nil
    if btnp(0) or btnp(4) then
        return false
    elseif btnp(1) or btnp(5) then
        return true
    end
    return nil
end


background={}

function background:new(o)
    o=setmetatable(o or {},self)
    self.__index=self

    --init
    o.tile_width=8 --tiles
    o.tile_height=4 --tiles
    o.x=32
    o.heigh=o.tile_height*8*3 --pixels
    o.tiles={}
    return o
end

function background:update(cam_y)
    --visible
	local min_tile = flr(cam_y/self.heigh)
	local max_tile = ceil((cam_y+128)/self.heigh)

	--delete
	for k,v in pairs(self.tiles) do
		if v<min_tile or v>max_tile then
			self.tiles[k] = nil
		end
	end
	
	--create
	for i=min_tile,max_tile do 
		if self.tiles["t"..i]==nil then 
			self.tiles["t"..i]=i
		end
	end
end

function background:draw()
    for k,v in pairs(self.tiles) do
        local y=v*self.heigh
        spr(136,self.x,y,self.tile_width,self.tile_height)
        spr(136,self.x,y+32,self.tile_width,self.tile_height)
		spr(128,self.x,y+64,self.tile_width,self.tile_height)
	end
end


columns={}

function columns:new(o)
	o=setmetatable(o or {},self)
	self.__index=self

	--init
	o.tiles={}
	return o
end

function columns:update(tile_width,tile_height,cam_y,player,action_right,is_dead)
	--visible
	local min_tile = flr(cam_y/tile_height)
	local max_tile = ceil((cam_y+128)/tile_height)

	--delete
	for k,v in pairs(self.tiles) do
		if v.idx<min_tile or v.idx>max_tile then
			self.tiles[k] = nil
		end
	end
	
	--create, add jump effect and update
	for i=min_tile,max_tile do 
		if self.tiles["t"..i]==nil then 
			--create [don't add saws to the first few tiles (first from bottom up is 1365)]
			local tile_saw=(i<1358) and saw:new({idx=i,tile_width=tile_width,tile_height=tile_height}) or nil
			self.tiles["t"..i]={idx=i,saw=tile_saw}
		elseif self.tiles["t"..i].saw!=nil then
			--update saw
			self.tiles["t"..i].saw:update()
		end
		if not is_dead then
			if self.tiles["t"..i].jfx!=nil then
				--update jump effect
				self.tiles["t"..i].jfx:update()
			elseif action_right!=nil and player.tile_pos==i then
				--add jump effect
				self.tiles["t"..i].jfx=jump_effect:new({right_wall=player.pos.x>63,y=i*tile_height})
			end
		end
	end
end

function columns:draw(tile_width,tile_height)
	for k,v in pairs(self.tiles) do
		if (v.saw != nil) v.saw:draw()
		if (v.jfx != nil) v.jfx:draw()
		local left_sprite=(v.saw != nil and v.saw.left) and 66 or 64 
		local right_sprite=(v.saw != nil and v.saw.left == false) and 66 or 64
		local y = v.idx*tile_height
		spr(left_sprite,0,y,2,3)
	 	spr(right_sprite,128-tile_width,y,2,3,true)
	end
end

function columns:collide(player)
	for k,v in pairs(self.tiles) do
		if (v.saw != nil and v.saw:collide(player)) return true
	end
	return false
end

function columns:will_collide(player)
	local target_tile=player.tile_pos-1
	return self.tiles["t"..target_tile].saw!=nil and self.tiles["t"..target_tile].saw.left!=player.right_wall
end


game_camera={}

function game_camera:new(o)
    o=setmetatable(o or {},self)
    self.__index=self
    
    --init
    o.offset=-84 --player y offset
    o.tracking=26 --slowdown player tracking
    o.track_faster=74 --track faster if player is less than this treshold
	o.y = o.y or 0
    o.y+=o.offset
	return o
end

function game_camera:update(player_y)
    local cam_tracking=self.tracking
    --track faster
    if (player_y-self.y<self.track_faster) cam_tracking/=2
    --shift
    self.y-=(self.y-(player_y+self.offset))/cam_tracking
end

function game_camera:draw()
    camera(0,self.y)
end


game_initial={}

function game_initial:new(o)
    o=setmetatable(o or {},self)
    self.__index=self
    
    --init
    o.cam_y=0
    o.y=0
    o.anim=false
    o.anim_finished=false
    o.anim_t=0
    o.anim_d=32
    o.highscore=higscore:new()
    o.controls_demo=controls_demo:new()
	return o
end

function game_initial:update(cam_y,player_pos,score)
    local offset_y=0
    if self.anim and self.anim_finished==false then
        offset_y=easing_cubic_in_out(self.anim_t,0,110,self.anim_d)
        self.anim_t+=1
        if (self.anim_t>self.anim_d) self.anim_finished=true
    end
    self.cam_y=cam_y+offset_y
    self.highscore:update(self.cam_y+self.y)
    self.controls_demo:update(self.cam_y+self.y)
end

function game_initial:draw()
    if (self.anim) pal({0,1,3,2,5,13,6,2,4,2,11,12,1,4,93,0}, 0)
    --name sprite
    palt(0,false)
    palt(11,true)
    spr(192,34,self.cam_y+18,8,4)
    palt()
    
    --highscore and controls demo
    self.highscore:draw()
    self.controls_demo:draw()
    pal()
end

function game_initial:hide()
    self.anim=true
end


game_over={}

function game_over:new(o)
    o=setmetatable(o or {},self)
    self.__index=self
    
    --init
    o.x=63
    o.y=38
    o.circles={
        {x=o.x,y=o.y,r=28,d=16},
        {x=o.x,y=o.y+24,r=8,d=18},
        {x=o.x-20,y=o.y-20,r=8,d=20},
        {x=o.x-20,y=o.y+32,r=2,d=22},
        {x=o.x+20,y=o.y-34,r=1,d=24},
        {x=o.x+20,y=o.y+34,r=4,d=26},
        {x=o.x-39,y=o.y+10,r=3,d=28},
        {x=o.x-32,y=o.y+18,r=1,d=28},
    }
    o.cam_y=0
    o.player_x=0
    o.player_y=0
    o.anim_t=0
    o.score=nil
    o.highscore=false

    o.particles={}
    o.explode_size=3
    o.explode_colors={8,8,8,4}
    o.explode_amount=10
	return o
end

function game_over:update(cam_y,player_pos,score)
    self.cam_y=cam_y
    self.player_x=player_pos.x+8
    self.player_y=player_pos.y-cam_y+8

    --set score, highscore and explode
    if self.score==nil then
        self.score=score
        local highscore=dget(0)
        if score>highscore then
            dset(0, score)
            self.highscore=highscore!=0
        else
            self.highscore=false
        end
        self:explode(player_pos.x,
                     player_pos.y,
                     self.explode_size,
                     self.explode_colors,
                     self.explode_amount)
        sfx(25)
    end

    --update particles
    for p in all(self.particles) do
        --lifetime
        p.t+=1
        if p.t>p.die then del(self.particles,p) end

        --color depends on lifetime
        if p.t/p.die < 1/#p.c_table then
            p.c=p.c_table[1]

        elseif p.t/p.die < 2/#p.c_table then
            p.c=p.c_table[2]

        elseif p.t/p.die < 3/#p.c_table then
            p.c=p.c_table[3]

        else
            p.c=p.c_table[4]
        end

        --physics
        if p.grav then p.dy+=.5 end
        if p.grow then p.r+=.1 end
        if p.shrink then p.r-=.1 end

        --move
        p.x+=p.dx
        p.y+=p.dy
    end 
end

function game_over:draw()
    --explosion
    for p in all(self.particles) do
        --draw pixel for size 1, draw circle for larger
        if p.r<=1 then
            pset(p.x,p.y,p.c)
        else
            circfill(p.x,p.y,p.r,p.c)
        end
    end

    --circless
    self.anim_t=min(self.anim_t+1,100)
    for c in all(self.circles) do
        local t=min(self.anim_t,c.d)
        local x=easing_cubic_out(t,self.player_x,c.x-self.player_x,c.d)
        local y=easing_cubic_out(t,self.player_y,c.y-self.player_y,c.d)
        local r=easing_cubic_out(t,0,c.r,c.d)
        circfill(x,self.cam_y+y,r,8)
        circfill(x,self.cam_y+y,r,8)
    end
    
    --text
    if self.anim_t>=10 then
        print("\^igame over\n",self.x-17,self.cam_y+self.y-8,2)
        line(self.x-19,self.cam_y+self.y-8,self.x-19,self.cam_y+self.y-4,2)
        line(self.x+19,self.cam_y+self.y-8,self.x+19,self.cam_y+self.y-4,2)
        if self.highscore then
            print("new",self.x-6,self.cam_y+self.y+2)
            print("highscore",self.x-18,self.cam_y+self.y+8)
            print(self.score,64-flr((#tostr(self.score)*4)/2),self.cam_y+self.y+16)
        else
            print("score",self.x-9,self.cam_y+self.y+7)
            print(self.score,64-flr((#tostr(self.score)*4)/2),self.cam_y+self.y+15)
        end
    end
end

-- explosion effect
function game_over:explode(x,y,r,c_table,num)
    for i=0,num do
        self:add_particle(
            x,         -- x
            y,         -- y
            20+rnd(10),-- die
            rnd(2)-1,  -- dx
            rnd(2)-1,  -- dy
            false,     -- gravity
            false,     -- grow
            true,      -- shrink
            r,         -- radius
            c_table    -- color_table
        )
    end
end

function game_over:add_particle(x,y,die,dx,dy,grav,grow,shrink,r,c_table)
    local fx={
        x=x,
        y=y,
        t=0,
        die=die,
        dx=dx,
        dy=dy,
        grav=grav,
        grow=grow,
        shrink=shrink,
        r=r,
        c=0,
        c_table=c_table
    }
    add(self.particles,fx)
end


animatable={}

function animatable:new(o)
	o=setmetatable(o or {},self)
	self.__index=self
	
	--init
	--o.current [current animation name]
	o.animations={}
	o.frame=1
	o.count=1
	o.sprite=0 --[sprite index]
	return o
end

function animatable:add_animation(name,duration,list)
	self.animations[name]={duration=duration,list=list}
	if self.current==nil then 
		self.current = name 
		self.sprite = self.animations[self.current].list[self.frame]
	end
end

function animatable:play_animation(name)
	if self.current != name then
		self.current = name
		self.count=1
		self.frame=1
		self.sprite = self.animations[self.current].list[self.frame]
	end
end

function animatable:update_animation()
	if self.current != nil then 
		self.count+=1
		local animation=self.animations[self.current]
		if self.count>animation.duration then
			self.count=1
			self.frame+=1
			if (self.frame>count(animation.list)) self.frame=1
		end
		self.sprite = self.animations[self.current].list[self.frame]
		if (self.sprite==-1) then
			self.current=nil
			self.sprite=nil
		end
	end
end


collidable={}

function collidable:new(o)
    o=setmetatable(o or {},self)
    self.__index=self
    
    --init
    o.pos = o.pos or {x=0,y=0}
    o.hitbox = o.hitbox or {x=0,y=0,w=1,h=1}
    return o
end

function collidable:collide(other)
    if
        other.pos.x+other.hitbox.x+other.hitbox.w>self.pos.x+self.hitbox.x and 
        other.pos.y+other.hitbox.y+other.hitbox.h>self.pos.y+self.hitbox.y and
        other.pos.x+other.hitbox.x<self.pos.x+self.hitbox.x+self.hitbox.w and
        other.pos.y+other.hitbox.y<self.pos.y+self.hitbox.y+self.hitbox.h 
    then
        return true
    end
end

function collidable:draw_collision_box()
    local x = self.pos.x+self.hitbox.x
    local y = self.pos.y+self.hitbox.y
    rect(x,y,x+self.hitbox.w,y+self.hitbox.h,8)
    rectfill(self.pos.x,self.pos.y,self.pos.x,self.pos.y,9)
end



saw={}
extend(saw,animatable)
extend(saw,collidable)

function saw:new(o)
    o=setmetatable(o,self)
    o=animatable.new(self,o)
    o=collidable.new(self,o)
    self.__index=self

    --init {idx=0,tile_width=1,tile_height=1}
    o.left=rnd(1)<0.5

    --collidable
    local x=(o.left) and o.tile_width-8 or 128-o.tile_width-16
	o.pos={x=x,y=o.idx*o.tile_height}
	o.hitbox={x=3,y=3,w=16,h=16}
    
    --animatable
    o:add_animation("spin",3,{68,71})
    return o
end

function saw:update()
    self:update_animation()
end

function saw:draw()
    palt(11,true)
    spr(self.sprite,self.pos.x,self.pos.y,3,3,not self.left)
    palt()
end


player={}
extend(player,animatable)
extend(player,collidable)

function player:new(o)
	o=setmetatable(o or {},self)
	o=animatable.new(self,o)
	o=collidable.new(self,o)
	self.__index=self

	--init
	o.right_wall=rnd(1)<0.5
	o.left_x=12
	o.right_x=100
	o.tile_height=o.tile_height or 8
	o.tile_offset_y=4 --in pixels
	o.tile_pos=1362
	o.jumping=false
	o.jump_speed=0.08 -- in tiles
	o.jump_speed_will_die=0.0042 -- in tiles
	o.jump_tile_pos=0 --in tiles
	o.jump_changes_direction=false
	o.jump_amp=8 --amplitude

	--collidable
	o.pos={x=o.left_x,y=o.tile_pos*o.tile_height+o.tile_offset_y}
	o.hitbox={x=3,y=1,w=8,h=11}
	
	--animatable
	o:add_animation("idle",20,{0,2})
	o:add_animation("scared",1,{4})
	o:add_animation("will_die",3,{10,12,14})
	o:add_animation("flying",2,{6,8})
	return o
end

function player:update(action_right,trap_y,will_die)
	--jump
	if action_right!=nil then
		sfx(20)
		if self.jumping then
			self.tile_pos-=1
		else
			self.jumping=true
		end
		self.jump_tile_pos=0
		self.jump_changes_direction=self.right_wall!=action_right
		self.right_wall=action_right
	end
	if self.jumping then
		local treshold=self.jump_changes_direction and -0.7 or -0.275
		local speed = ternary(will_die and self.jump_tile_pos<treshold,
								self.jump_speed_will_die,
								self.jump_speed)
		self.jump_tile_pos=max(self.jump_tile_pos-speed,-1)
		if self.jump_tile_pos==-1 then
			self.jumping=false
			self.tile_pos-=1
			self.jump_tile_pos=0
		end
	end

	--position
	self.pos.y=(self.tile_pos+self.jump_tile_pos)*self.tile_height+self.tile_offset_y
	if self.jumping then
		if self.jump_changes_direction then
			local offset=(self.right_x-self.left_x)*abs(self.jump_tile_pos)
			self.pos.x=ternary(self.right_wall,self.left_x+offset,self.right_x-offset)
		else
			local offset=sin(self.jump_tile_pos/2)*self.jump_amp
			self.pos.x=ternary(self.right_wall,self.right_x-offset,self.left_x+offset)
		end
	else
		self.pos.x=ternary(self.right_wall,self.right_x,self.left_x)
	end

	--animation
	if will_die then
		self:play_animation("will_die")
	elseif self.jumping then
		self:play_animation("flying")
	elseif trap_y-self.pos.y<28 then
		self:play_animation("scared")
	else
		self:play_animation("idle")
	end
	self:update_animation()
end

function player:draw()
	local facing_left=ternary(self.jumping,not self.right_wall, self.right_wall)
	spr(self.sprite,self.pos.x,self.pos.y,2,2,facing_left)
end



jump_effect={}
extend(jump_effect,animatable)

function jump_effect:new(o)
    o=setmetatable(o,self)
    o=animatable.new(self,o)
    self.__index=self

    --init
    o.right_wall=o.right_wall
    o.y=o.y or 0
    o.left_x=16
    o.right_x=104
    -- animatable
    o:add_animation("fx",3,{32,33,34,35,36,-1})
    return o
end

function jump_effect:update()
    self:update_animation()
end

function jump_effect:draw()
    if self.sprite!=nil then
        local x=self.right_wall and self.right_x or self.left_x
        spr(self.sprite,x,self.y+4,1,2,self.right_wall)
    end
end


trap={}
extend(trap,animatable)
extend(trap,collidable)

function trap:new(o)
    o=animatable.new(self,o)
    o=setmetatable(o,self)
    self.__index=self

    --init
    o.speed_start=0.5
    o.speed_top=1.7
    o.speed_top_treshold=200 --game score points when we reach top speed
    o.offset=128
    o.offset_min=120
    o.tiles={122,123,124,125,123,124,125,123,124,125,123,126}
    o.tiles_fill={112,113,113,113,113,113,113,113,113,113,113,114}
    o.speed_top=o.speed_top-o.speed_start --exclude start from top speed to ensure max is correct

    --collidable
    o.pos={x=16,y=32767}
	o.hitbox={x=0,y=6,w=95,h=9}

    --animatable
    o:add_animation("spin",3,{74,77})
    return o
end

function trap:update(camera_y,score,is_dead)
    self:update_animation()
    local speed=min(score/self.speed_top_treshold,1) --0 to 1
    local shift=self.speed_start+self.speed_top*speed
    self.pos.y=max(min(self.pos.y-shift, camera_y+self.offset),camera_y+72)
    --animate in the trap when the game starts
    self.offset=max(self.offset-0.2, self.offset_min)
end

function trap:draw()
    for i=0,3 do
        spr(self.sprite,16+i*24,self.pos.y,3,3)
    end
    palt(0,false)
    palt(11,true)
    for i=1,#self.tiles do
        spr(self.tiles[i],8+i*8,self.pos.y+16,1,1)
        spr(self.tiles[i],8+i*8,self.pos.y+16,1,1)
        spr(self.tiles_fill[i],8+i*8,self.pos.y+24,1,1)
        spr(self.tiles_fill[i],8+i*8,self.pos.y+32,1,1)
        spr(self.tiles_fill[i],8+i*8,self.pos.y+40,1,1)
        spr(self.tiles_fill[i],8+i*8,self.pos.y+48,1,1)
    end
    palt()
end


transition={}
extend(transition,animatable)

function transition:new(o)
	o=setmetatable(o or {},self)
    o=animatable.new(self,o)
	self.__index=self

	--init
	o.cam_y=0
    o.saw_size=54
    o.transition=nil
    o.y=0
    o.offset=128+ceil(o.saw_size/2)
    o.anim_t=0
    o.anim_d=20

    --animatable
    o:add_animation("spin",1,{68,71})

    --
    o:finish()
	return o
end

function transition:update(cam_y)
    if (self.transition==nil) return
    self.cam_y=cam_y
    self:update_animation()
    self.anim_t=min(self.anim_t+1,self.anim_d)
    if self.transition=="start" then
        self.y=self.offset-easing_cubic_out(self.anim_t,0,self.offset,self.anim_d)
    else
        self.y=-easing_cubic_out(self.anim_t,0,self.offset,self.anim_d)
    end
end

function transition:draw()
    if (self.transition==nil) return
    pal({0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}, 0)
    palt(0,false)
    palt(11,true)
    
    --rect
    rectfill(0,self.cam_y+self.y,128,self.cam_y+self.y+128,0)

    --saws
    local sx=ternary(self.sprite==68,32,56)
    local posy=self.cam_y+self.y+ternary(self.transition=="start",0,116)-flr((self.saw_size-12)/2)
    sspr(sx, 32, 24, 24, -4, posy,self.saw_size,self.saw_size)
    sspr(sx, 32, 24, 24, 40, posy,self.saw_size,self.saw_size)
    sspr(sx, 32, 24, 24, 80, posy,self.saw_size,self.saw_size)
    
    palt()
    pal()

    --end transition
    if (self.anim_t>=self.anim_d) self.transition=nil
end

function transition:start()
    sfx(23)
    self.transition="start"
    self.y=self.offset
    self.anim_t=0
end

function transition:finish()
    sfx(24)
    self.transition="finish"
    self.y=0
    self.anim_t=0
end


controls_demo={}

function controls_demo:new(o)
    o=setmetatable(o or {},self)
    self.__index=self

    --init
    o.width=38
    o.height=22
    o.x=63-flr(o.width/2)
    o.y=0
    o.offset_y=66
    o.col=13
    o.active_col=15
    o.anim_idx=1
    o.anim_t=0
    --s: start; c: change; d: duration; out: ease out/in; lb: left button pressed; rb: right pressed; f: flip char at the end of the animation
    o.animations={
        --jump left side
        {s=0,c=0.3,d=14,out=true,lb=true},
        {s=0.3,c=-0.3,d=14,out=false},
        {s=0,c=0,d=8,out=true},
        {s=0,c=0.3,d=14,out=true,lb=true},
        {s=0.3,c=-0.3,d=14,out=false},
        {s=0,c=0,d=8,out=true},
        {s=0,c=0.3,d=14,out=true,lb=true},
        {s=0.3,c=-0.3,d=14,out=false},
        {s=0,c=0,d=8,out=true},

        --change direction
        {s=0,c=1,d=24,out=true,rb=true,f=true},
        {s=1,c=0,d=24,out=true},

        --jump right side
        {s=1,c=-0.3,out=true,d=14,rb=true},
        {s=0.7,c=0.3,out=false,d=14},
        {s=1,c=0,d=8,out=true},
        {s=1,c=-0.3,out=true,d=14,rb=true},
        {s=0.7,c=0.3,out=false,d=14},
        {s=1,c=0,d=8,out=true},
        {s=1,c=-0.3,out=true,d=14,rb=true},
        {s=0.7,c=0.3,out=false,d=14},
        {s=1,c=0,d=8,out=true},

        --change direction
        {s=1,c=-1,d=24,out=true,lb=true,f=false},
        {s=0,c=0,d=24,out=true},
    }
    o.char_x=0
    o.char_width=8
    o.char_height=4
    o.char_flip=false
    o.lbtn_pressed=0
    o.rbtn_pressed=0
    return o
end

function controls_demo:update(pos_y)
    self.y=pos_y+self.offset_y

    --update animation index and time
    local anim=self.animations[self.anim_idx]
    self.anim_t=self.anim_t+1
    if (self.anim_t>anim.d/2 and anim.f!=nil) self.char_flip=anim.f
    if self.anim_t>=anim.d then
        self.anim_idx+=1
        self.anim_t=0
     
        if (self.anim_idx>#self.animations) self.anim_idx=1
        anim=self.animations[self.anim_idx]
        if anim.lb then
            self.lbtn_pressed=14
        elseif anim.rb then
            self.rbtn_pressed=14
        end
       
    else
        self.lbtn_pressed=max(self.lbtn_pressed-1,0)
        self.rbtn_pressed=max(self.rbtn_pressed-1,0)
    end

    --update rect_x
    local anim_value=ternary(anim.out,easing_cubic_out(self.anim_t,anim.s,anim.c,anim.d),easing_cubic_in(self.anim_t,anim.s,anim.c,anim.d))
    self.char_x=anim_value*(self.width-self.char_width)
end 

function controls_demo:draw()
    --vertical lines
    line(self.x,self.y,self.x,self.y+self.height-4,self.active_col)
    line(self.x+self.width-1,self.y,self.x+self.width-1,self.y+self.height-4,self.active_col)

    --char
    spr(37,self.x+self.char_x,self.y+6,1,1,self.char_flip)

    --button icons
    local left_col=self.lbtn_pressed>0 and self.active_col or self.col
    palt(0,false)
    palt(11,true)
    print("⬅️",self.x-3,self.y+self.height,0)
    print("⬅️",self.x-3,self.y+self.height-1,left_col)
    print("🅾️",self.x-3,self.y+self.height+7,0)
    print("🅾️",self.x-3,self.y+self.height+6,self.col)

    local left_col=self.rbtn_pressed>0 and self.active_col or self.col
    print("➡️",self.x+self.width-4,self.y+self.height,0)
    print("➡️",self.x+self.width-4,self.y+self.height-1,left_col)
    print("❎",self.x+self.width-4,self.y+self.height+7,0)
    print("❎",self.x+self.width-4,self.y+self.height+6,self.col)
    palt()
end


score={}

function score:new(o)
	o=setmetatable(o or {},self)
	self.__index=self

	--init
	o.score=0
    o.x=0
    o.y=0
    o.offset_y=4
    o.width=0
    o.height=6
    o.anim_t=0
    o.anim_d=24
    o.anim_y=0
    o.anim_target=10
	return o
end

function score:update(cam_y,jumped)
    if (jumped) self.score+=1
    self.width=#tostr(self.score)*4
    self.x=64-ceil(self.width/2)
    self.y=cam_y+self.offset_y
    --slide animation
    if self.anim_t<self.anim_d then
        self.anim_t+=1
        self.anim_y=self.anim_target-easing_cubic_out(self.anim_t,0,self.anim_target,self.anim_d)
    end
end

function score:draw()
    local y=self.y-self.anim_y
    palt(0,false)
    palt(11,true)
    rectfill(self.x,y,self.x+self.width,y+self.height,0)
    spr(115,self.x-8,y,1,1,true)
    spr(115,self.x+self.width+1,y)
    palt()
    print(self.score,self.x+1,y+1,15)
end




higscore={}

function higscore:new(o)
	o=setmetatable(o or {},self)
	self.__index=self

	--init
    o.highscore=dget(0)
	o.highscore_string="best "..o.highscore
    o.width=#o.highscore_string*4
    o.height=6
    o.x=64-ceil(o.width/2)
    o.y=0
    o.offset_y=54
	return o
end

function higscore:update(cam_y)
    if (self.highscore==0) return
    self.y=cam_y+self.offset_y
end

function higscore:draw()
    if (self.highscore==0) return
    palt(0,false)
    palt(11,true)
    rectfill(self.x,self.y,self.x+self.width,self.y+self.height,0)
    spr(115,self.x-8,self.y,1,1,true)
    spr(115,self.x+self.width+1,self.y)
    palt()
    print(self.highscore_string,self.x+1,self.y+1,15)
end




function ternary (cond,T,F)
    if cond then return T else return F end
end


-- t = how far through the current movement you are
-- b = where the movement starts
-- c = the final change in value at the end.
-- d = the total duration of the movement
function easing_cubic_out(t,b,c,d)
    t /= d
    t-=1
    return c*(t*t*t + 1) + b
end 

function easing_cubic_in(t,b,c,d)
    t /= d
    return c*t*t*t + b
end

function easing_cubic_in_out(t,b,c,d)
    t /= d/2
    if (t < 1) return c/2*t*t*t + b
    t-=2
    return c/2*(t*t*t + 2) + b
end


function log(msg)
    printh("["..stat(93)..":"..stat(94)..":"..stat(95).."] "..msg)
end


function draw_stats(camera_y)
    local offset_y=camera_y or 0
    print("mem: "..stat(0),0,6+offset_y,7)
    print("cpu: "..stat(1),0,12+offset_y,7)
    print("fps: "..stat(7),0,18+offset_y,7)
end




__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000820000000000000820000000000000000000000000000000000000000000000082000000000000008200000000000000820000000
0000000820000000000000fffff0000000000fffff00000000000008200000000000000820000000000000fffff00000000000fffff00000000000fffff00000
000000fffff0000000000fff1f9900000000fff1f9900000000000fffff00000000000fffff0000000000fff1f99000000000fff1f99000000000fff1f990000
00000fff1f9900000000ffffff8400000000fffff110000000000fff1f99000000000fff1f9900000000ffffff1100000000ffffff1100000000ffffff110000
0000ffffff8400000000ffffff4f00000000fffff84000000000ffffff840000000444ffff840000000444ffff8400000000ffffff8400000000ffffff840000
0000ffffff4f00000000ffffffff00000000fffff4f00000000fffffff4ff000004fff4fff4ff000004fff4fff4f0000000f4fffff4f0000000fffff4f4f0000
0000ffffffff00000000fff4ffff00000000fff4ffff000000fffffffffff000004ffff4fffff000004ffff4ffff0000000ff4ffffff0000000fffff4fff0000
0000fff4ffff00000000ff4ffff400000000ff4ffff4000000fffff4fffff000006ffffffffff000006fffffffff0000000ff4ffffff0000000fffff4fff0000
0000ff4ffff40000000044ffff400000000044ffff400000004fff4fffff40000006ffffffff40000006fffffff40000000ff4ffffff0000000fffff4fff0000
000044ffff40000000000666640000000000066664000000000444fffff4000000006ffffff4000000006fffff40000000004ffffff400000000f444fff40000
00009666640000000000909000000000000090900000000000009666664000000000966666400000000006666490000000000fffff40000000000fffff400000
00009900000000000000990000000000000099000000000000009009000000000000900900000000000000009000000000000066649000000000006664900000
00009000000000000000900000000000000090000000000000000000000000000000000000000000000000000000000000000000900000000000000090000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000777000000f77000000007000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077000007ff770000ffff7000000007000fff00000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000007f770000ff7f70000f0f7700000000700fff1f0000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000ff700000f07700000007700000000000fffff99000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000f0000000f00000000000000000000000fffff84000000000000000000000000000000000000000000000000000000000000000000000000000000000
f0000000f00f00000700000000ff00000000f000ffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000
f000000000000000f7700000000f70000000070009fff00000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ff000000f0f0000000070000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ff000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f0000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f0000000f0000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000f0000000f077000000077000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000fff000007ff7700f0007f700000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000007ff7000077f7700000ff7700000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077000000777000000007000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02202124444444490220212444444449bbbbbbbbbbb7bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000
22201211444444942220121144444494bbbbbbbbbb767bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000000000007000000000000000000000000000000000000
02202121122222440220212112222244bbbbbbbbb66666bbbbbbbbbbbbbbbb776bbbbb677bbbbbbb000000000076700000000000000000000000000000000000
00000001122222440000000112222244bbbbbbbb6666666bbbbbbbbbbbbbbb76666bb6667bbbbbbb000000000666660000000000000000077000007700000000
00202101122222440020210112222244bbbb776666666666677bbbbbbbbbbb66666666666bbbbbbb000000006666666000000000000000076660066700000000
02221201122222440222120112222244bbbb766666666666667bbbbbbbbbb6666666666666bbbbbb000007766666666677000000000000666666666660000000
00202101122222440020210112222244bbbb666666666666666bbbbbbb7766666666666666677bbb000007666666666667000000000006666666666666000000
00000001122222440000000112222244bbbb666666666666666bbbbbbb7666666666666666667bbb000006666666666666000000000776666666666666770000
02202121122222440220212112222244bbb6666616ddd6666666bbbbbb66666616ddd66666666bbb0000666666ddd666666000000007666666ddd66666670000
22201211122222442220121112411244bb66666611dddd6666666bbbbbb6666611dddd666666bbbb000666666ddddd6666660000000066666ddddd6666600000
02202121122222440220212112421244b766666611111dd6666667bbbbbb666611111dd66666bbbb00766666dd111dd66666700000000666dd111dd666600000
000000011222224400000001124212447666666611151dd66666667bbbbb666611151dd6666bbbbb07666666dd151dd66666670000000666dd151dd666000000
00202101122222440020210112421244b766666611111dd6666667bbbbb6666611111dd66666bbbb00766666dd111dd66666700000006666dd111dd666600000
02221201122222440222120112941244bb66666611dddd6666666bbbbbb6666611dddd666666bbbb000666666d111d6666660000000066666d111d6666600000
00202101122222440020210112222244bbb6666616ddd6666666bbbbbb66666616ddd66666666bbb000066666611166666000000000766666611166666670000
00000001122222440000000112222244bbbb666666666666666bbbbbbb7666666666666666667bbb000006666111116666000000000776666111116666770000
02202121122222440220212112222244bbbb666666666666666bbbbbbb7766666666666666677bbb000007661111111667000000000006661111111666000000
22201211122222442220121112222244bbbb766666666666667bbbbbbbbbb6666666666666bbbbbb000007761111111677000000000000661111111660000000
02202121122222440220212112222244bbbb776666666666677bbbbbbbbbbb66666666666bbbbbbb000000006666666000000000000000076600666700000000
00000001122222440000000112222244bbbbbbbb6666666bbbbbbbbbbbbbbb7666bb66667bbbbbbb000000000666660000000000000000077000007700000000
00202101122222440020210112222244bbbbbbbbb66666bbbbbbbbbbbbbbbb776bbbbb677bbbbbbb000000000076700000000000000000000000000000000000
02221201122222440222120112222244bbbbbbbbbb767bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000000000007000000000000000000000000000000000000
00202101111111440020210111111144bbbbbbbbbbb7bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000
00000001111111140000000111111114bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000
140b0b42240b0b42240b0b4100bbbbbb000000000000000000000000000000000000000000000000bb444444bbbbbbb44444444444444444444444bb00000000
1240b4211240b4211240b421000bbbbb000000000000000000000000000000000000000000000000b4444444bbbbbbb444444444444444444444444b00000000
1124421b0124421b01244211000bbbbb000000000000000000000000000000000000000000000000142222244444444422222222222222242222224100000000
101221b0b01221b0b01221b1000bbbbb000000000000000000000000000000000000000000000000122222224444444222222222222222222222222100000000
1b42240b0b42240b0b422401000bbbbb000000000000000000000000000000000000000000000000122222222222222222222222222222222222222100000000
14211240b4211240b4211241000bbbbb000000000000000000000000000000000000000000000000122112222221122222211222222112222221122100000000
121b0124421b0124421b012100bbbbbb000000000000000000000000000000000000000000000000121b0122221b0122221b0122221b0122221b012100000000
11b0b01221b0b01221b0b011bbbbbbbb00000000000000000000000000000000000000000000000011b0b01221b0b01221b0b01221b0b01221b0b01100000000
00000010111111201111222022222220222222220222111102111111010000000000001011111120111122202222222022222222022211110211111101000000
00000010111111201112122022222240422222220221211102111111010000000000001011111120111212202222222022222222022121110211111101000000
11111110222222201111222022444990994442220222111102222222011111111111111022222220111122202222222022222222022211110222222201111111
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00101111112011111220121222402544445204222121022111110211111101000010111111201111122012122220222222220222212102211111021111110100
001011111120111111202122229024ffff4209222212021111110211111101000010111111201111112021222220222222220222221202111111021111110100
11101111222011112220121249904ffffff409942121022211110222111101111110111122201111222012122220222222220222212102221111022211110111
0000000000000000000000000004ffffffff40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000001011111120111224902424ffffffff42420942211102111111010000000000001011111120111222202222222022222222022221110211111101000000
0000001011111120112122904294ffffffff49240922121102111111010000000000001011111120112122202222222022222222022212110211111101000000
1111111011122220111224902424ffffffff42420942211102222111011111111111111011122220111222202222222022222222022221110222211101111111
0000000000000000000000000004ffffffff40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010111111101111222012142424ffffffff42424121022211110111111101000010111111101111222012122220222222220222212102221111011111110100
0010111111101111112021224294ffffffff49242212021111110111111101000010111111101111112021222220222222220222221202111111011111110100
0110111111101112222012142424ffffffff42424121022221110111111101100110111111101112222012122220222222220222212102222111011111110110
0000000000000000000000000004ffffffff40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0111011011112220111214904294ffffffff49240941211102221111011011100111011011112220111212202222222022222222022121110222111101101110
0000001011111120112122902424ffffffff42420922121102111111010000000000001011111120112122202222222022222222022212110211111101000000
0111011011112220111214904294ffffffff49240941211102221111011011100111011011112220111212202222222022222222022121110222111101101110
0000000000000000000000000004ffffffff40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0110111111101111222012192424ffffffff42429121022211110111111101100110111111101111222012122220222222220222212102221111011111110110
0010111111101111112021214294ffffffff49241212021111110111111101000010111111101111112021212220222222220222121202111111011111110100
0010111111101111122012192424ffffffff42429121022111110111111101000010111111101111122012122220222222220222212102211111011111110100
0000000000000000000000000004ffffffff40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111011122220111214904294ffffffff49240941211102222111011111111111111011122220111212202222222022222222022121110222211101111111
0000001011111120112122902424ffffffff42420922121102111111010000000000001011111120112122202222222022222222022212110211111101000000
00000010111111201112149042944444444449240941211102111111010000000000001011111120111212202222222022222222022121110211111101000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11101111222011112220121249909944449909942121022211110222111101111110111122201111222012122220222222220222212102221111022211110111
00101111112011111120212222404222222404222212021111110211111101000010111111201111112021222220222222220222221202111111021111110100
00101111112011111220121222202222222202222121022111000000000001000010111111201111122012122220222222220222212102211111021111110100
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b0b00000000000000b0b0b000000000000000b0b0b00000000000000000bbbbb00000000000000000000000000000000ffffffff5111111111111111ffffffff
0b0989899899999990b0b00999999999999990b0b0099999999899898000bbbb00000000000000000000000000000000fffffff551111111111111111fffffff
b08888888888888899000099888888888888990000998888888888888800bbbb00000000000000000000000000000000fffffff511111111111111111fffffff
088888888888888889900998888888888888899009988888888888888880bbbb00000000000000000000000000000000ffffff5511111111111111111fffffff
088888888888888888900988888888888888889009888888888888888880bbbb00000000000000000000000000000000fffff55111fffffffeeeee1111ffffff
088888888888888888800888888888888888888008888888888888888880bbbb00000000000000000000000000000000fffff5511f77fffffffffee111ffffff
088888888228888888800888888888888888888008888888888888888810bbbb00000000000000000000000000000000fffff151ff77ffffffffffee11ffffff
088888888118888888800888888888888888888008888888882222222110bbbb00000000000000000000000000000000fffff15fffffffffffffffee15ffffff
088888888008888888800888888882288888888008888888821111111110bbbb00000000000000000000000000000000fffff55fffffffffffffffee15ffffff
088888888008888888800888888881188888888008888888811111111100bbbb00000000000000000000000000000000fffff55fffffffffffffffeed5ffffff
088888888888888888800888888880088888888008888888880000000000bbbb00000000000000000000000000000000fffff5dffdd55dfffd55ddeedfffffff
088888888888888888800888888880088888888008888888888888888000bbbb00000000000000000000000000000000ffffffdf111111fff111111ed4ffffff
088888888888888888100888888880088888888008888888888888888800bbbb00000000000000000000000000000000fffff4d1fff4ff111ff4fff1e4ffffff
088888888888888881000888888888888888888002888888888888888880bbbb00000000000000000000000000000000fffff4f1ff474f1f1f474ff1e4ffffff
088888888888888810000888888888888888888001288888888888888880bbbb00000000000000000000000000000000fffff4f1ffffff1f1ffffff1e4ffffff
088888888888888880000888888888888888888001122222228888888880bbbb00000000000000000000000000000000fffff4ff1111114f4111111ee4ffffff
088888888888888888000888888888888888888001111111112888888880bbbb00000000000000000000000000000000fffff4ffffffff7feffffeee4fffffff
088888888228888888800888888888888888888000111111111888888880bbbb00000000000000000000000000000000fffff4ffffffff4f4ffffeee4fffffff
088888888118888888800888888888888888888000000000008888888880bbbb00000000000000000000000000000000ffffff4ffffff444445feeee4fffffff
088888888008888888800888888888888888888000088888888888888880bbbb00000000000000000000000000000000ffffff4fffff55555554eeee4fffffff
088888888008888888800888888882288888888001888888888888888880bbbb00000000000000000000000000000000ffffff14fff546666445eeee1fffffff
088888888888888888800888888881188888888008888888888888888880bbbb00000000000000000000000000000000fffffff14ffff444444eeee41fffffff
088888888888888888800888888881188888888008888888888888888880bbbb00000000000000000000000000000000fffffff114ffff5555666e41ffffffff
088888888888888888800888888880088888888008888888888888888880bbbb00000000000000000000000000000000fffff440114ffff55f66e411ffffffff
028888888888888888200288888820028888882002888888888888888820bbbb00000000000000000000000000000000fff44000f114ffffff6e4100111fffff
012888888888888882100128888210012888821001288888888888888210bbbb00000000000000000000000000000000fff00000ff114fffff6411000001ffff
011222222222222221100112222110011222211001122222222222222110bbbb00000000000000000000000000000000ff4000004ff1111111111f0000001fff
011111111111111111100111111110001111110001111111111111111110bbbb00000000000000000000000000000000ff40000046fff111111fff00000001ff
001111111111111111000011111100000111100000111111111111111100bbbb00000000000000000000000000000000f400000006fffffffffff000000001ff
b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0bbbb00000000000000000000000000000000f4000000006ffffffffff000000001ff
0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0bbbbb00000000000000000000000000000000ff400000000ffffffff60000000011ff
b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0bbbb000000000000000000000000000000004444000000006ffffff0000000011111
__label__
00202101122222440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004422222110120200
02221201122222440000000000000000001011111120111112201212222022222222022221210221111102111111010000000000000000004422222110212220
00202101122222440000000000000000001011111120111111202122222022222222022222120211111102111111010000000000000000004422222110120200
00000001122222440000000000000000111010000000000000000202000000000000000201010000000000000000011100000000000000004422222110000000
02202121122222440000000000000000000009898998999999900000099999999999999000000999999998998980000000000000000000004422222112120220
22201211122222440000000000000000000088888888888888990000998888888888889900009988888888888888000000000000000000004422222111210222
02202121122222440000000000000000000888888888888888899009988888888888888990099888888888888888800000000000000000004422222112120220
00000001122222440000000000000000110888888888888888889009888888888888888890098888888888888888801100000000000000004422222110000000
00202101122222440000000000000000000888888888888888888008888888888888888880088888888888888888800000000000000000004422222110120200
02221201122222440000000000000000000888888882288888888008888888888888888880088888888888888888100000000000000000004422222110212220
00202101122222440000000000000000000888888881188888888008888888888888888880088888888822222221100000000000000000004422222110120200
00000001122222440000000000000000010888888880088888888008888888822888888880088888888211111111101000000000000000004422222110000000
02202121122222440000000000000000000888888880088888888008888888811888888880088888888111111111000000000000000000004422222112120220
22201211122222440000000000000000010888888888888888888008888888800888888880088888888800000000001000000000000000004422222111210222
02202121122222440000000000000000000888888888888888888008888888800888888880088888888888888880000000000000000000004422222112120220
00000001122222440000000000000000010888888888888888881008888888800888888880088888888888888888001000000000000000004422222110000000
00202101122222440000000000000000000888888888888888810008888888888888888880028888888888888888800000000000000000004422222110120200
02221201122222440000000000000000010888888888888888100008888888888888888880012888888888888888801000000000000000004422222110212220
00202101111111440000000000000000000888888888888888800008888888888888888880011222222288888888800000000000000000004411111110120200
00000001111111140000000000000000000888888888888888880008888888888888888880011111111128888888800000000000000000004111111110000000
02202124444444490000000000000000000888888882288888888008888888888888888880001111111118888888800000000000000000009444444442120220
22201211444444940000000000000000110888888881188888888008888888888888888880000000000088888888801100000000000000004944444411210222
02202121122222440000000000000000000888888880088888888008888888888888888880000888888888888888800000000000000000004422222112120220
00000001122222440000000000000000000888888880088888888008888888822888888880018888888888888888800000000000000000004422222110000000
00202101122222440000000000000000000888888888888888888008888888811888888880088888888888888888800000000000000000004422222110120200
02221201122222440000000000000000110888888888888888888008888888811888888880088888888888888888801100000000000000004422222110212220
00202101122222440000000000000000000888888888888888888008888888800888888880088888888888888888800000000000000000004422222110120200
00000001122222440000000000000000000288888888888888882002888888200288888820028888888888888888200000000000000000004422222110000000
02202121122222440000000000000000000128888888888888821001288882100128888210012888888888888882100000000000000000004422222112120220
22201211122222440000000000000000000112222222222222211001122221100112222110011222222222222221100000000000000000004422222111210222
02202121122222440000000000000000000111111111111111111001111111100011111100011111111111111111100000000000000000004422222112120220
00000001122222440000000000000000010011111111111111110000111111000001111000001111111111111111001110000000000000004422222110000000
00202101122222440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004422222110120200
02221201122222440000000000000000000101010102010101020101020202020202000202020002010100010101001000000000000000004422222110212220
00202101122222440000000000000000000000101010001010100010202000202020202020202020101010201010101000000000000000004422222110120200
00000001122222440000000000000000011101111222011112220121222202222222202222121022211110222111101110000000000000004422222110000000
02202121122222440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004422222112120220
22201211122222440000000000000000000000010111111201112222022222220222222220222211102111111010000000000000000000004422222111210222
02202121122222440000000000000000000000010111111201121222022222220222222220222121102111111010000000000000000000004422222112120220
00000001122222440000000000000000011111110111222201112222022222220222222220222211102222111011111110000000000000004422222110000000
00202101122222440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004422222110120200
02221201122222440000000000000000000101111111011112220121222202222222202222121022211110111111101000000000000000004422222110212220
00202101111111440000000000000000000101111111011111120212222202222822202222212021111110111111101000000000000000004411111110120200
00000001111111140000000000000000001101111111011122220121222202fffff2202222121022221110111111101100000000000000004111111110000000
022021244444444900000000000000000000000000000000000000000000099f1fff000000000000000000000000000000000000000000009444444442120220
222012114444449400070000000000000011101101111222011121220222248ffff4442220221211102221111011011100000000000000004944444411210222
022021211222224400767000000000000000000101111112011212220222ff4fff4fff4220222121102111111010000000000000000000004422222112120220
000000011222224406666600000000000011101101111222011121220222fffff4ffff4420221211102221111011011100000000000000004422222110000000
002021011222224466666660000000000000000000000000000000000000ffffffffff6420000000000000000000000000000000000000004422222110120200
0222120112222244666666666770000000110111111101111222012122224ffffffff6f644521022211110111111101100000000000000004422222110212220
00202101122222446666666666700000000101111111011111120212122204ffffff6e6ed5212021111110111111101000000000000000004422222110120200
0000000112222244666666666660000000010111111101111122012122220246666696ed44521022111110111111101000000000000000004422222110000000
0220212112222244666666666660000000000000000000000000000000000002d96699d555000000000000000000000000000000000000004422222112120220
222012111222224416ddd66666660000011111110111222201112122022222220d9dd944d0221211102222111011111110000000000000004422222111210222
022021211222224411dddd6666666000000000010111111201121222022222220224dd4d40222121102111111010000000000000000000004422222112120220
000000011222224411111dd666666700000000010111111201112122022222220222242240221211102111111010000000000000000000004422222110000000
002021011222224411151dd666666670000000000000000000000000000000000000000000000000000000000000000000000000000000004422222110120200
022212011222224411111dd666666700011101111222011112220121222202222222202222121022211110222111101110000000000000004422222110212220
002021011222224411dddd6666666000000101111112011111120212222202222222202222212021111110211111101000000000000000004422222110120200
000000011222224416ddd66666660000000101111112011111220121222202222222202222121022111110211111101000000000000000004422222110000000
02202121122222446666666666600000000000000000000000000000000000000000000000000000000000000000000000000000000000004422222112120220
22201211122222446666666666600000000000101111112011112220222222202222222202221111021111110100000000000000000000004422222111210222
02202121122222446666666666700000000000101111112011121220222222404222222202212111021111110100000000000000000000004422222112120220
00000001122222446666666667700000111111102222222011112220224449909944422202221111022222220111111110000000000000004422222110000000
00202101122222446666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004422222110120200
02221201122222440666660000000000001011111120111112201212224025444452042221210221111102111111010000000000000000004422222110212220
00202101111111440076700000000000001011111120111111202122229024ffff42092222120211111102111111010000000000000000004411111110120200
0000000111111114000700000000000011101111222011112220121249904ffffff4099421210222111102221111011110000000000000004111111110000000
022021244444444900000000000000000000000000000000000000000004ffffffff400000000000000000000000000000000000000000009444444442120220
222012114444449400000000000000000000001011111120111224902424ffffffff424209422111021111110100000000000000000070004944444411210222
022021211222224400000000000000000000001011111120112122904294ffffffff492409221211021111110100000000000000000767004422222112120220
000000011222224400000000000000001111111011122220111224902424ffffffff424209422111022221110111111110000000006666604422222110000000
002021011222224400000000000000000000000000000000000000000004ffffffff400000000000000000000000000000000000066666664422222110120200
022212011222224400000000000000000010111111101111222012142424ffffffff424241210222111101111111010000000776666666664422222110212220
002021011222224400000000000000000010111111101111112021224294ffffffff492422120211111101111111010000000766666666664422222110120200
000000011222224400000000000000000110111111101112222012142424ffffffff424241210222211101111111011000000666666666664422222110000000
022021211222224400000000000000000000000000000000000000000004ffffffff400000000000000000000000000000000666666666664422222112120220
222012111222224400000000000000000111011011112220111214904294ffffffff492409412111022211110110111000006666666ddd614422222111210222
022021211222224400000000000000000000001011111120112122902424ffffffff42420922121102111111010000000006666666dddd114422222112120220
000000011222224400000000000000000111011011112220111214904294ffffffff4924094121110222111101101110007666666dd111114422222110000000
002021011222224400000000000000000000000000000000000000000004ffffffff4000000000000000000000000000076666666dd151114422222110120200
022212011222224400000000000000000110111111101111222012192424ffffffff4242912102221111011111110110007666666dd111114422222110212220
002021011222224400000000000000000010111111101111112021214294ffffffff49241212021111110111111101000006666666dddd114422222110120200
000000011222224400000000000000000010111111101111122012192424ffffffff424291210221111101111111010000006666666ddd614422222110000000
022021211222224400000000000000000000000000000000000000000004ffffffff400000000000000000000000000000000666666666664422222112120220
222012111222224400000000000000001111111011122220111214904294ffffffff492409412111022221110111111110000666666666664422222111210222
022021211222224400000000000000000000001011111120112122902424ffffffff424209221211021111110100000000000766666666664422222112120220
00000001122222440000000000000000000000101111112011121490429444444444492409412111021111110100000000000776666666664422222110000000
00202101122222440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066666664422222110120200
02221201122222440000000000000000111011112220111122201212499099444499099421210222111102221111011110000000006666604422222110212220
00202101111111440000000000000000001011111120111111202122224042222224042222120211111102111111010000000000000767004411111110120200
00000001111111140000000000000000001011111120111112201212222022222222022221210221110000000000010000000000000070004111111110000000
02202124444444490000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009444444442120220
22201211444444940000000000000000000000101111112011112220222222202222222202221111021111110100000000000000000000004944444411210222
02202121122222440000000000000000000000101111112011121220222222202222222202212111021111110100000000000000000000004422222112120220
00000001122222440000000000000000111111102222222011112220222222202222222202221111022222220111111100000000000000004422222110000000
00202101122222440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004422222110120200
02221201122222440000000000000000001011111120111112201212222022222222022221210221111102111111010000000000000000004422222110212220
00202101122222440000000000000000001011111120111111202122222022222222022222120211111102111111010000000000000000004422222110120200
00000001122222440000000000000000111011112220111122201212222022222222022221210222111102221111011100000000000000004422222110000000
02202121122222440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004422222112120220
22201211122222440000000000000000000000101111112011122220222222202222222202222111021111110100000000000000000000004422222111210222
02202121122222440000000000000000000000101111112011212220222222202222222202221211021111110100000000000000000000004422222112120220
00000001122222440000000000000000111111101112222011122220222222202222222202222111022221110111111100000000000000004422222110000000
00202101122222440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004422222110120200
02221201122222440000000000070000001011111110111122271212222022222222022221270222111101111111010000070000000000004422222110212220
00202101122222440000000000767000001011111110111111767122222022222222022222767211111101111111010000767000000000004422222110120200
00000001122222440000000006666600011011111110111226666612222022222222022226666622211101111111011006666600000000004422222110000000
02202121122222440000000066666660000000000000000066666660000000000000000066666660000000000000000066666660000000004422222112120220
22201211122222440000077666666666771101101111277666666666772222202222277666666666772211110110177666666666770000004422222111210222
02202121122222440000076666666666670000101111176666666666672222202222276666666666671111110100076666666666670000004422222112120220
00000001122222440000066666666666661101101111266666666666662222202222266666666666662211110110166666666666660000004422222110000000
00202101122222440000666666ddd666666000000000666666ddd666666000000000666666ddd666666000000000666666ddd666666000004422222110120200
0222120112222244000666666ddddd6666661111111666666ddddd6666662222222666666ddddd6666660111111666666ddddd66666600004422222110212220
002021011111114400766666dd111dd66666711111766666dd111dd66666722222766666dd111dd66666711111766666dd111dd6666670004411111110120200
000000011111111407666666dd151dd66666671117666666dd151dd66666672227666666dd151dd66666671117666666dd151dd6666667004111111110000000
022021244444444900766666dd111dd66666700000766666dd111dd66666700000766666dd111dd66666700000766666dd111dd6666670009444444442120220
2220121144444494000666666d111d6666661110111666666d111d6666662220222666666d111d6666662111011666666d111d66666600004944444411210222
02202121122222440000666666111666660000101111666666111666662222202222666666111666661111110100666666111666660000004422222112120220
00000001122222440000066661111166660000101111166661111166662222202222266661111166661111110100066661111166660000004422222110000000
00202101122222440044444411111114444444444444444411111114444444444444444411111114444444444444444411111114444444004422222110120200
02221201122222440444444411111114444444444444444411111114444444444444444411111114444444444444444411111114444444404422222110212220
00202101122222441422222444444444222222222222222444444444222222222222222444444444222222222222222444444444222222414422222110120200
00000001122222441222222244444442222222222222222244444442222222222222222244444442222222222222222244444442222222214422222110000000
02202121122222441222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222214422222112120220
22201211122222441221122222211222222112222221122222211222222112222221122222211222222112222221122222211222222112214422222111210222
02202121122222441210012222100122221001222211012222110122221201222212012222120122221101222210012222100122221001214422222112120220
00000001122222441100001221000012211010122120201221101012212020122120201221202012212020122110101221000012210000114422222110000000

__map__
4051000088898a8b8c8d8e8f0000514000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5051000098999a9b9c9d9e9f0000514000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
40510000a8a9aaabacadaeaf0000514000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
50510000b8b9babbbcbdbebf0000514000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4051000080818283848586870000514000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5051000090919293949596970000514000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
40510000a0a1a2a3a4a5a6a70000514000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
50510000b0b1b2b3b4b5b6b70000514000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4051000088898a8b8c8d8e8f0000514000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010e00000c0430c01300003000030000300003000030c0000c0000c000000030000300003000030c0000c0000c0430c01300003000030000300003000030c0000c0000c000000030000300003000030c0000c033
990e00001d7351d715227352271527735277151d7351d715227352271527735277151d7351d71522735227151d7351d715227352271527735277151d7351d715227352271527735277151d7351d7152273522715
c90e00001603216032160321603216032160321603216032160321603216032160321603216032160321603216032160321603216032160321603216032160321603216032160321603216032160321603216032
c90e00000f0320f0320f0320f0320f0320f0320f0320f0320f0320f0320f0320f0320f0320f0320f0320f03211032110321103211032110321103211032110321103211032110321103211032110321103211032
010e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010e00000c0430c0000000000000246150000000000000000c0430c0130c0330000024615000000c0000c0000c0430c01300000000002461500000000000c0330c0430c0000c033000002461500000000000c000
990e00001d73522735277351d73522735277351d73522735277351d73522735277351d73522735277351d7351d73522735277351d73522735277351d73522735277351d73522735277351d73522735277351d735
010e0000000000a0000a050000000a0000a050000000a0000a050000000a0000a050000000a0000a05000000000000a05000000000000a05000000000000a05000000000000a05000000000000a0500000000000
010e00000000000000030500000000000030500000000000030500000000000030500000000000030500000000000050500000000000050500000000000050500000000000050500000000000050500000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
950100000064100641016011760112601156010060100601006010060100601006010060100601006010060100601006010060100601006010060100601006010060100601006010060100601006010060100000
01080000160410500011041110000f041000000a04105000050410a00000043000430004300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010300000560005600000000560005600056000000005600056000560000000056000560005613000000560005613056000000005623056000562300000056230000005623000000561300000056000000005600
000200000405004050050500505006040080400b0300f0301202015020190101d0100060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
00020000000500005001050010500304005040070300a0300c0200e02011010150101605100000000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001
a50500000a5000a50016514165401651011540115100f5400f5100a5400a5150a5000f5000f5000a5000a5000a5000a5000f5000f500115001150016500165001650016500000000000000000000000000000000
0102000019511195111a5111d5111f51123511255112a5002f5012e50133501355010000100001000010000116501165011650111501115010f5010f5010a5010a50100001000010000100001000010000100001
d10100000c6210c6210c6210c6110c6110c6210c6010c6010c6000c6000c6000c6000c6000c6000c6000c6000c6000c6000c6000c6000c6000c6000c6000c6000c6000c6000c6000c6000c6000c6000c6000c600
__music__
01 00010244
02 00010344
01 06070208
02 06070309
01 02424344
02 03424344

