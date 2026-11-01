-- hold-to-speedup.lua
-- Temporarily increases playback speed to 2x while the Spacebar is held down.
-- Releasing the Spacebar immediately reverts playback back to the previous speed.
-- Tapping the Spacebar quickly acts as standard pause / play toggle (YouTube-like behavior).
-- Compatible with mpv and Celluloid.

local speed_multiplier = 2.0
local hold_threshold = 0.5
local is_speeding = false
local was_paused = false
local timer = nil
local pre_hold_speed = 1.0

local function speed_on()
    is_speeding = true
    pre_hold_speed = mp.get_property_number("speed", 1.0)
    was_paused = mp.get_property_bool("pause", false)

    if was_paused then
        mp.set_property_bool("pause", false)
    end

    mp.set_property("speed", speed_multiplier)
    mp.set_osd_ass(0, 0, "▶▶ " .. speed_multiplier .. "x faster")
end

local function speed_off()
    mp.set_property("speed", pre_hold_speed)
    mp.set_osd_ass(0, 0, "")
    mp.osd_message("", 0)
    mp.osd_message("▶", 1)

    if was_paused then
        mp.set_property_bool("pause", true)
    end

    is_speeding = false
end

local function handle_space(event)
    if event.event == "down" then
        if timer then
            timer:kill()
        end
        timer = mp.add_timeout(hold_threshold, speed_on)
    elseif event.event == "up" then
        if timer then
            timer:kill()
            timer = nil
        end
        if is_speeding then
            speed_off()
        else
            mp.command("cycle pause")
        end
    end
end

mp.add_forced_key_binding("space", "speed_space", handle_space, {complex = true})

