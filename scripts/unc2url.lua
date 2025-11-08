-- Converts UNC WebDAV paths to URLs

local function url_encode(str)
    str = str:gsub(" ", "%%20")
    str = str:gsub("\"", "%%22")
    str = str:gsub("<", "%%3C")
    str = str:gsub(">", "%%3E")
    str = str:gsub("#", "%%23")
    str = str:gsub("{", "%%7B")
    str = str:gsub("}", "%%7D")
    str = str:gsub("|", "%%7C")
    str = str:gsub("%^", "%%5E")
    str = str:gsub("~", "%%7E")
    str = str:gsub("`", "%%60")
    return str
end

mp.register_event("start-file", function()
    local path = mp.get_property("path")

    -- Detect UNC WebDAV path
    local server, rest = path:match("^\\\\([^\\]+)\\DavWWWRoot\\(.+)$")
    if server and rest then
        print("[unc2url] UNC WebDAV path detected. Converting to URL...")

        local rel = rest:gsub("\\", "/")
        rel = url_encode(rel)

        local url = "https://" .. server:gsub("@SSL", "") .. "/" .. rel

        -- Load the URL in place of the UNC path
        mp.commandv("loadfile", url, "replace")
    end
end)
