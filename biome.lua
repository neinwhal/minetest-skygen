-- Functions related to the biome mode

skygen.previous_biome = {}

skygen.transition_frames = 16

skygen.set_sky = function(player, biome_name)
    local base_values = {}
    if skygen.event == "none" then
        base_values = skygen.biomes[biome_name].colors
    else
        base_values = skygen.biomes[biome_name].event_colors
    end
    player:set_sky({
        type = "regular",
        sky_color = {
            day_sky         = {r = base_values[1][1],   g = base_values[1][2],  b = base_values[1][3]},
            day_horizon     = {r = base_values[2][1],   g = base_values[2][2],  b = base_values[2][3]},
            dawn_sky        = {r = base_values[5][1],   g = base_values[5][2],  b = base_values[5][3]}, -- base_values[5] to base_values[8] are calculated
            dawn_horizon    = {r = base_values[6][1],   g = base_values[6][2],  b = base_values[6][3]},
            night_sky       = {r = base_values[7][1],   g = base_values[7][2],  b = base_values[7][3]},
            night_horizon   = {r = base_values[8][1],   g = base_values[8][2],  b = base_values[8][3]},
            indoors         = {r = 128,                 g = 128,                b = 128}, -- Don't see much point in changing this
            fog_sun_tint    = {r = base_values[3][1],   g = base_values[3][2],  b = base_values[3][3]},
            fog_moon_tint   = {r = base_values[4][1],   g = base_values[4][2],  b = base_values[4][3]},
            fog_tint_type = "custom"
        }
    })
end

skygen.init_transition = function(player, prev_biome_name, biome_name)
    skygen.sky_state[player:get_player_name()] = "transition"
    local base_colors = {}
    if skygen.event == "none" then
        base_colors[1] = skygen.biomes[prev_biome_name].colors[3] -- Sun tint
        base_colors[2] = skygen.biomes[prev_biome_name].colors[4] -- Moon tint
    else
        base_colors[1] = skygen.biomes[prev_biome_name].event_colors[3] -- Sun tint
        base_colors[2] = skygen.biomes[prev_biome_name].event_colors[4] -- Moon tint
    end
    local base_params = {}
    base_params[1] = minetest.registered_biomes[prev_biome_name].heat_point
    base_params[2] = minetest.registered_biomes[prev_biome_name].humidity_point
    local color_diffs = skygen.get_color_diffs(prev_biome_name, biome_name)
    local param_diffs = skygen.get_param_diffs(prev_biome_name, biome_name)
    skygen.transition(player, base_colors, base_params, color_diffs, param_diffs, 0, biome_name)
end

skygen.transition = function(player, base_colors, base_params, color_diffs, param_diffs, progress, biome)
    if progress == skygen.transition_frames then
        skygen.sky_state[player:get_player_name()] = "biome"
        skygen.previous_biome[player:get_player_name()] = biome
    else
        progress = progress + 1
        base_params[1] = base_params[1] + param_diffs[1]
        base_params[2] = base_params[2] + param_diffs[2]
        local heat = base_params[1]*2.55 -- 0 ... 255
        local humidity = base_params[2]/100 -- 0 ... 1
        for k=1,2 do
            for i=1,3 do
                base_colors[k][i] = base_colors[k][i] + color_diffs[k][i]
            end
        end
        local sun = base_colors[1]
        local moon = base_colors[2]
        local cloud_color = {}
        if skygen.event == "none" then    
            cloud_color = {r = 255, g =  255, b =  255, a = 255 * humidity}
        else
            local colorset = skygen.event_data[skygen.event].color_cloud
            cloud_color = {r = colorset[1], g = colorset[2], b = colorset[3], a = 255 * humidity}
        end
        player:set_clouds({
            density = humidity/1.5,
            color = cloud_color,
            thickness = humidity * 80
        })
        local sun_texture
        local moon_texture
        if skygen.event ~= "none" then
            sun_texture = skygen.event_data[skygen.event].sun_texture
            moon_texture = skygen.event_data[skygen.event].moon_texture
        else
            sun_texture = "sun.png"
            moon_texture = "moon.png"
        end
        player:set_sun({
            texture = sun_texture,
            scale = ((heat/255) + 0.1)*2,
        })
        player:set_moon({
            texture = moon_texture,
            scale = ((heat/255) + 0.1)*4,
        })
        if skygen.colorize_stars == true then
            player:set_stars({
                star_color = {r = sun[1], g = sun[2], b = sun[3]},
                count = (1.5 - humidity) * 4 * 10
            })
        else
            player:set_stars({
                count = (1.5 - humidity) * 4 * 10
            })
        end
        minetest.after(1 / skygen.transition_frames, function()
            skygen.transition(player, base_colors, base_params, color_diffs, param_diffs, progress, biome)
        end)
    end
end

skygen.colorize = function(color, colorizer, amount)
    local result = {}
    local difference = 0
    for i=1,3 do
        difference = colorizer[i] - color[i]
        result[i] = color[i] + (difference * amount)
    end
    return result
end

skygen.set_all = function(player, biome_name) -- For initial case
    if skygen.event == "none" then
        sun = skygen.biomes[biome_name].colors[3] -- Sun tint
        moon = skygen.biomes[biome_name].colors[4] -- Moon tint
    else
        sun = skygen.biomes[biome_name].event_colors[3] -- Sun tint
        moon = skygen.biomes[biome_name].event_colors[4] -- Moon tint
    end
    heat = minetest.registered_biomes[biome_name].heat_point*2.55
    humidity = minetest.registered_biomes[biome_name].humidity_point/100
    local cloud_color = {}
    if skygen.event == "none" then    
        cloud_color = {r = 255, g =  255, b =  255, a = 255 * humidity}
    else
        local colorset = skygen.event_data[skygen.event].color_cloud
        cloud_color = {r = colorset[1], g = colorset[2], b = colorset[3], a = 255 * humidity}
    end
    player:set_clouds({
        density = humidity/1.5,
        color = cloud_color,
        thickness = humidity * 80
    })
    local sun_texture
    local moon_texture
    if skygen.event ~= "none" then
        sun_texture = skygen.event_data[skygen.event].sun_texture
        moon_texture = skygen.event_data[skygen.event].moon_texture
    else
        sun_texture = "sun.png"
        moon_texture = "moon.png"
    end
    player:set_sun({
        texture = sun_texture,
        scale = ((heat/255) + 0.1)*2,
    })
    player:set_moon({
        texture = moon_texture,
        scale = ((heat/255) + 0.1)*4,
    })
    if skygen.colorize_stars == true then
        player:set_stars({
            star_color = {r = sun[1], g = sun[2], b = sun[3]},
            count = (1.5 - humidity) * 4 * 10
        })
    else
        player:set_stars()
    end
end

skygen.set_clouds = function(player, biome_name) -- Cause minetest sets them to default every now and then
    local heat = minetest.registered_biomes[biome_name].heat_point*2.55
    local humidity = minetest.registered_biomes[biome_name].humidity_point/100
    local cloud_color = {}
    if skygen.event == "none" then    
        cloud_color = {r = 255, g =  255, b =  255, a = 255 * humidity}
    else
        local colorset = skygen.event_data[skygen.event].color_cloud
        cloud_color = {r = colorset[1], g = colorset[2], b = colorset[3], a = 255 * humidity}
    end
    player:set_clouds({
        density = humidity/1.5,
        color = cloud_color,
        thickness = humidity * 80
    })
end

skygen.get_param_diffs = function(prev_biome_name, biome_name)
    local prev_heat = minetest.registered_biomes[prev_biome_name].heat_point
    local prev_humidity = minetest.registered_biomes[prev_biome_name].humidity_point
    local heat = minetest.registered_biomes[biome_name].heat_point
    local humidity = minetest.registered_biomes[biome_name].humidity_point
    local results = {}
    results[1] = (heat - prev_heat) / skygen.transition_frames
    results[2] = (humidity - prev_humidity) / skygen.transition_frames
    return results
end

skygen.get_color_diffs = function(prev_biome_name, biome_name)
    local prev_colorset = {}
    local colorset = {}
    if skygen.event == "none" then
        prev_colorset[1] = skygen.biomes[prev_biome_name].colors[3] -- Sun tint
        prev_colorset[2] = skygen.biomes[prev_biome_name].colors[4] -- Moon tint
        colorset[1] = skygen.biomes[biome_name].colors[3] -- Sun tint
        colorset[2] = skygen.biomes[biome_name].colors[4] -- Moon tint
    else
        prev_colorset[1] = skygen.biomes[prev_biome_name].event_colors[3] -- Sun tint
        prev_colorset[2] = skygen.biomes[prev_biome_name].event_colors[4] -- Moon tint
        colorset[1] = skygen.biomes[biome_name].event_colors[3] -- Sun tint
        colorset[2] = skygen.biomes[biome_name].event_colors[4] -- Moon tint
    end
    local result = {{}, {}}
    for k=1,2 do
        for i=1,3 do
            result[k][i] = (colorset[k][i] - prev_colorset[k][i]) / skygen.transition_frames
        end
    end
    return result
end

skygen.fetch_biome = function(player)
    local player_pos = player:get_pos()
    local biome_data = minetest.get_biome_data(player_pos)
    local biome = minetest.get_biome_name(biome_data.biome)
    local heat = biome_data.heat*2.55 -- 0 ... 255
    local humidity = biome_data.humidity/100 -- 0 ... 1
    local values = {}
    values[1] = biome
    values[2] = heat
    values[3] = humidity
    return values
end