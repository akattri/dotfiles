local mp = require 'mp'

local hold_threshold = 0.2
local timer = nil
local active = false

function toggle_speed(hold)
    if hold then
        mp.set_property("speed", 2.0)
        mp.osd_message(">> 2.0x", 1)
        active = true
    else
        mp.set_property("speed", 1.0)
        mp.osd_message("> 1.0x", 1)
        active = false
    end
end

function handle_key(event)
    if event.event == "down" then
        -- Start a timer to see if this is a hold
        timer = mp.add_timeout(hold_threshold, function() toggle_speed(true) end)
    elseif event.event == "up" then
        if timer then
            timer:stop()
            if active then
                toggle_speed(false)
            else
                mp.command("cycle pause")
            end
            timer = nil
        end
    end
end

-- Using MBTN_MID or a different key as a test if SPACE is still blocked
-- But for now, let's stick to 'space' with the 'forced' flag
mp.add_forced_key_binding("space", "yt_style_speed", handle_key, {complex = true})
