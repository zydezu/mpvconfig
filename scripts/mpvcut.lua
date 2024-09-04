utils = require "mp.utils"
msg = require "mp.msg"

local o = {
	-- Save location
	localsavetofolder = true, -- Save to `savedirectory` instead of the current folder
	savedirectory = "~~desktop/mpv/clips", -- Required for web videos

	-- Key config
	keycut = "z",
	keycancelcut = "Z",
	keycycleaction = "a",

	-- The default action
	action = "COPY",

	-- File size target (MB)
	compresssize = 24.00,
	resolution = 720, -- Target resolution to compress to

	-- Web videos/cache
	usecacheforwebvideos = true,
}
(require 'mp.options').read_options(o)

local function print(s)
	mp.msg.info(s)
	mp.osd_message(s)
end

local function table_to_str(o)
	if type(o) == 'table' then
		local s = ''
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. table_to_str(v) .. '\n'
		end
		return s
	else
		return tostring(o)
	end
end

function is_url(s)
	return nil ~=
		string.match(s,
			"^[%w]-://[-a-zA-Z0-9@:%._\\+~#=]+%." ..
			"[a-zA-Z0-9()][a-zA-Z0-9()]?[a-zA-Z0-9()]?[a-zA-Z0-9()]?[a-zA-Z0-9()]?[a-zA-Z0-9()]?" ..
			"[-a-zA-Z0-9()@:%_\\+.~#?&/=]*")
end

local result = mp.command_native({ name = "subprocess", args = {"ffmpeg"}, playback_only = false, capture_stdout = true, capture_stderr = true })
if result.status ~= 1 then
	mp.osd_message("FFmpeg failed to run, please press ` for debug info", 5)
	mp.msg.error("FFmpeg failed to run:\n" .. table_to_str(result))
	mp.msg.error("`which ffmpeg` output:\n" .. table_to_str(mp.command_native({ name = "subprocess", args = {"which", "ffmpeg"}, playback_only = false, capture_stdout = true, capture_stderr = true })))
end
local fullpath = mp.command_native({"expand-path", o.savedirectory})
local fullpathsave = ""
local webext = ".mkv"

function getfullpath()
	if fullpath then
		fullpathsave = mp.command_native({"expand-path", o.savedirectory .. "/" .. mp.get_property("media-title")})
		if (o.usecacheforwebvideos and is_url(mp.get_property("path"))) then
			local video = mp.get_property("video-format", "none")
			local audio = mp.get_property("audio-codec-name", "none")
			local webm={vp8=true,vp9=true,av1=true,opus=true,vorbis=true,none=true}
			local mp4={h264=true,hevc=true,av1=true,mp3=true,flac=true,aac=true,none=true}
			if webm[video] and webm[audio] then
				webext = ".webm"
			elseif mp4[video] and mp4[audio] then
				webext = ".mp4"
			else
				webext = ".mkv"
			end	
		end
	end
end
mp.register_event("file-loaded", getfullpath)

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

function is_windows() local a=os.getenv("windir")if a~=nil then return true else return false end end
local isWindows = is_windows()
local function createDirectory(directoryPath)
	local args = {'mkdir', directoryPath}
	if isWindows then args = {'powershell', '-NoProfile', '-Command', 'mkdir', directoryPath} end
	local res = utils.subprocess({ args = args, cancellable = false })
	if res.status ~= 0 then
		mp.msg.error("Failed to create directory: " .. directoryPath)
	else
		mp.msg.info("Directory created successfully: " .. directoryPath)
	end
end

function checkPaths(d, suffix, webpathsave)
	resultpath = utils.join_path(fullpath .. '/', d.infile_noext .. suffix .. d.ext)
	if (utils.readdir(fullpath) == nil) then
		if not isWindows then
			subfullpath = utils.split_path(fullpath)
			createDirectory(subfullpath) -- required for linux as it cannot create mpv/clips/
		end
		createDirectory(fullpath)
	end
	if webpathsave then return webpathsave .. " " .. suffix .. webext end
	return resultpath
end

ACTIONS = {}

ACTIONS.COPY = function(d)
	local fileextrasuffix = "_FROM_" .. d.start_time_hms .. "_TO_" .. d.end_time_hms .. " (cut)"
	local resultpath = utils.join_path(d.indir, d.infile_noext .. fileextrasuffix .. d.ext)
	if (o.localsavetofolder) then resultpath = checkPaths(d, fileextrasuffix) end
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
		resultpath
	}
	print("Saving clip...")
	mp.command_native_async({
		name = "subprocess",
		args = args,
		playback_only = false,
	}, function() print("Saved clip!") end)
end

averageBitrate = -1
avgCount = 1

function resetBitrate()
	averageBitrate = -1
	avgCount = 1
end

function getBitrate()
	local video_bitrate = mp.get_property_number("video-bitrate")
	if video_bitrate then
		video_bitrate = video_bitrate / 1000
		avgCount = avgCount + 1
		if averageBitrate == -1 then
			averageBitrate = video_bitrate
		else
			averageBitrate = ((avgCount-1) * averageBitrate + video_bitrate) / avgCount
		end
	end
end

mp.register_event("file-loaded", resetBitrate)
mp.add_periodic_timer(2, getBitrate)

ACTIONS.COMPRESS = function(d)
	local target_bitrate = ((o.compresssize * 8192) / d.duration * 0.9) -- Video bitrate (kilobytes)
	msg.info("Initial bitrate: " .. target_bitrate)
	local max_bitrate = target_bitrate
	local video_bitrate = averageBitrate
	if video_bitrate and video_bitrate ~= -1 then -- the average bitrate system is to stop small cuts from becoming too big
		max_bitrate = video_bitrate
		msg.info("Max bitrate: " .. max_bitrate)
		if target_bitrate > max_bitrate then
			target_bitrate = max_bitrate
		end
	end
	if target_bitrate > 128 then
		target_bitrate = target_bitrate - 128 -- minus audio bitrate
	end
	msg.info("Using bitrate: " .. target_bitrate)

	local fileextrasuffix = "_FROM_" .. d.start_time_hms .. "_TO_" .. d.end_time_hms .. " (compress)"
	local resultpath = utils.join_path(d.indir, d.infile_noext .. fileextrasuffix .. d.ext)
	if (o.localsavetofolder) then resultpath = checkPaths(d, fileextrasuffix) end
	
	local videoheight = mp.get_property_number("height")
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
		resultpath
	}
	if (videoheight) then
		if (videoheight > o.resolution) then
			resline = "scale=trunc(oh*a/2)*2:" .. o.resolution
			target_bitrate = target_bitrate
			args = {
				"ffmpeg",
				"-nostdin", "-y",
				"-loglevel", "error",
				"-ss", d.start_time,
				"-t", d.duration,
				"-i", d.inpath,
				"-vf", resline,
				"-pix_fmt", "yuv420p",
				"-c:v", "libx264",
				"-b:v", target_bitrate .. "k",
				"-c:a", "copy",
				resultpath
			}
		end
	end

	print("Saving clip...")
	mp.command_native_async({
		name = "subprocess",
		args = args,
		playback_only = false,
	}, function() print("Saved clip!") end)
end

ACTIONS.ENCODE = function(d)
	local fileextrasuffix = "_FROM_" .. d.start_time_hms .. "_TO_" .. d.end_time_hms .. " (encode)"
	local resultpath = utils.join_path(d.indir, d.infile_noext .. fileextrasuffix .. d.ext)
	if (o.localsavetofolder) then resultpath = checkPaths(d, fileextrasuffix) end
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
		resultpath
	}
	print("Saving clip...")
	mp.command_native_async({
		name = "subprocess",
		args = args,
		playback_only = false,
	}, function() print("Saved clip!") end)
end

RUNWEBCACHE = function(d)
    local command = {
        filename = checkPaths(d, "(cache)", fullpathsave)
    }
	command["name"] = "dump-cache"
	command["start"] = d.start_time
	command["end"] = d.end_time
	mp.command_native_async(command, function() 
		print("Written!")
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

local function text_overlay_on()
	print(string.format("%s from %s", ACTION, secondstotime(START_TIME)))
end

function secondstotime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    local ms = math.floor((seconds - math.floor(seconds)) * 1000)

    local timestring = ""
    if hours > 0 then
        timestring = string.format("%02d:%02d:%02d.%03d", hours, minutes, secs, ms)
    else
        timestring = string.format("%02d:%02d.%03d", minutes, secs, ms)
    end

    return timestring
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
		if o.usecacheforwebvideos then
			mp.msg.info("WEBCACHE")
			RUNWEBCACHE(d)
		else
			mp.msg.error("Can't cut on a web video (usecacheforwebvideos is disabled)")
		end
	else
		-- mp.msg.info(ACTION)
		-- mp.msg.info(table_to_str(d))
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
		print(string.format("%s to %s", ACTION, secondstotime(time)))
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

mp.add_key_binding(o.keycut, "cut", put_time)
mp.add_key_binding(o.keycancelcut, "cancel_cut", cancel_cut)
mp.add_key_binding(o.keycycleaction, "cycle_action", cycle_action)