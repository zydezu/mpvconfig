--[[
    mpvcut.lua by zydezu
	(https://github.com/zydezu/mpvconfig/blob/main/scripts/mpvcut.lua)
	
	* Based on https://github.com/familyfriendlymikey/mpv-cut/blob/main/main.lua

    Clip, compress and re-encode selected clips
--]]

mp.msg = require("mp.msg")
mp.utils = require("mp.utils")

local options = {
	-- Save location
	save_to_directory = true, 				-- save to 'save_directory' instead of the current folder
	save_directory = "~~desktop/mpv/clips", -- required for web videos

	-- Key config
	key_cut = "a",
	key_cancel_cut = "shift+a",
	key_cycle_action = "A",

	-- The default action
	action = "COPY",

	-- File size targets
	compress_size = 9.50,					-- target size for the compress action (in MB)
	encoding_type = "h265",					-- h264, h265, av1
	shrink_resolution = true,				-- whether to shrink the resolution to the target resolution 
	target_resolution = 1080, 				-- target resolution to compress to (vertical resolution)

	-- Web videos/cache
	use_cache_for_web_videos = true,
}
require("mp.options").read_options(options)

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

local full_path = mp.command_native({"expand-path", options.save_directory})
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
		full_path_save = mp.command_native({"expand-path", options.save_directory .. "/" .. mp.get_property("media-title")})
		if (options.use_cache_for_web_videos and is_url(mp.get_property("path"))) then
			local video = mp.get_property("video-format", "none")
			local audio = mp.get_property("audio-codec-name", "none")

			local webm_codecs = { vp8=true, vp9=true }
			local webm_audio  = { opus=true, vorbis=true }

			local mp4_video   = { h264=true, hevc=true, av1=true }
			local mp4_audio   = { opus=true, mp3=true, flac=true, aac=true }

			local function contains(tbl, val)
				return tbl[val] or false
			end

			if contains(webm_codecs, video) and contains(webm_audio, audio) then
				web_ext = ".webm"
			elseif contains(mp4_video, video) and contains(mp4_audio, audio) then
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
			full_path_save = mp.command_native({"expand-path", options.save_directory .. "/" ..
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

local function create_folder(path)
	local args
	if package.config:sub(1,1) == '\\' then
		-- Windows: normalize slashes and use 'mkdir' with '/S' for nested folders
		local win_path = path:gsub("/", "\\")
		args = { "cmd", "/c", "mkdir", win_path }
	else
		-- Unix/macOS/Linux
		args = { "mkdir", "-p", path }
	end

	local res = mp.utils.subprocess({ args = args })
	if res.status == 0 then
		mp.msg.info("Successfully created folder: " .. path)
	else
		mp.msg.error("Failed to create folder: " .. path)
	end
end

local function check_paths(d, suffix, web_path_save)
	local result_path = mp.utils.join_path(full_path .. "/", d.infile_noext .. suffix .. ".mp4")
	if (mp.utils.readdir(full_path) == nil) then
		create_folder(full_path)
	end
	if web_path_save then return web_path_save .. " " .. suffix .. web_ext end
	return result_path
end

ACTIONS = {}

ACTIONS.COPY = function(d)
	local file_extra_suffix = "_FROM_" .. d.start_time_hms .. "_TO_" .. d.end_time_hms .. " (cut)"
	local result_path = mp.utils.join_path(d.indir, d.infile_noext .. file_extra_suffix .. d.ext)
	if (options.save_to_directory) then result_path = check_paths(d, file_extra_suffix) end
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
	if options.encoding_type == "av1" then options.compress_size = options.compress_size * 1.2 end
	local target_bitrate = ((options.compress_size * 8192) / d.duration * 0.9) -- Video bitrate (KB)
	mp.msg.info("Theoretical bitrate: " .. target_bitrate)

	local max_bitrate = target_bitrate
	local video_bitrate = average_bitrate
	if video_bitrate and video_bitrate ~= -1 then -- the average bitrate system is to stop small cuts from becoming too big
		max_bitrate = video_bitrate
		mp.msg.info("Average bitrate: " .. max_bitrate)
		if target_bitrate > max_bitrate then
			target_bitrate = max_bitrate
		end
	end
	if target_bitrate > 128 then
		target_bitrate = target_bitrate - 128 -- minus audio bitrate
	end
	mp.msg.info("Using bitrate: " .. target_bitrate)

	local file_extra_suffix = "_FROM_" .. d.start_time_hms .. "_TO_" .. d.end_time_hms .. " (compress)"
	local result_path = mp.utils.join_path(d.indir, d.infile_noext .. file_extra_suffix .. ".mp4")
	if options.save_to_directory then
		result_path = check_paths(d, file_extra_suffix)
	end

	local video_height = mp.get_property_number("height")

	-- Start with common args
	local args = {
		"ffmpeg", "-nostdin", "-y", "-loglevel", "error",
		"-ss", d.start_time,
		"-t", d.duration,
		"-i", d.inpath
	}

	if video_height and options.shrink_resolution and video_height > options.target_resolution then
		local res_line = "scale=trunc(oh*a/2)*2:" .. options.target_resolution
		table.insert(args, "-vf")
		table.insert(args, res_line)
	end

	if options.encoding_type == "av1" then
		-- AV1 using libsvtav1
		table.insert(args, "-c:v")
		table.insert(args, "libsvtav1")
		table.insert(args, "-b:v")
		table.insert(args, target_bitrate .. "k")
		table.insert(args, "-svtav1-params")
		table.insert(args, "rc=1")
		table.insert(args, "-preset")
		table.insert(args, tostring(options.av1_preset or 6)) -- default preset 6
		table.insert(args, "-c:a")
		table.insert(args, "libopus")
		table.insert(args, "-b:a")
		table.insert(args, "128k")
	elseif options.encoding_type == "h265" then
		-- H.265 using libx265
		table.insert(args, "-c:v")
		table.insert(args, "libx265")
		table.insert(args, "-b:v")
		table.insert(args, target_bitrate .. "k")
		table.insert(args, "-vtag")
		table.insert(args, "hvc1")
		table.insert(args, "-pix_fmt")
		table.insert(args, "yuv420p")
		table.insert(args, "-c:a")
		table.insert(args, "aac")
		table.insert(args, "-b:a")
		table.insert(args, "128k")
	else
		-- Default to x264
		table.insert(args, "-pix_fmt")
		table.insert(args, "yuv420p")
		table.insert(args, "-c:v")
		table.insert(args, "libx264")
		table.insert(args, "-b:v")
		table.insert(args, target_bitrate .. "k")
		table.insert(args, "-c:a")
		table.insert(args, "copy")
	end

	-- Output path
	table.insert(args, result_path)

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
	local result_path = mp.utils.join_path(d.indir, d.infile_noext .. file_extra_suffix .. ".mp4")
	if (options.save_to_directory) then result_path = check_paths(d, file_extra_suffix) end
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

ACTION = options.action
if not ACTIONS[ACTION] then ACTION = next_table_key(ACTIONS, nil) end

START_TIME = nil

local function get_data()
	local d = {}
	d.inpath = mp.get_property("path")
	d.indir = mp.utils.split_path(d.inpath)
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
		if options.use_cache_for_web_videos then
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

mp.add_key_binding(options.key_cut, "cut", put_time)
mp.add_key_binding(options.key_cancel_cut, "cancel_cut", cancel_cut)
mp.add_key_binding(options.key_cycle_action, "cycle_action", cycle_action)