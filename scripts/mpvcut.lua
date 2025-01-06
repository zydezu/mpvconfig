--[[
    mpvcut.lua by zydezu
	(https://github.com/zydezu/mpvconfig/blob/main/scripts/mpvcut.lua)
	
	* Based on https://github.com/familyfriendlymikey/mpv-cut/blob/main/main.lua

    Clip, compress and re-encode selected clips
--]]

utils = require "mp.utils"
msg = require "mp.msg"

local o = {
	-- Save location
	save_to_directory = true, 				-- save to 'save_directory' instead of the current folder
	save_directory = "~~desktop/mpv/clips", -- required for web videos

	-- Key config
	key_cut = "z",
	key_cancel_cut = "Z",
	key_cycle_action = "a",

	-- The default action
	action = "COPY",

	-- File size targets
	compress_size = 9.50,					-- target size for the compress action (in MB)
	resolution = 720, 						-- target resolution to compress to (vertical resolution)

	-- Web videos/cache
	use_cache_for_web_videos = true,
}
(require "mp.options").read_options(o)

local function print(s)
	mp.msg.info(s)
	mp.osd_message(s)
end

local function is_url(s)
    local url_pattern = "^[%w]+://[%w%.%-_]+%.[%a]+[-%w%.%-%_/?&=]*"
    return string.match(s, url_pattern) ~= nil
end

local result = mp.command_native({ name = "subprocess", args = {"ffmpeg"}, playback_only = false, capture_stdout = true, capture_stderr = true })
if result.status ~= 1 then
	mp.osd_message("FFmpeg failed to run")
end

local full_path = mp.command_native({"expand-path", o.save_directory})
local full_path_save = ""
local web_ext = ".mkv"

local average_bitrate = -1
local avg_count = 1

local function get_bitrate()
	local video_bitrate = mp.get_property_number("video-bitrate")
	if video_bitrate then
		video_bitrate = video_bitrate / 1000
		avg_count = avg_count + 1
		if average_bitrate == -1 then
			average_bitrate = video_bitrate
		else
			average_bitrate = ((avg_count-1) * average_bitrate + video_bitrate) / avg_count
		end
	end
end

local function init()
	-- Set save directory path
	if full_path then
		full_path_save = mp.command_native({"expand-path", o.save_directory .. "/" .. mp.get_property("media-title")})
		if (o.use_cache_for_web_videos and is_url(mp.get_property("path"))) then
			local video = mp.get_property("video-format", "none")
			local audio = mp.get_property("audio-codec-name", "none")
			local webm = {vp8=true, vp9=true, av1=true, opus=true, vorbis=true, none=true}
			local mp4 = {h264=true, hevc=true, av1=true, mp3=true, flac=true, aac=true, none=true}
			if webm[video] and webm[audio] then
				web_ext = ".webm"
			elseif mp4[video] and mp4[audio] then
				web_ext = ".mp4"
			else
				web_ext = ".mkv"
			end

			local youtube_ID = ""
			local _, _, videoID = string.find(mp.get_property("filename"), "([%w_-]+)%?si=")
			local videoIDMatch = mp.get_property("filename"):match("[?&]v=([^&]+)")
			if (videoIDMatch) then
				youtube_ID = " [" .. videoIDMatch .. "]"
			elseif (videoID) then
				youtube_ID = " [" .. videoID .. "]"
			end
			full_path_save = mp.command_native({"expand-path", o.save_directory .. "/" .. 
				(string.gsub(mp.get_property("media-title"):sub(1, 100), "^%s*(.-)%s*$:", "%1") .. youtube_ID):gsub('[\\/:*?"<>|]', "")})
		end
	end

	-- Reset average bitrate
	average_bitrate = -1
	avg_count = 1
end

mp.register_event("file-loaded", init)
mp.add_periodic_timer(2, get_bitrate)

local function to_hms(seconds)
	local ms = math.floor((seconds - math.floor(seconds)) * 1000)
	local secs = math.floor(seconds)
	local mins = math.floor(secs / 60)
	secs = secs % 60
	local hours = math.floor(mins / 60)
	mins = mins % 60
	return string.format("%02d-%02d-%02d-%03d", hours, mins, secs, ms)
end

local function next_table_key(t, current)
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	for i = 1, #keys do
		if keys[i] == current then
			return keys[(i % #keys) + 1]
		end
	end
	return keys[1]
end

local function is_windows() local a=os.getenv("windir")if a~=nil then return true else return false end end
local is_windows = is_windows()

local function create_directory(directory_path)
	local args = {"mkdir", directory_path}
	if is_windows then args = {"powershell", "-NoProfile", "-Command", "mkdir", directory_path} end
	local res = utils.subprocess({ args = args, cancellable = false })
	if res.status ~= 0 then
		mp.msg.error("Failed to create directory: " .. directory_path)
	else
		mp.msg.info("Directory created successfully: " .. directory_path)
	end
end

local function check_paths(d, suffix, web_path_save)
	result_path = utils.join_path(full_path .. "/", d.infile_noext .. suffix .. d.ext)
	if (utils.readdir(full_path) == nil) then
		if not is_windows then
			sub_full_path = utils.split_path(full_path)
			create_directory(sub_full_path) -- required for linux as it cannot create mpv/clips/
		end
		create_directory(full_path)
	end
	if web_path_save then return web_path_save .. " " .. suffix .. web_ext end
	return result_path
end

ACTIONS = {}

ACTIONS.COPY = function(d)
	local file_extra_suffix = "_FROM_" .. d.start_time_hms .. "_TO_" .. d.end_time_hms .. " (cut)"
	local result_path = utils.join_path(d.indir, d.infile_noext .. file_extra_suffix .. d.ext)
	if (o.save_to_directory) then result_path = check_paths(d, file_extra_suffix) end
	local args = {
		"ffmpeg",
		"-nostdin", "-y",
		"-loglevel", "error",
		"-ss", d.start_time,
		"-t", d.duration,
		"-i", d.inpath,
		"-c", "copy",
		"-map", "0",
		"-dn",
		"-avoid_negative_ts", "make_zero",
		result_path
	}
	print("Saving clip...")
	mp.command_native_async({
		name = "subprocess",
		args = args,
		playback_only = false,
	}, function() print("Saved clip!") end)
end

ACTIONS.COMPRESS = function(d)
	local target_bitrate = ((o.compress_size * 8192) / d.duration * 0.9) -- Video bitrate (KB)
	msg.info("Theoretical bitrate: " .. target_bitrate)

	local max_bitrate = target_bitrate
	local video_bitrate = average_bitrate
	if video_bitrate and video_bitrate ~= -1 then -- the average bitrate system is to stop small cuts from becoming too big
		max_bitrate = video_bitrate
		msg.info("Average bitrate: " .. max_bitrate)
		if target_bitrate > max_bitrate then
			target_bitrate = max_bitrate
		end
	end
	if target_bitrate > 128 then
		target_bitrate = target_bitrate - 128 -- minus audio bitrate
	end
	msg.info("Using bitrate: " .. target_bitrate)

	local file_extra_suffix = "_FROM_" .. d.start_time_hms .. "_TO_" .. d.end_time_hms .. " (compress)"
	local result_path = utils.join_path(d.indir, d.infile_noext .. file_extra_suffix .. d.ext)
	if o.save_to_directory then 
		result_path = check_paths(d, file_extra_suffix) 
	end
	
	local video_height = mp.get_property_number("height")
	local args = {
		"ffmpeg",
		"-nostdin", "-y",
		"-loglevel", "error",
		"-ss", d.start_time,
		"-t", d.duration,
		"-i", d.inpath,
		"-pix_fmt", "yuv420p",
		"-c:v", "libx264",
		"-b:v", target_bitrate .. "k",
		"-c:a", "copy",
		result_path
	}

	if video_height then
		if video_height > o.resolution then
			res_line = "scale=trunc(oh*a/2)*2:" .. o.resolution
			target_bitrate = target_bitrate
			args = {
				"ffmpeg",
				"-nostdin", "-y",
				"-loglevel", "error",
				"-ss", d.start_time,
				"-t", d.duration,
				"-i", d.inpath,
				"-vf", res_line,
				"-pix_fmt", "yuv420p",
				"-c:v", "libx264",
				"-b:v", target_bitrate .. "k",
				"-c:a", "copy",
				result_path
			}
		end
	end

	print("Saving clip...")
	mp.command_native_async({
		name = "subprocess",
		args = args,
		playback_only = false,
	}, function() 
		print("Saved clip!") 
	end)
end

ACTIONS.ENCODE = function(d)
	local file_extra_suffix = "_FROM_" .. d.start_time_hms .. "_TO_" .. d.end_time_hms .. " (encode)"
	local result_path = utils.join_path(d.indir, d.infile_noext .. file_extra_suffix .. d.ext)
	if (o.save_to_directory) then result_path = check_paths(d, file_extra_suffix) end
	local args = {
		"ffmpeg",
		"-nostdin", "-y",
		"-loglevel", "error",
		"-ss", d.start_time,
		"-t", d.duration,
		"-i", d.inpath,
		"-pix_fmt", "yuv420p",
		"-crf", "16",
		"-preset", "superfast",
		result_path
	}
	print("Saving clip...")
	mp.command_native_async({
		name = "subprocess",
		args = args,
		playback_only = false,
	}, function() 
		print("Saved clip!") 
	end)
end

RUN_WEB_CACHE = function(d)
    local command = {
        filename = check_paths(d, "(cache)", full_path_save)
    }
	command["name"] = "dump-cache"
	command["start"] = d.start_time
	command["end"] = d.end_time
	mp.command_native_async(command, function() 
		print("Saved clip!")
	end)
end

ACTION = o.action
if not ACTIONS[ACTION] then ACTION = next_table_key(ACTIONS, nil) end

START_TIME = nil

local function get_data()
	local d = {}
	d.inpath = mp.get_property("path")
	d.indir = utils.split_path(d.inpath)
	d.infile = mp.get_property("filename")
	d.infile_noext = mp.get_property("filename/no-ext")
	d.ext = mp.get_property("filename"):match("^.+(%..+)$") or ".mp4"
	return d
end

local function get_times(start_time, end_time)
	local d = {}
	d.start_time = tostring(start_time)
	d.end_time = tostring(end_time)
	d.duration = tostring(end_time - start_time)
	d.start_time_hms = tostring(to_hms(start_time))
	d.end_time_hms = tostring(to_hms(end_time))
	d.duration_hms = tostring(to_hms(end_time - start_time))
	return d
end

local function seconds_to_hms(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    local ms = math.floor((seconds - math.floor(seconds)) * 1000)

    local time_string = ""
    if hours > 0 then
        time_string = string.format("%02d:%02d:%02d.%03d", hours, minutes, secs, ms)
    else
        time_string = string.format("%02d:%02d.%03d", minutes, secs, ms)
    end

    return time_string
end

local function text_overlay_on()
	print(string.format("%s from %s", ACTION, seconds_to_hms(START_TIME)))
end

local function print_or_update_text_overlay(content)
	if START_TIME then text_overlay_on() else print(content) end
end

local function cycle_action()
	ACTION = next_table_key(ACTIONS, ACTION)
	print_or_update_text_overlay("Action: " .. ACTION)
end

local function cut(start_time, end_time)
	local d = get_data()
	local t = get_times(start_time, end_time)
	for k, v in pairs(t) do d[k] = v end
	if is_url(d.inpath) then
		if o.use_cache_for_web_videos then
			mp.msg.info("Using web cache")
			RUN_WEB_CACHE(d)
		else
			mp.msg.error("Can't cut on a web video (use_cache_for_web_videos is set to false)")
		end
	else
		ACTIONS[ACTION](d)
	end
end

local function put_time()
	local time = mp.get_property_number("time-pos")
	if not START_TIME then
		START_TIME = time
		text_overlay_on()
		return
	end
	if time > START_TIME then
		print(string.format("%s to %s", ACTION, seconds_to_hms(time)))
		cut(START_TIME, time)
		START_TIME = nil
	else
		print("Invalid selection")
		START_TIME = nil
	end
end

local function cancel_cut()
	START_TIME = nil
	print("Cleared selection")
end

mp.add_key_binding(o.key_cut, "cut", put_time)
mp.add_key_binding(o.key_cancel_cut, "cancel_cut", cancel_cut)
mp.add_key_binding(o.key_cycle_action, "cycle_action", cycle_action)