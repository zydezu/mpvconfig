mp.utils = require("mp.utils")

local messages = {}
local chat_overlay = nil
local chat_hidden = false
local download_finished = false

local options = {
    auto_load = true, -- whether to automatically load live chat when a video loads
    live_chat_directory = "~/Pictures/mpv/livechat/", -- livechat directory
    yt_dlp_path = "yt-dlp", -- path to yt-dlp executable
    show_author = true, -- show the author's name
    author_color = "random", -- the color of the author's name, can be 'random', 'none' or a hex value
    author_border_color = "000000", -- the color of borders around the author's name
    message_color = "FFFFFF", -- the color of the author's message
    message_border_color = "000000", -- the color of the borders around an author's message
    font = "A-OTF Shin Go Pro M", -- the font to use for chat messages
    font_size = 18, -- the font size of chat messages
    border_size = 2, -- the border size of chat messages
    message_duration = 5000, -- the duration that each message is shown for in miliseconds
    max_message_line_length = 40, -- the amount of characters before a message breaks into a new line
    message_break_anywhere = false, -- whether line breaks in messages can happen anywhere or only after whole words
    message_gap = 0, -- additional spacing between chat messages, given as a percentage of the font height
    anchor = 9, -- where chat displays on the screen in numpad notation (1 is bottom-left, 7 is top-left, 9 is top-right, etc.)
    parse_interval = 0.5
}
require("mp.options").read_options(options)

if not options.font then options.font = mp.get_property_native('osd-font') end

local NORMAL = 0
local SUPERCHAT = 1

local function split_utf8_strings(str, maxLength)
    local result = {}
    local currentIndex = 1
    local length = #str
    local byteCount = 0
    local charCount = 0

    while currentIndex <= length do
        -- Check if the next characters are a \N escape sequence
        local nextTwo = string.sub(str, currentIndex, currentIndex + 1)
        if nextTwo == "\\N" then
            table.insert(result, nextTwo)
            currentIndex = currentIndex + 2
            goto continue
        end

        local byte = string.byte(str, currentIndex)
        local charLength

        if byte >= 0 and byte <= 127 then
            charLength = 1
        elseif byte >= 192 and byte <= 223 then
            charLength = 2
        elseif byte >= 224 and byte <= 239 then
            charLength = 3
        elseif byte >= 240 and byte <= 247 then
            charLength = 4
        else
            break -- invalid byte
        end

        if byteCount + charLength > maxLength then
            break
        end

        local currentChar = string.sub(str, currentIndex, currentIndex + charLength - 1)
        table.insert(result, currentChar)
        byteCount = byteCount + charLength
        currentIndex = currentIndex + charLength
        charCount = charCount + 1

        ::continue::
    end

    return table.concat(result), charCount
end

local delimiter_pattern = " %.,%-!%?"
local function split_string(input)
    local splits = {}

    for inputs in string.gmatch(input, "[^" .. delimiter_pattern .. "]+[" .. delimiter_pattern .. "]*") do
        table.insert(splits, inputs)
    end

    return splits
end

local function rgb_from_int(color)
    local r = math.floor(color / 65536) % 256
    local g = math.floor(color / 256) % 256
    local b = color % 256
    return r, g, b
end

local function rgb_to_int(r, g, b)
    return r * 65536 + g * 256 + b
end

local function brightness(r, g, b)
    return 0.299 * r + 0.587 * g + 0.114 * b
end

local function clamp_brightness(r, g, b, min_bright, max_bright)
    local bright = brightness(r, g, b)

    if bright < min_bright then
        local scale = min_bright / bright
        r = math.min(255, r * scale)
        g = math.min(255, g * scale)
        b = math.min(255, b * scale)
    elseif bright > max_bright then
        local scale = max_bright / bright
        r = r * scale
        g = g * scale
        b = b * scale
    end

    return math.floor(r), math.floor(g), math.floor(b)
end

local function string_to_color(str)
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + str:byte(i)) % 0xFFFFFF
    end

    local r, g, b = rgb_from_int(hash)

    r, g, b = clamp_brightness(r, g, b, 160, 220)

    return rgb_to_int(r, g, b)
end

local function swap_color_string(str)
    local r = str:sub(1, 2)
    local g = str:sub(3, 4)
    local b = str:sub(5, 6)
    return b .. g .. r
end

local function reset()
    messages = {}
    if chat_overlay then
        chat_overlay:remove()
    end
    chat_overlay = nil
end

local function on_download_finished()
    download_finished = true
end

local function break_message(message, initial_length)
    local max_line_length = options.max_message_line_length
    if max_line_length <= 0 then
        return message
    end

    local contains_cjk = message:find("[%z\1-\127\194-\244][\226\128\128-\226\255\255]") 
                       or message:find("[\224\176\128-\233\190\191]")

    local break_anywhere = options.message_break_anywhere or contains_cjk

    local current_length = initial_length
    local result = ""

    if break_anywhere then
        local lines = {}
        while #message > 0 do
            local part, count = split_utf8_strings(message, max_line_length)
            table.insert(lines, part)

            local byte_offset = 0
            for i = 1, count do
                local b = string.byte(message, byte_offset + 1)
                if b < 128 then
                    byte_offset = byte_offset + 1
                elseif b < 224 then
                    byte_offset = byte_offset + 2
                elseif b < 240 then
                    byte_offset = byte_offset + 3
                else
                    byte_offset = byte_offset + 4
                end
            end

            message = message:sub(byte_offset + 1)
        end

        return table.concat(lines, "\n")
    end

    for _, v in ipairs(split_string(message)) do
        local _, utf8_char_count = split_utf8_strings(v, 1000)

        if current_length + utf8_char_count > max_line_length then
            result = result .. "\n" .. v
            current_length = utf8_char_count
        else
            result = result .. v
            current_length = current_length + utf8_char_count
        end
    end

    return result
end

local function chat_message_to_string(message)
    if message.type == NORMAL then
        if options.show_author then
            if options.author_color == 'random' then
                return string.format(
                    '{\\1c&H%06x&}{\\3c&H%s&}%s{\\1c&H%s&}{\\3c&H%s&}: %s',
                    message.author_color,
                    swap_color_string(options.author_border_color),
                    message.author,
                    swap_color_string(options.message_color),
                    swap_color_string(options.message_border_color),
                    break_message(message.contents, message.author:len() + 2)
                )
            elseif options.author_color == 'none' then
                return string.format(
                    '{\\3c&H%s&}%s{\\1c&H%s&}{\\3c&H%s&}: %s',
                    swap_color_string(options.author_border_color),
                    message.author,
                    swap_color_string(options.message_color),
                    swap_color_string(options.message_border_color),
                    break_message(message.contents, message.author:len() + 2)
                )
            else
                return string.format(
                    '{\\1c&H%s&}{\\3c&H%s&}%s{\\1c&H%s&}{\\3c&H%s&}: %s',
                    swap_color_string(options.author_color),
                    swap_color_string(options.author_border_color),
                    message.author,
                    swap_color_string(options.message_color),
                    swap_color_string(options.message_border_color),
                    break_message(message.contents, message.author:len() + 2)
                )
            end
        else
            return break_message(message.contents, 0)
        end
    elseif message.type == SUPERCHAT then
        if message.contents then
            return string.format(
                '%s %s: %s',
                message.author,
                message.money,
                break_message(message.contents, message.author:len() + message.money:len())
           )
       else
            return string.format(
                '%s %s',
                message.author,
                message.money
           )
       end
    end
end

local function format_message(message)
    local message_string = chat_message_to_string(message):gsub("’", "'")
    local result = nil
    local lines = message_string:gmatch("([^\n]*)\n?")
    for line in lines do
        local formatting = '{\\an' .. options.anchor .. '}'
                        .. '{\\fs' .. options.font_size .. '}'
                        .. '{\\fn' .. options.font .. '}'
                        .. '{\\bord' .. options.border_size .. '}'
                        .. string.format(
                               '{\\1c&H%s&}',
                               swap_color_string(options.message_color)
                           )
                        .. string.format(
                               '{\\3c&H%s&}',
                               swap_color_string(options.message_border_color)
                           )
        if message.type == SUPERCHAT then
            formatting = formatting .. string.format(
                '{\\1c&H%s&}{\\3c&%s&}',
                swap_color_string(string.format('%06x', message.text_color)),
                swap_color_string(string.format('%06x', message.border_color))
            )
        end
        local message_string = formatting
                            .. line
        if result == nil then
            result = message_string
        else
            if options.anchor <= 3 then
                result = message_string .. '\n' .. result
            else
                result = result .. '\n' .. message_string
            end
        end
    end
    return result or ''
end

local function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then
        f:close()
        return true
    else
        return false
    end
end

local function download_live_chat(url, filename)
    if file_exists(filename) then return end
    mp.command_native_async({
        name = "subprocess",
        args = {
            options.yt_dlp_path,
            '--skip-download',
            '--sub-langs=live_chat',
            url,
            '--write-sub',
            '-o',
            '%(id)s',
            '-P',
            mp.command_native({"expand-path", options.live_chat_directory})
        }
    }, on_download_finished)
end

local function live_chat_exists_remote(url)
    local result = mp.command_native({
        name = "subprocess",
        capture_stdout = true,
        args = { options.yt_dlp_path, url, '--list-subs', '--quiet' }
    })
    if result.status == 0 then
        return string.find(result.stdout, "live_chat")
    end
    return false
end

local function update_messages(live_chat_json, last)
    local file = io.open(live_chat_json, 'rb')
    file:seek('set', last)
    while true do
        local line = file:read('*l')
        if not line then
            if not download_finished then
                last = file:seek()
                mp.add_timeout(options.parse_interval, function() update_messages(live_chat_json, last) end)
            end
            file:close()
            return
        end
        local entry = mp.utils.parse_json(line)
        if entry.replayChatItemAction then
            local time = tonumber(
                entry.videoOffsetTimeMsec or
                entry.replayChatItemAction.videoOffsetTimeMsec
            )
            for _,action in ipairs(entry.replayChatItemAction.actions) do
                if action.addChatItemAction then
                    if action.addChatItemAction.item.liveChatTextMessageRenderer then
                        local liveChatTextMessageRenderer = action.addChatItemAction.item.liveChatTextMessageRenderer

                        local id = liveChatTextMessageRenderer.authorExternalChannelId
                        local color = string_to_color(id)

                        local author
                        if liveChatTextMessageRenderer.authorName then
                            author = liveChatTextMessageRenderer.authorName.simpleText or 'NAME_ERROR'
                        else
                            author = '-'
                        end

                        local message_data = liveChatTextMessageRenderer.message
                        local message = ""
                        for _,data in ipairs(message_data.runs) do
                            if data.text then
                                message = message .. data.text
                            elseif data.emoji then
                                if data.emoji.isCustomEmoji then
                                    message = message .. data.emoji.shortcuts[1]
                                else
                                    message = message .. data.emoji.emojiId
                                end
                            end
                        end

                        messages[#messages+1] = {
                            type = NORMAL,
                            author = author,
                            author_color = color,
                            contents = message,
                            time = time
                        }
                    elseif action.addChatItemAction.item.liveChatPaidMessageRenderer then
                        local liveChatPaidMessageRenderer = action.addChatItemAction.item.liveChatPaidMessageRenderer

                        local border_color = liveChatPaidMessageRenderer.bodyBackgroundColor - 0xff000000
                        local text_color = liveChatPaidMessageRenderer.bodyTextColor - 0xff000000
                        local money = liveChatPaidMessageRenderer.purchaseAmountText.simpleText

                        local author
                        if liveChatPaidMessageRenderer.authorName then
                            author = liveChatPaidMessageRenderer.authorName.simpleText or 'NAME_ERROR'
                        else
                            author = '-'
                        end

                        local message_data = liveChatPaidMessageRenderer.message
                        local message = ""
                        if message_data ~= nil then
                            for _,data in ipairs(message_data.runs) do
                                if data.text then
                                    message = message .. data.text
                                elseif data.emoji then
                                    if data.emoji.isCustomEmoji then
                                        message = message .. data.emoji.shortcuts[1]
                                    else
                                        message = message .. data.emoji.emojiId
                                    end
                                end
                            end
                        else
                            message = nil
                        end

                        messages[#messages+1] = {
                            type = SUPERCHAT,
                            author = author,
                            money = money,
                            border_color = border_color,
                            text_color = text_color,
                            contents = message,
                            time = time
                        }
                    end
                end
            end
        end
    end
end

local function update_chat_overlay(time)
    if chat_hidden or chat_overlay == nil or messages == {} or time == nil then
        return
    end

    local msec = time * 1000

    chat_overlay.data = ''

    local visible_messages = {}

    for i = 1, #messages do
        local message = messages[i]
        if message.time > msec then
            break
        elseif msec <= message.time + options.message_duration then
            table.insert(visible_messages, message)
        end
    end

    local max_visible = 20
    local count = #visible_messages

    if count > max_visible then
        local start_index = count - max_visible + 1
        local trimmed = {}
        for i = start_index, count do
            table.insert(trimmed, visible_messages[i])
        end
        visible_messages = trimmed
    end

    for _, message in ipairs(visible_messages) do
        local message_string = format_message(message)

        if options.anchor <= 3 then
            chat_overlay.data =
                    message_string
                ..  '\n'
                ..  '{\\fscy' .. options.message_gap .. '}{\\fscx0}\\h{\fscy\fscx}'
                ..  chat_overlay.data
        else
            chat_overlay.data =
                    chat_overlay.data
                ..  '{\\fscy' .. options.message_gap .. '}{\\fscx0}\\h{\fscy\fscx}'
                ..  '\n'
                ..  message_string
        end
    end

    chat_overlay:update()
end

local function wait_for_file(filename, generating_overlay)
    if filename ~= nil and file_exists(filename) then
        update_messages(filename, 0)
        if not chat_overlay then
            chat_overlay = mp.create_osd_overlay("ass-events")
            chat_overlay.z = -1
        end
        update_chat_overlay(mp.get_property_native("time-pos"))
        generating_overlay:remove()
    else
        mp.add_timeout(options.parse_interval, function() wait_for_file(filename, generating_overlay) end)
    end
end

local function load_live_chat(filename, interactive)
    reset()

    local generating_overlay = mp.create_osd_overlay("ass-events")

    local path = mp.get_property_native('path')
    if filename == nil then
        local is_network = path:find('^http://') ~= nil or
                           path:find('^https://') ~= nil
        if is_network then
            local id = path:gsub("^.*\\?v=", ""):gsub("&.*", "")
            filename = string.format(
                "%s/%s.live_chat.json",
                mp.command_native({"expand-path", options.live_chat_directory}),
                id
            )

            if not file_exists(filename) then
                generating_overlay:update()
                if live_chat_exists_remote(path) then
                    generating_overlay:update()

                    download_live_chat(path, filename)
                end
            end
        else
            local base_path = path:match('(.+)%..+$') or path
            filename = base_path .. '.live_chat.json'
        end
    end

    wait_for_file(filename, generating_overlay)
end

local function _load_live_chat(_, filename)
    load_live_chat(filename)
end

local function _update_chat_overlay(_, time)
    update_chat_overlay(time)
end

local function load_live_chat_interactive(filename)
    load_live_chat(filename, true)
end

local function set_chat_hidden(state)
    if state == nil then
        chat_hidden = not chat_hidden
    else
        chat_hidden = state == 'yes'
    end

    if chat_overlay ~= nil then
        if chat_hidden then
            mp.command('show-text "Youtube chat replay hidden"')
            chat_overlay:remove()
        else
            mp.command('show-text "Youtube chat replay unhidden"')
            update_chat_overlay(mp.get_property_native("time-pos"))
        end
    end
end

local function set_chat_anchor(anchor)
    if anchor == nil then
        options.anchor = (options.anchor % 9) + 1
    else
        options.anchor = tonumber(anchor)
    end
    if chat_overlay then
        update_chat_overlay(mp.get_property_native("time-pos"))
    end
end

local function set_break_anywhere(state)
    if state == nil then
        options.message_break_anywhere = not options.message_break_anywhere
    else
        options.message_break_anywhere = state == 'yes'
    end

    if chat_overlay then
        update_chat_overlay(mp.get_property_native("time-pos"))
    end
end

mp.add_key_binding(nil, "load-chat", load_live_chat_interactive)
mp.add_key_binding(nil, "unload-chat", reset)
mp.add_key_binding(nil, "chat-hidden", set_chat_hidden)
mp.add_key_binding(nil, "chat-anchor", set_chat_anchor)
mp.add_key_binding(nil, "break-anywhere", set_break_anywhere)

if options.auto_load then
    mp.register_event("file-loaded", _load_live_chat)
end
mp.observe_property("time-pos", "native", _update_chat_overlay)
mp.register_event("end-file", reset)