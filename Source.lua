
local Find = gui.get_config_item
local Checkbox = gui.add_checkbox
local Slider = gui.add_slider
local Combo = gui.add_combo
local MultiCombo = gui.add_multi_combo
local AddKeybind = gui.add_keybind
local CPicker = gui.add_colorpicker
local playerstate = 0;
local ConditionalStates = { }
local configs = {}
local pixel = render.font_esp
local calibri11 = render.create_font("calibri.ttf", 11, render.font_flag_outline)
local calibri13 = render.create_font("calibri.ttf", 13, render.font_flag_shadow)
local verdana = render.create_font("verdana.ttf", 13, render.font_flag_outline)
local tahoma = render.create_font("tahoma.ttf", 13, render.font_flag_shadow)
local refs = {
    yawadd = Find("Rage>Anti-Aim>Angles>Yaw add");
    yawaddamount = Find("Rage>Anti-Aim>Angles>Add");
    spin = Find("Rage>Anti-Aim>Angles>Spin");
    jitter = Find("Rage>Anti-Aim>Angles>Jitter");
    spinrange = Find("Rage>Anti-Aim>Angles>Spin range");
    spinspeed = Find("Rage>Anti-Aim>Angles>Spin speed");
    jitterrandom = Find("Rage>Anti-Aim>Angles>Random");
    jitterrange = Find("Rage>Anti-Aim>Angles>Jitter Range");
    desync = Find("Rage>Anti-Aim>Desync>Fake amount");
    compAngle = Find("Rage>Anti-Aim>Desync>Compensate angle");
    freestandFake = Find("Rage>Anti-Aim>Desync>Freestand fake");
    flipJittFake = Find("Rage>Anti-Aim>Desync>Flip fake with jitter");
    leanMenu = Find("Rage>Anti-Aim>Desync>Roll lean");
    leanamount = Find("Rage>Anti-Aim>Desync>Lean amount");
    ensureLean = Find("Rage>Anti-Aim>Desync>Ensure Lean");
    flipJitterRoll = Find("Rage>Anti-Aim>Desync>Flip lean with jitter");
};
local var = {
    player_states = {"Standing", "Moving", "Slow motion", "Air", "Air Duck", "Crouch"};
};
function get_local_speed()
    local local_player = entities.get_entity(engine.get_local_player())
    if local_player == nil then
      return
    end
    local velocity_x = local_player:get_prop("m_vecVelocity[0]")
    local velocity_y = local_player:get_prop("m_vecVelocity[1]")
    local velocity_z = local_player:get_prop("m_vecVelocity[2]")
    local velocity = math.vec3(velocity_x, velocity_y, velocity_z)
    local speed = math.ceil(velocity:length2d())
    if speed < 10 then
        return 0
    else 
        return speed 
    end
end

function accumulate_fps()
    return math.ceil(1 / global_vars.frametime)
end
function get_tickrate()
    if not engine.is_in_game() then return end

    return math.floor( 1.0 / global_vars.interval_per_tick )
end
function get_ping()
    if not engine.is_in_game() then return end

    return math.ceil(utils.get_rtt() * 1000);
end

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function enc(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function dec(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

local function str_to_sub(text, sep)
    local t = {}
    for str in string.gmatch(text, "([^"..sep.."]+)") do
        t[#t + 1] = string.gsub(str, "\n", " ")
    end
    return t
end

local function to_boolean(str)
    if str == "true" or str == "false" then
        return (str == "true")
    else
        return str
    end
end

local function animation(check, name, value, speed) 
    if check then 
        return name + (value - name) * global_vars.frametime * speed / 1.5
    else 
        return name - (value + name) * global_vars.frametime * speed / 1.5
    end
end

function animate(value, cond, max, speed, dynamic, clamp)
    speed = speed * global_vars.frametime * 20
    if dynamic == false then
        if cond then
            value = value + speed
        else
            value = value - speed
        end
    
    else
        if cond then
            value = value + (max - value) * (speed / 100)
        else
            value = value - (0 + value) * (speed / 100)
        end
    end

    if clamp then
        if value > max then
            value = max
        elseif value < 0 then
            value = 0
        end
    end
    return value
end

function drag(var_x, var_y, size_x, size_y)
    local mouse_x, mouse_y = input.get_cursor_pos()

    local drag = false

    if input.is_key_down(0x01) then
        if mouse_x > var_x:get_int() and mouse_y > var_y:get_int() and mouse_x < var_x:get_int() + size_x and mouse_y < var_y:get_int() + size_y then
            drag = true
        end
    else
        drag = false
    end

    if (drag) then
        var_x:set_int(mouse_x - (size_x / 2))
        var_y:set_int(mouse_y - (size_y / 2))
    end
end

print(" _____________________________________ ")
print("| loading...                          |")
print("|_____________________________________|")

local MenuSelection = Combo("Legacy", "lua>tab b", {"Ragubot", "Anti popadalki 2", "Anti popadalki", "Krasivaya huina"})
local DAMain = Checkbox("Dormant Aimbot", "lua>tab b")
local DA = AddKeybind("lua>tab b>Dormant Aimbot")
local FL0 = Checkbox("Better Hideshots", "lua>tab b")
local hstype = Combo("Hideshots Type", "lua>tab b", {"Favor firerate", "Favor fakelag", "Break lagcomp"})
local ragebotlogs = Checkbox("Ragebot logs", "lua>tab b")
ConditionalStates[0] = {
	player_state = Combo("Conditions", "lua>tab b", var.player_states);
}
for i=1, 6 do
	ConditionalStates[i] = {
        yawadd = Checkbox("Yaw add " .. var.player_states[i], "lua>tab b");
        yawaddamount = Slider("Add " .. var.player_states[i], "lua>tab b", -180, 180, 1);
        spin = Checkbox("Spin " .. var.player_states[i], "lua>tab b");
        spinrange = Slider("Spin range " .. var.player_states[i], "lua>tab b", 0, 360, 1);
        spinspeed = Slider("Spin speed " .. var.player_states[i], "lua>tab b", 0, 360, 1);
        jitter = Checkbox("Jitter " .. var.player_states[i], "lua>tab b");
        jittertype = Combo("Jitter Type " .. var.player_states[i], "lua>tab b", {"Center", "Offset", "Random"});
        jitterrange = Slider("Jitter range " .. var.player_states[i], "lua>tab b", 0, 360, 1);
        desynctype = Combo("Desync Type " .. var.player_states[i], "lua>tab b", {"Static", "Jitter", "Random"});
        desync = Slider("Desync " .. var.player_states[i], "lua>tab b", -60, 60, 1);
        compAngle = Slider("Comp " .. var.player_states[i], "lua>tab b", 0, 100, 1);
        flipJittFake = Checkbox("Flip fake " .. var.player_states[i], "lua>tab b");
        leanMenu = Combo("Roll lean " .. var.player_states[i], "lua>tab b", {"sigma", "static", "Extend roll system", "Invert", "Freestandv1", "Freestandv2", "Jitter roll"});
        leanamount = Slider("Lean amount " .. var.player_states[i], "lua>tab b", 0, 50, 1);
    };
end
local StaticFS = Checkbox("Static Freestand", "lua>tab b")
local FF = Checkbox("Fake Flick", "lua>tab b")
local FFK = AddKeybind("lua>tab b>Fake Flick")
local IV = Checkbox("Inverter", "lua>tab b")
local IVK = AddKeybind("lua>tab b>Inverter")
local colormains = Checkbox("Color", "lua>tab b")
local colormain = CPicker("lua>tab b>Color", false)
local indicatorsmain = Combo("Indicators", "lua>tab b", {"None", "Modern","Alternative"})
local watermark, keybinds = MultiCombo("Solus UI", "lua>tab b", {"Watermark","Keybinds list"})
local clantagmain = Checkbox("Clantag", "lua>tab b")

function MenuElements()
    for i=1, 6 do
        local tab = MenuSelection:get_int()
        local state = ConditionalStates[0].player_state:get_int() + 1
        local yawAddCheck = ConditionalStates[i].yawadd:get_bool()
        local spinCheck = ConditionalStates[i].spin:get_bool()
        local jitterCheck = ConditionalStates[i].jitter:get_bool()
        local leanamountCheck = ConditionalStates[i].leanamount:get_int()
        local BH = FL0:get_bool()
        gui.set_visible("lua>tab b>Dormant Aimbot", tab == 0);
        gui.set_visible("lua>tab b>Better Hideshots", tab == 0);
        gui.set_visible("lua>tab b>Hideshots Type", tab == 0 and BH);
        gui.set_visible("lua>tab b>Ragebot logs", tab == 0);
        gui.set_visible("lua>tab b>Conditions", tab == 1);
        gui.set_visible("lua>tab b>Yaw add " .. var.player_states[i], tab == 1 and state == i);
        gui.set_visible("lua>tab b>Add " .. var.player_states[i], tab == 1 and state == i and yawAddCheck);
        gui.set_visible("lua>tab b>Spin " .. var.player_states[i], tab == 1 and state == i);
        gui.set_visible("lua>tab b>Spin range " .. var.player_states[i], tab == 1 and state == i and spinCheck);
        gui.set_visible("lua>tab b>Spin speed " .. var.player_states[i], tab == 1 and state == i and spinCheck);
        gui.set_visible("lua>tab b>Jitter " .. var.player_states[i], tab == 1 and state == i);
        gui.set_visible("lua>tab b>Jitter Type " .. var.player_states[i], tab == 1 and state == i and jitterCheck);
        gui.set_visible("lua>tab b>Jitter range " .. var.player_states[i], tab == 1 and state == i and jitterCheck);
        gui.set_visible("lua>tab b>Desync Type " .. var.player_states[i], tab == 1 and state == i);
        gui.set_visible("lua>tab b>Desync " .. var.player_states[i], tab == 1 and state == i);
        gui.set_visible("lua>tab b>Comp " .. var.player_states[i], tab == 1 and state == i);
        gui.set_visible("lua>tab b>Flip fake " .. var.player_states[i], tab == 1 and state == i);
        gui.set_visible("lua>tab b>Roll lean " .. var.player_states[i], tab == 1 and state == i);
        gui.set_visible("lua>tab b>Lean Amount " .. var.player_states[i], tab == 1 and state == i);
        gui.set_visible("lua>tab b>Static Freestand", tab == 2);
        gui.set_visible("lua>tab b>Fake Flick", tab == 2);
        gui.set_visible("lua>tab b>Inverter", tab == 2);
        gui.set_visible("lua>tab b>Color", tab == 3);
        gui.set_visible("lua>tab b>Indicators", tab == 3);
        gui.set_visible("lua>tab b>Solus UI", tab == 3);
        gui.set_visible("lua>tab b>Clantag", tab == 3);
    end
end
local hs = gui.get_config_item("Rage>Aimbot>Aimbot>Hide shot")
local dt = gui.get_config_item("Rage>Aimbot>Aimbot>Double tap")
local limit = gui.get_config_item("Rage>Anti-Aim>Fakelag>Limit")
local cache = {
  backup = limit:get_int(),
  override = false,
}

function RB()
if FL0:get_bool() then
  if hstype:get_int() == 0 and not dt:get_bool() then
    if hs:get_bool() then
        limit:set_int(1)
        cache.override = true
    else
        if cache.override then
        limit:set_int(cache.backup)
        cache.override = false
        else
        cache.backup = limit:get_int()
        end
      end
    end
  end
  if FL0:get_bool() then
    if hstype:get_int() == 1 and not dt:get_bool() then
      if hs:get_bool() then
          limit:set_int(9)
          cache.override = true
      else
          if cache.override then
          limit:set_int(cache.backup)
          cache.override = false
          else
          cache.backup = limit:get_int()
          end
        end
      end
    end
if FL0:get_bool() then
    if hstype:get_int() == 2 and not dt:get_bool() then
        if hs:get_bool() then
            limit:set_int(global_vars.tickcount % 32 >= 4 and 14 or 1)
            cache.override = true
        else
            if cache.override then
            limit:set_int(cache.backup)
            cache.override = false
            else
            cache.backup = limit:get_int()
            end
        end
    end
end
end
local TargetDormant = Find("rage>aimbot>aimbot>target dormant")
local function DA()
TargetDormant:set_bool(DAMain:get_bool())
    local local_player = entities.get_entity(engine.get_local_player())
    if not engine.is_in_game() or not local_player:is_valid() or not DAMain:get_bool() then
        return
    end
end
function UpdateStateandAA()

    local isSW = info.fatality.in_slowwalk
    local local_player = entities.get_entity(engine.get_local_player())
    local inAir = local_player:get_prop("m_hGroundEntity") == -1
    local vel_x = math.floor(local_player:get_prop("m_vecVelocity[0]"))
    local vel_y = math.floor(local_player:get_prop("m_vecVelocity[1]"))
    local still = math.sqrt(vel_x ^ 2 + vel_y ^ 2) < 5
    local cupic = bit.band(local_player:get_prop("m_fFlags"),bit.lshift(2, 0)) ~= 0
    local flag = local_player:get_prop("m_fFlags")

    playerstate = 0

    if inAir and cupic then
        playerstate = 5
    else
        if inAir then
            playerstate = 4
        else
            if isSW then
                playerstate = 3
            else
                if cupic then
                    playerstate = 6
                else
                    if still and not cupic then
                        playerstate = 1
                    elseif not still then
                        playerstate = 2
                    end
                end
            end
        end
    end
    refs.yawadd:set_bool(ConditionalStates[playerstate].yawadd:get_bool());
    if ConditionalStates[playerstate].jittertype:get_int() == 1 then
        refs.yawaddamount:set_int((ConditionalStates[playerstate].yawaddamount:get_int()) + (global_vars.tickcount % 4 >= 2 and 0 or ConditionalStates[playerstate].jitterrange:get_int()))
    else
        refs.yawaddamount:set_int(ConditionalStates[playerstate].yawaddamount:get_int());
    end
    refs.spin:set_bool(ConditionalStates[playerstate].spin:get_bool());
    refs.jitter:set_bool(ConditionalStates[playerstate].jitter:get_bool());
    refs.spinrange:set_int(ConditionalStates[playerstate].spinrange:get_int());
    refs.spinspeed:set_int(ConditionalStates[playerstate].spinspeed:get_int());
    refs.jitterrandom:set_bool(ConditionalStates[playerstate].jittertype:get_int() == 2);
    if ConditionalStates[playerstate].jittertype:get_int() == 0 or ConditionalStates[playerstate].jittertype:get_int() == 2 then
            refs.jitterrange:set_int(ConditionalStates[playerstate].jitterrange:get_int());
        else
            refs.jitterrange:set_int(0);
        end
    if ConditionalStates[playerstate].desync:get_int() == 60 and ConditionalStates[playerstate].desynctype:get_int() == 0 then
        refs.desync:set_int((ConditionalStates[playerstate].desync:get_int() * 1.666666667) - 2);
        else if ConditionalStates[playerstate].desync:get_int() == -60 and ConditionalStates[playerstate].desynctype:get_int() == 0 then
            refs.desync:set_int((ConditionalStates[playerstate].desync:get_int() * 1.666666667) + 2);
              else if ConditionalStates[playerstate].desynctype:get_int() == 0 then 
                refs.desync:set_int(ConditionalStates[playerstate].desync:get_int() * 1.666666667);
                    else if ConditionalStates[playerstate].desynctype:get_int() == 1 and 0 >= ConditionalStates[playerstate].desync:get_int() then 
                        refs.desync:set_int(global_vars.tickcount % 4 >= 2 and -18 * 1.666666667 or ConditionalStates[playerstate].desync:get_int() * 1.666666667 + 2);
                            else if ConditionalStates[playerstate].desynctype:get_int() == 1 and ConditionalStates[playerstate].desync:get_int() >= 0 then 
                                refs.desync:set_int(global_vars.tickcount % 4 >= 2 and 18 * 1.666666667 or ConditionalStates[playerstate].desync:get_int() * 1.666666667 - 2);
                                    else if ConditionalStates[playerstate].desynctype:get_int() == 2 and ConditionalStates[playerstate].desync:get_int() >= 0 then 
                                        refs.desync:set_int(utils.random_int(0, ConditionalStates[playerstate].desync:get_int() * 1.666666667));
                                            else if ConditionalStates[playerstate].desynctype:get_int() == 2 and ConditionalStates[playerstate].desync:get_int() <= 0 then 
                                                refs.desync:set_int(utils.random_int(ConditionalStates[playerstate].desync:get_int() * 1.666666667, 0));
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
    refs.compAngle:set_int(ConditionalStates[playerstate].compAngle:get_int());
    refs.flipJittFake:set_bool(ConditionalStates[playerstate].flipJittFake:get_bool());
    refs.leanMenu:set_int(ConditionalStates[playerstate].leanMenu:get_int());
    refs.leanamount:set_int(ConditionalStates[playerstate].leanamount:get_int());
end
local AAfreestand = Find("Rage>Anti-Aim>Angles>Freestand")
local add = Find("Rage>Anti-Aim>Angles>Add")
local jitter = Find("Rage>Anti-Aim>Angles>Jitter Range")
local attargets = Find("Rage>Anti-Aim>Angles>At fov target")
local flipfake = Find("Rage>Anti-Aim>Desync>Flip fake with jitter")
local compfreestand = Find("Rage>Anti-Aim>Desync>Compensate Angle")
local fakefreestand = Find("Rage>Anti-Aim>Desync>Fake Amount")
local freestandfake  = Find("Rage>Anti-Aim>Desync>Freestand Fake")
local add_backup = add:get_int()
local jitter_backup = jitter:get_int()
local attargets_backup = attargets:get_bool()
local flipfake_backup = flipfake:get_bool()
local compfreestand_backup = compfreestand:get_int()
local fakefreestand_backup = fakefreestand:get_int()
local freestandfake_backup = freestandfake:get_int()
local restore_aa = false

local function StaticFreestand()
    if AAfreestand:get_bool() and StaticFS:get_bool() then
        add:set_int(0)
        jitter:set_int(0)
        flipfake:set_bool(false)
        compfreestand:set_int(0)
        freestandfake:set_int(0)
        restore_aa = true
    else
        if (restore_aa == true) then
            add:set_int(add_backup)
            jitter:set_int(jitter_backup)
            attargets:set_bool(attargets_backup)
            flipfake:set_bool(flipfake_backup)
            compfreestand:set_int(compfreestand_backup)
            freestandfake:set_int(freestandfake_backup)
            restore_aa = false
        else
            add_backup = add:get_int()
            jitter_backup = jitter:get_int()
            attargets_backup = attargets:get_bool()
            flipfake_backup = flipfake:get_bool()
            compfreestand_backup = compfreestand:get_int()
            freestandfake_backup = freestandfake:get_int()
        end
    end
end
local add = Find("Rage>Anti-Aim>Angles>Add")
local fakeangle = Find("Rage>Anti-Aim>Desync>Fake Amount")
local fakeamount = fakeangle:get_int() >= 0

local function fakeflick()
    if FF:get_bool() then
        if global_vars.tickcount % 19 == 13 and fakeangle:get_int() >= 0 then
            add:set_int(92)
        else
            if global_vars.tickcount % 19 == 13 and 0 >= fakeangle:get_int() then
                add:set_int(-92)
            end
        end 
    end
end

local fakeangle = Find("Rage>Anti-Aim>Desync>Fake Amount")
local function InvertDesync()
    if IV:get_bool() then
        fakeangle:set_int(fakeangle:get_int() * -1)
    end
end

local function WM()
    
    local player = entities.get_entity(engine.get_local_player())
    if player == nil then return end
    if watermark:get_bool() then
    local latency  = math.floor((utils.get_rtt() or 0)*1000)
    local Time = utils.get_time()
    local realtime = string.format("%02d:%02d:%02d", Time.hour, Time.min, Time.sec)
    local watermarkText = ' Legacy[Beta] / Version 1 / ' .. realtime .. ' time / Delay: ' .. latency .. 'ms';
    
        w, h = render.get_text_size(pixel, watermarkText);
        local watermarkWidth = w;
        x, y = render.get_screen_size();
        x, y = x - watermarkWidth - 5, y * 0.010;
    
        render.rect_filled_rounded(x - 4, y - 3, x + watermarkWidth + 2, y + h + 2.5, colormain:get_color(), 6, render.all);
        render.rect_filled_rounded(x - 2, y - 1, x + watermarkWidth, y + h , render.color(24, 24, 26, 255), 4, render.all);
        render.text(pixel, x - 2.5, y + 2, watermarkText, render.color(255, 255, 255));
    end
end
local screen_size = {render.get_screen_size()}
local keybindsx = Slider("keybindsx", "lua>tab a", 0, screen_size[1], 1)
local keybindsy = Slider("keybindsy", "lua>tab a", 0, screen_size[2], 1)
gui.set_visible("lua>tab a>keybindsx", false)
gui.set_visible("lua>tab a>keybindsy", false)

local function KB()

if keybinds:get_bool() then

local lp = entities.get_entity(engine.get_local_player())
if not lp then return end
if not lp:is_alive() then return end

if not engine.is_in_game() then return end

    local pos = {keybindsx:get_int(), keybindsy:get_int()}

    local size_offset = 0

    local binds =
    {
        Find("lua>tab b>Dormant Aimbot"):get_bool(),
        Find("rage>aimbot>aimbot>double tap"):get_bool(),
        Find("rage>aimbot>aimbot>hide shot"):get_bool(),
        Find("rage>aimbot>ssg08>scout>override"):get_bool(),
        Find("rage>aimbot>aimbot>force extra safety"):get_bool(),
        Find("rage>aimbot>aimbot>headshot only"):get_bool(),
        Find("misc>movement>fake duck"):get_bool(),
        Find("rage>anti-aim>angles>freestand"):get_bool(),
        Find("lua>tab b>Fake Flick"):get_bool(),
        Find("lua>tab b>Inverter"):get_bool(),
    }

    local binds_name = 
    {
        "Dormant Aimbot",
        "Double tap",
        "On Shot anti-aim",
        "Damage override",
        "Force safepoint",
        "Headshot only",
        "Duck peek assist",
        "Freestanding",
        "Fake flick",
        "Inverter"
    }


    size_offset = 80

    animated_size_offset = animate(animated_size_offset or 0, true, size_offset, 60, true, false)

    local size = {75 + animated_size_offset, 22}

    local enabled = "[toggled]"
    local text_size = render.get_text_size(pixel, enabled) + 7

    local override_active = binds[1] or binds[2] or binds[3] or binds[4] or binds[5] or binds[6] or binds[7] or binds[8] or binds[9] or binds[10] or binds[11] or binds[12]

    drag(keybindsx, keybindsy, size[1] + 15, size[2] + 15)

    render.push_clip_rect(pos[1], pos[2], pos[1] + size[1], pos[2] + 20)
    render.rect_filled_rounded(pos[1], pos[2], pos[1] + size[1], pos[2] + size[2], render.color(colormain:get_color().r,colormain:get_color().g,colormain:get_color().b, 255), 8, render.all)
    render.pop_clip_rect()

    render.push_clip_rect(pos[1], pos[2] + 17, pos[1] + size[1], pos[2] + 20)
    render.rect_filled_rounded(pos[1], pos[2], pos[1] + size[1], pos[2] + 20, render.color(colormain:get_color().r,colormain:get_color().g,colormain:get_color().b, 255), 8)
    render.pop_clip_rect()

    render.rect_filled_rounded(pos[1] + 2, pos[2] + 2, pos[1] + size[1] - 2, pos[2] + 18, render.color(24, 24, 26, 255), 6)
    render.text(pixel, pos[1] + size[1] / 2 - render.get_text_size(pixel, "keybinds") / 2 - 1, pos[2] + 6, "keybinds", render.color(255, 255, 255, 255))
    local bind_offset = 0
    if binds[1] then
    render.text(tahoma, pos[1] + 6, pos[2] + size[2] + 2, binds_name[1], render.color(255, 255, 255, 255))
    render.text(tahoma, pos[1] + size[1] - text_size, pos[2] + size[2] + 2, enabled, render.color(255, 255, 255, 255))
    bind_offset = bind_offset + 15
    end

    if binds[2] then
    render.text(tahoma, pos[1] + 6, pos[2] + size[2] + 2 + bind_offset, binds_name[2], render.color(255, 255, 255, 255))
    render.text(tahoma, pos[1] + size[1] - text_size, pos[2] + size[2] + 2 + bind_offset, enabled, render.color(255, 255, 255, 255))
    bind_offset = bind_offset + 15
    end

    if binds[3] then
    render.text(tahoma, pos[1] + 6, pos[2] + size[2] + 2 + bind_offset, binds_name[3], render.color(255, 255, 255, 255))
    render.text(tahoma, pos[1] + size[1] - text_size, pos[2] + size[2] + 2 + bind_offset, enabled, render.color(255, 255, 255, 255))
    bind_offset = bind_offset + 15
    end
 
    if binds[4] then
    render.text(tahoma, pos[1] + 6, pos[2] + size[2] + 2 + bind_offset, binds_name[4], render.color(255, 255, 255, 255))
    render.text(tahoma, pos[1] + size[1] - text_size, pos[2] + size[2] + 2 + bind_offset, enabled, render.color(255, 255, 255, 255))
    bind_offset = bind_offset + 15
    end

    if binds[5] then
    render.text(tahoma, pos[1] + 6, pos[2] + size[2] + 2 + bind_offset, binds_name[5], render.color(255, 255, 255, 255))
    render.text(tahoma, pos[1] + size[1] - text_size, pos[2] + size[2] + 2 + bind_offset, enabled, render.color(255, 255, 255, 255))
    bind_offset = bind_offset + 15
    end

    if binds[6] then
    render.text(tahoma, pos[1] + 6, pos[2] + size[2] + 2 + bind_offset, binds_name[6], render.color(255, 255, 255, 255))
    render.text(tahoma, pos[1] + size[1] - text_size, pos[2] + size[2] + 2 + bind_offset, enabled, render.color(255, 255, 255, 255))
    bind_offset = bind_offset + 15
    end

    if binds[7] then
    render.text(tahoma, pos[1] + 6, pos[2] + size[2] + 2 + bind_offset, binds_name[7], render.color(255, 255, 255, 255))
    render.text(tahoma, pos[1] + size[1] - text_size, pos[2] + size[2] + 2 + bind_offset, enabled, render.color(255, 255, 255, 255))
    bind_offset = bind_offset + 15
    end

    if binds[8] then
    render.text(tahoma, pos[1] + 6, pos[2] + size[2] + 2 + bind_offset, binds_name[8], render.color(255, 255, 255, 255))
    render.text(tahoma, pos[1] + size[1] - text_size, pos[2] + size[2] + 2 + bind_offset, enabled, render.color(255, 255, 255, 255))
    bind_offset = bind_offset + 15
    end

    if binds[9] then
    render.text(tahoma, pos[1] + 6, pos[2] + size[2] + 2 + bind_offset, binds_name[9], render.color(255, 255, 255, 255))
    render.text(tahoma, pos[1] + size[1] - text_size, pos[2] + size[2] + 2 + bind_offset, enabled, render.color(255, 255, 255, 255))
    bind_offset = bind_offset + 15
    end

    if binds[10] then
    render.text(tahoma, pos[1] + 6, pos[2] + size[2] + 2 + bind_offset, binds_name[10], render.color(255, 255, 255, 255))
    render.text(tahoma, pos[1] + size[1] - text_size, pos[2] + size[2] + 2 + bind_offset, enabled, render.color(255, 255, 255, 255))
    bind_offset = bind_offset + 15
    end
end
end
local offset_scope = 0
function ID()
local lp = entities.get_entity(engine.get_local_player())
if not lp then return end
if not lp:is_alive() then return end
local scoped = lp:get_prop("m_bIsScoped")
offset_scope = animation(scoped, offset_scope, 25, 10)

local function Clamp(Value, Min, Max)
    return Value < Min and Min or (Value > Max and Max or Value)
end

if indicatorsmain:get_int() == 1 then
    
    local alpha2 = math.floor(math.abs(math.sin(global_vars.realtime) * 2) * 255)
    local lp = entities.get_entity(engine.get_local_player())
    if not lp then return end
    if not lp:is_alive() then return end
    local screen_width, screen_height = render.get_screen_size( )
    local x = screen_width / 2
    local y = screen_height / 2
    local ay = 0

    local RAGE = Find("rage>aimbot>aimbot>aimbot"):get_bool()
    local is_dt = Find("rage>aimbot>aimbot>double tap"):get_bool()
    local is_hs = Find("rage>aimbot>aimbot>hide shot"):get_bool()
    local DMG = Find("rage>aimbot>ssg08>scout>override"):get_bool()
    local SP = Find("rage>aimbot>aimbot>force extra safety"):get_bool()
    local FS = Find("rage>anti-aim>angles>freestand"):get_bool()
    local text =  "Legacy"
    local text2 = "Beta"
    local text3 = "DT"
    local text4 = "mindamage"
    local text5 = "FS"
    local text6 = "SP"
    local text7 = "huina"

    local textx, texty = render.get_text_size(pixel, text)
    local text2x, text2y = render.get_text_size(pixel, text2)
    local text3x, text3y = render.get_text_size(pixel, text3)
    local text4x, text4y = render.get_text_size(pixel, text4)
    local text5x, text5y = render.get_text_size(pixel, text5)
    local text6x, text6y = render.get_text_size(pixel, text6)
    local text7x, text7y = render.get_text_size(pixel, text7)
    local StateIndicator = "STAND"
    local StateIndicator1 = "MOVE"
    local StateIndicator2 = "SLOW"
    local StateIndicator3 = "AIR"
    local StateIndicator4 = "AIR+"
    local StateIndicator5 = "CROUCH"

    local StateIndicatorx, StateIndicatory = render.get_text_size(pixel, StateIndicator)
    local StateIndicator1x, StateIndicator1y = render.get_text_size(pixel, StateIndicator1)
    local StateIndicator2x, StateIndicator2y = render.get_text_size(pixel, StateIndicator2)
    local StateIndicator3x, StateIndicator3y = render.get_text_size(pixel, StateIndicator3)
    local StateIndicator4x, StateIndicator4y = render.get_text_size(pixel, StateIndicator4)
    local StateIndicator5x, StateIndicator5y = render.get_text_size(pixel, StateIndicator5)

        render.text(pixel, x+offset_scope+2, y + 10, text, render.color(255,255, 255, 255))
        render.text(pixel, x+offset_scope + 42, y + 8, text2, render.color(colormain:get_color().r, colormain:get_color().g, colormain:get_color().b, alpha2))

    if playerstate == 1 and not scoped then
        render.text(pixel, x+offset_scope + 7, y + 20, StateIndicator, colormain:get_color())
    else
        if playerstate == 2 and not scoped then
            render.text(pixel, x+offset_scope + 8, y + 20, StateIndicator1, colormain:get_color())
        else
            if playerstate == 3 and not scoped then
                render.text(pixel, x+offset_scope + 7, y + 20, StateIndicator2, colormain:get_color())
            else
                if playerstate == 4 and not scoped then
                    render.text(pixel, x+offset_scope + 14, y + 20, StateIndicator3, colormain:get_color())
                else
                    if playerstate == 5 and not scoped then
                        render.text(pixel, x+offset_scope + 12, y + 20, StateIndicator4, colormain:get_color())
                    else
                        if playerstate == 6 and not scoped then
                            render.text(pixel, x+offset_scope + 8, y + 20, StateIndicator5, colormain:get_color())
                        else
                            if playerstate == 1 and scoped then
                                render.text(pixel, x+offset_scope, y + 20, StateIndicator, colormain:get_color())
                            else
                                if playerstate == 2 and scoped then
                                    render.text(pixel, x+offset_scope, y + 20, StateIndicator1, colormain:get_color())
                                else
                                    if playerstate == 3 and scoped then
                                        render.text(pixel, x+offset_scope, y + 20, StateIndicator2, colormain:get_color())
                                    else
                                        if playerstate == 4 and scoped then
                                            render.text(pixel, x+offset_scope, y + 20, StateIndicator3, colormain:get_color())
                                        else
                                            if playerstate == 5 and scoped then
                                                render.text(pixel, x+offset_scope, y + 20, StateIndicator4, colormain:get_color())
                                            else
                                                if playerstate == 6 and scoped then
                                                    render.text(pixel, x+offset_scope, y + 20, StateIndicator5, colormain:get_color())
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if is_dt and info.fatality.can_fastfire and not scoped then
        render.text(pixel, x+offset_scope + 16, y + 30+ay, text3, render.color(75, 255, 75, 255))
        ay = ay + 10
    else if is_dt and not info.fatality.can_fastfire and not scoped then
            render.text(pixel, x+offset_scope + 16, y + 30+ay, text3, render.color(255, 0, 0, 185))
            ay = ay + 10
    else if is_dt and info.fatality.can_fastfire and scoped then
        render.text(pixel, x+offset_scope, y + 30+ay, text3, render.color(75, 255, 75, 255))
        ay = ay + 10
    else
        if is_dt and not info.fatality.can_fastfire and scoped then
            render.text(pixel, x+offset_scope, y + 30+ay, text3, render.color(255, 0, 0, 185))
            ay = ay + 10
        end
        end
    end
end

    if is_hs then
            render.text(pixel, x+offset_scope + 18, y + 30+ay, text7, render.color(255,255, 255, 255))
        else
            render.text(pixel, x+offset_scope + 18, y + 30+ay, text7, render.color(255,255, 255, 128))
        end
    if DMG then
            render.text(pixel, x+offset_scope, y + 30+ay, text4, render.color(255,255, 255, 255))
        else
            render.text(pixel, x+offset_scope, y + 30+ay, text4, render.color(255,255, 255, 128))
        end

    if FS then
            render.text(pixel, x+offset_scope + 30, y + 30+ay, text5, render.color(255,255, 255, 255))
        else
            render.text(pixel, x+offset_scope + 30, y + 30+ay, text5, render.color(255,255, 255, 128))
        end

    if SP then
            render.text(pixel, x+offset_scope + 42, y + 30+ay, text6, render.color(255,255, 255, 255))
        else
            render.text(pixel, x+offset_scope + 42, y + 30+ay, text6, render.color(255,255, 255, 128))
        end
    end

if indicatorsmain:get_int() == 2 then
    
    local alpha2 = math.floor(math.abs(math.sin(global_vars.realtime) * 2) * 255)
    local lp = entities.get_entity(engine.get_local_player())
    if not lp then return end
    if not lp:is_alive() then return end
    local local_player = entities.get_entity(engine.get_local_player())
    local ay = 0
    local desync_percentage = Clamp(math.abs(local_player:get_prop("m_flPoseParameter", 11) * 120 - 60.5), 0.5 / 60, 60) / 56
    local w, h = 35, 3
    local screen_width, screen_height = render.get_screen_size( )
    local x = screen_width / 2
    local y = screen_height / 2
    local color1 = render.color(colormain:get_color().r, colormain:get_color().g, colormain:get_color().b, 255)
    local color2 = render.color(colormain:get_color().r - 70, colormain:get_color().g - 90, colormain:get_color().b - 70, 185)

    local text =  "AA.lua"
    local textx, texty = render.get_text_size(pixel, text)

    render.text(pixel, x+offset_scope + 5, y + 10, text, render.color(colormain:get_color().r, colormain:get_color().g, colormain:get_color().b, 255))

    render.rect_filled(x + 4 +offset_scope, y + 21, x+offset_scope + w + 5, y + 22 + h + 1, render.color("#000000"))
    render.rect_filled_multicolor(x+offset_scope + 5, y + 22, x+offset_scope + 2 + w * desync_percentage, y + 22 + h, color1, color2, color2, color1)
end
end
local old_time = 0;
local animation = {
    "N",
    "NE",
    "NEV",
    "NEVE",
    "NEVER",
    "NEVERL",
    "NEVERLO",
    "NEVERLOS",
    "NEVERLOSE",
}
local function CT()
    if clantagmain:get_bool() then
        local defaultct = Find("misc>various>clan tag")
        local realtime = math.floor((global_vars.realtime) * 1.725)
        if old_time ~= realtime then
            utils.set_clan_tag(animation[realtime % #animation+1]);
        old_time = realtime;
        defaultct:set_bool(false);
        end
    end
end
local function main(shot)
if shot.manual then return end
    local hitgroup_names = {"generic", "head", "chest", "stomach", "left arm", "right arm", "left leg", "right leg", "neck", "?", "gear"}
    local p = entities.get_entity(shot.target)
    local n = p:get_player_info()
    local hitgroup = shot.server_hitgroup
    local clienthitgroup = shot.client_hitgroup
    local health = p:get_prop("m_iHealth")

        if ragebotlogs:get_bool() then
            if shot.server_damage > 0 then
                print( "[Legacy Beta] Hurt " , n.name  , "'s ", hitgroup_names[hitgroup + 1]," for " , shot.server_damage, " damage [hc=", math.floor(shot.hitchance), ", bt=", math.floor(shot.backtrack),"]")
            else
                print( "[Legacy Beta] Missed " , n.name  , "'s ", hitgroup_names[shot.client_hitgroup + 1]," due to ", shot.result)
            end
        end
end
function on_shutdown()
    utils.set_clan_tag("");
end
function on_shot_registered(shot)
    main(shot)
end
function on_create_move()
    UpdateStateandAA()
    StaticFreestand()
    fakeflick()
    InvertDesync()
end
function on_paint()
    MenuElements()
    RB()
    DA()
    WM()
    KB()
    ID()
    CT()
end