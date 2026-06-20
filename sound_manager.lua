local sound_manager = {}

sound_manager.timer = 0

-- configuration Constants
local MAX_CONCURRENT_SOUNDS = 5
local THROTTLE_TIME = 0.1

local active_sound_count = 0
local last_played_times = {} -- Tracks when EACH sound was last played

-- pre-allocate the properties table
local play_props = { pan = 0 }

-- cache API function to speed up execution
local sound_play = sound.play


function sound_manager.play_sound(hash_url)

	-- convert the URL/Hash to a string for reliable indexing.
	local sound_key = tostring(hash_url)

	-- per-sound throttling
	local last_played = last_played_times[sound_key]
	
	if last_played and (sound_manager.timer - last_played) < THROTTLE_TIME then
		pprint("sound dropped",hash_url)
		return
	end

	-- concurrency limit
	if active_sound_count >= MAX_CONCURRENT_SOUNDS then
		pprint("too many sounds")
		return
	end

	play_props.pan = 0
	
	-- register sound execution
	last_played_times[sound_key] = sound_manager.timer
	active_sound_count = active_sound_count + 1

	-- play Sound and handle voice tracking via the callback
	sound_play(hash_url, play_props, function() 
		-- This safely frees up the slot once the sound finishes playing
		active_sound_count = active_sound_count - 1 
	end)			
end

function sound_manager.updatetimer(dt)
	sound_manager.timer = sound_manager.timer + dt
end

-- return the class
return sound_manager