-- IPOD
-- Contributors:
-- - dennis
-- - kuylar
-- - lucas

-- suggestion by Lucas:
--     Use window api to prevent redrawing screen

local pretty = require "cc.pretty"
local INFO = "IPOD v1.5"

local loop = false
local queue = {}

local tracks = {}
local renderedTracks = {}
local searchValue = ""

local itemsPerPage = 10
local infoLines = 4

local popupMessage = ""

local selectedItem = 1
local scrollIndex = 1

local buttonIndex = 0

local writePopup

-- Modes:
-- "index" - cursor, keys => buttons
-- "search" - cursor, keys => searchValue
-- "remove" - remove confirmation
-- "_" - other
local mode = "index"


local Buttons = {
    {
        text = "Search",
        key = keys.s,
        action = function()
            popupMessage = "Searching, backspace to cancel"
            changeMode("search")
        end,
        desc = "Search for saved tracks",
    },
    {
        text = "Play",
        key = keys.p,
        action = function()
            quickPlay()
        end,
        desc = "Play without saving to list",
    },
    {
        text = "Add",
        key = keys.a,
        action = function()
            addTrackNew()
        end,
        desc = "Add a song to the list"
    },
    {
        text = "Remove",
        key = keys.r,
        action = function()
            buttonIndex = 2
            changeMode("remove")
            --quickRemove()
        end,
        desc = "Remove selected track",
    },
}
local ButtonPaddingCount = 1

-- process Buttons
function processButtons(buttons)
    local xV = ButtonPaddingCount
    for k,v in ipairs(buttons) do
        buttons[k].index = k
        buttons[k].xStart = xV
        -- 2 for []
        -- 1 for space
        -- 2 for ()
        -- 1 for access key
        -- total 6
        xV = xV + 6 + #v.text
        buttons[k].xEnd = xV
        xV = xV + ButtonPaddingCount
    end
end

processButtons(Buttons)

local youcubeapi = require "lib/youcubeapi".API.new()
youcubeapi:detect_bestest_server()



j = fs.open("disk/tracks.json", "r")
tracks = textutils.unserialiseJSON(j.readAll())
j.close()

function saveTracks()
    file = fs.open("disk/tracks.json", "w")
    file.write(textutils.serialiseJSON(tracks))
    file.close()
end

function addTrack(name, type, src)
    table.insert(tracks, {
        name=name,
        src=src,
        type=type
    })
    saveTracks()
    updateProjection()
end

function quickRemove()
    table.remove(tracks, selectedItem)
    saveTracks()
    updateProjection()
end

function getPageCount()
    return math.ceil(#renderedTracks / itemsPerPage)
end

function renderInfo()
    term.clear()
    term.setCursorPos(1, 1)
    
    writeColor("[" .. INFO .. "] ", colors.cyan)
    print("Now with more code!")
    if writePopup ~= nil then
        writePopup()
    else
        print(popupMessage or "")
    end
    writeColor("Song ", colors.lightGray)
    writeColor(selectedItem, colors.white)
    writeColor(" / ", colors.lightGray)
    writeColor(#renderedTracks, colors.white)
    --writeColor(" [" .. scrollIndex .. "][" .. mode .. "][" .. buttonIndex .. "]", colors.gray)
    print()
    print()
end

function renderList()
    local renderN = 0
    for k,v in pairs(renderedTracks) do
        if k >= scrollIndex and k < scrollIndex + itemsPerPage then
            if mode == "remove" and selectedItem == k then
                term.setBackgroundColor(colors.white)
            end
            writeColor((selectedItem == k) and "> " or "  ", (buttonIndex == 0 and colors.orange or colors.gray))
            if mode == "remove" and selectedItem == k then
                term.setTextColor(colors.black)
            end
            writeColor(v.type == "DFPWM" and "[DF] " or "[YT] ", colors.gray)
            -- prefix len 7
            writeColor(v.name, (selectedItem == k and buttonIndex == 0) and colors.white or colors.lightGray)
            print()

            if mode == "remove" and selectedItem == k then
                term.setBackgroundColor(colors.black)
            end

            renderN = renderN + 1
        end
    end
    --[[ while (itemsPerPage - renderN) > 0 do
        print()
        renderN = renderN - 1
    end ]]
end

function writeColor(text, color)
    term.setTextColor(color)
    write(text or "")
    term.setTextColor(colors.white)
end

function writeSelectableButton(text, isSelected, accessKey)
    writeColor("[", isSelected and colors.orange or colors.gray)
    writeColor(text, isSelected and colors.white or colors.lightGray)
    if accessKey ~= nil then
        writeColor((" (" .. accessKey .. ")"), isSelected and colors.lightGray or colors.gray)
    end
    writeColor("]", isSelected and colors.orange or colors.gray)
end

function renderBottom()
    print()
    if mode == "index" then
        -- buttons!
        for k,btn in ipairs(Buttons) do
            write(string.rep(" ", ButtonPaddingCount))
            writeSelectableButton(btn.text, buttonIndex == btn.index, string.upper(keys.getName(btn.key)))
        end
        if Buttons[buttonIndex] == nil then
            print("")
            writeColor("  <enter> Play  <arrow keys> Navigate", colors.lightGray)
        else
            print("")
            writeColor("  " .. Buttons[buttonIndex].desc or "", colors.lightGray)
        end
    elseif mode == "remove" then
        write(" ")
        writeColor("(!)", colors.red)
        writeColor(" Remove? ", colors.lightGray)
        writeSelectableButton("Yes", buttonIndex == 1, "Y")
        write(" ")
        writeSelectableButton("No", buttonIndex == 2, "N")
    elseif mode == "search" then
        write("Search: " .. searchValue)
    end
end

function renderAll()
    renderInfo()
    renderList()
    renderBottom()
end

function changeMode(newMode)
    mode = newMode

    if mode == "index" then
        term.setCursorBlink(false)
        buttonIndex = 1
    elseif mode == "search" then
        term.setCursorBlink(true)
    end
end

a = term.clear
function term.clear()
    peripheral.find('modem',rednet.open)
    a()
end


function quickPlay()
    term.clear()
    term.setCursorPos(2, 2)
    writeColor(">> Quick Play", colors.lime)
    print()
    print("Please enter the youtube url of the song")
    write("> ")

    local url = read()

    local info = youcubeapi:request_media(url)

    if info == nil or info.title == nil then
        writePopup = function()
            writeColor("(!) ", colors.red)
            writeColor("Couldn't get info", colors.yellow)
            print()
        end
        return
    end

    writePopup = function() end

    writeColor(" >> Playing...", colors.green)
    sleep(1)
    playThis({
        type = "YouTube",
        src = url,
        name = info.title .. " [Quick Play]",
    })
end


function playerMenuLoop(track)
    while true do
        local eventData = { os.pullEvent() }
        local eventName = eventData[1]

        if eventName == "key" then
            local keycode = eventData[2]

            -- s (stop)
            if keycode == 83 then
                os.reboot()
            -- l (loop)
            elseif keycode == 76 then
                loop = not loop
                renderPlayerPage(track)
            end
        elseif eventName == "youcubePlaybackEnded" then
            break
        end
    end
end

function playDFPWM(src)
    writeColor("[Compatability Mode]", colors.yellow)
    print()
    writeColor("  Running loudspeaker.lua...", colors.lightGray)
    shell.run("disk/loudspeaker", "play " .. src)
end

function renderPlayerPage(track)
    term.clear()
    term.setCursorPos(2, 2)
    writeColor("Now Playing:", colors.lime)
    term.setCursorPos(3, 3)
    write(track.name or "ERROR UNKNOWN")
    print()

    if track.type == "DFPWM" then
        return
    end

    write("     ")
    writeSelectableButton("Stop", false, "S")
    print()
    write(" [" .. (loop and "X" or " ") .. "] ")
    writeSelectableButton("Loop", false, "L")
    print()
end

function playSelected()
    track = renderedTracks[selectedItem]
    rednet.broadcast('radio:'..selectedItem)
    playThis(track)
end

function playThis(track)
    loop = false
    renderPlayerPage(track)

    if track.type == "DFPWM" then
        playDFPWM(track.src)
        return
    end

    while true do
        local id = shell.openTab("youcube", track.src)

        playerMenuLoop(track)

        if loop == false then
            break
        end
    end
end

-- 1: down, -1: up
function scroll(n)
    if n == nil then
        n = 1
    end

    scrollIndex = scrollIndex + n
end


function updateProjection()
    renderedTracks = tracks
end

function fixupCursor()
    -- fixes loopback using mouse scroll
    if scrollIndex < 1 then
        if selectedItem == 1 then
            scrollIndex = #renderedTracks - math.floor(itemsPerPage / 2)
        else
            selectedItem = selectedItem - 1
            scrollIndex = 1
        end
    end

    -- when scroll down move cursor too
    if scrollIndex > selectedItem then
        selectedItem = scrollIndex
    end

    -- when scroll up move cursor too
    if scrollIndex + itemsPerPage - 1 < selectedItem then
        selectedItem = scrollIndex + itemsPerPage - 1
    end

    -- scroll down at bottom
    if selectedItem - scrollIndex == itemsPerPage then
        scroll(1)
    end

    -- loopback
    if selectedItem > #renderedTracks then
        selectedItem = 1
    elseif selectedItem <= 0 then
        selectedItem = #renderedTracks
    end
    
    -- no negative scrolling
    if selectedItem - scrollIndex < 0 then
        scrollIndex = 0
    -- scroll up
    elseif selectedItem - scrollIndex >= itemsPerPage then
        scrollIndex = #renderedTracks - itemsPerPage
    end
end







function hoverHandler(x, y, isclick)
    if y <= infoLines then
        return
    end

    popupMessage = "click event " .. x .. "," .. y

    if y > infoLines + itemsPerPage then
        -- button handler
        if y > infoLines + itemsPerPage + 1 then
            
            if mode == "index" then
                for k,btn in ipairs(Buttons) do
                    if btn.xStart <= x and x <= btn.xEnd then
                        if buttonIndex == btn.index then
                            btn.action()
                        else
                            buttonIndex = btn.index
                        end
                    end
                end
            end

        else return end
    else
        if mode == "index" or mode == "search" then
            local clickedItem = scrollIndex + y - infoLines - 1

            if clickedItem ~= nil then
                if buttonIndex ~= 0 then
                    buttonIndex = 0
                end

                if isclick and selectedItem == clickedItem then
                    playSelected()
                end
                selectedItem = clickedItem
            end
        end
    end
end

function eventLoop()
    -- event loop
    while true do
        local eventData = { os.pullEvent() }
        local eventName = eventData[1]

        if eventName == "key" then
            local keycode = eventData[2]

            if mode == "index" then
                -- up
                if keycode == 265 then
                    selectedItem = selectedItem - 1
                    if selectedItem < scrollIndex then
                        scroll(-1)
                    end
                    buttonIndex = 0
                -- down
                elseif keycode == 264 then
                    selectedItem = selectedItem + 1
                    if selectedItem - scrollIndex >= itemsPerPage then
                        scroll(1)
                    end
                    buttonIndex = 0
                -- left
                elseif keycode == 263 then
                    if buttonIndex > 0 then
                        buttonIndex = buttonIndex - 1
                    end
                -- right
                elseif keycode == 262 then
                    if buttonIndex < #Buttons then
                        buttonIndex = buttonIndex + 1
                    end
                end
            elseif mode == "remove" then
                -- left or right
                if keycode == 263 or keycode == 262 then
                    if buttonIndex == 1 then
                        buttonIndex = 2
                    elseif buttonIndex == 2 then
                        buttonIndex = 1
                    end
                elseif keycode == keys.y then
                    quickRemove()
                    buttonIndex = 0
                    changeMode("index")
                elseif keycode == keys.n then
                    buttonIndex = 0
                    changeMode("index")
                end
            end
            
            -- enter
            if keycode == 257 then
                if buttonIndex == 0 and (mode == "index" or mode == "search") then
                    playSelected()
                else
                    if mode == "remove" then
                        if buttonIndex == 2 then
                            quickRemove()
                            buttonIndex = 0
                            changeMode("index")
                        else
                            buttonIndex = 0
                            changeMode("index")
                        end
                    else
                        Buttons[buttonIndex].action()
                    end
                end
            -- backspace
            elseif mode == "search" and keycode == 259 then
                if #searchValue == 0 then
                    changeMode("index")
                else
                    searchValue = searchValue:sub(1, #searchValue)
                end
            else
                -- buttons
                if mode == "index" then
                    for k,btn in ipairs(Buttons) do
                        if btn.key == keycode then
                            btn.action()
                        end
                    end
                end
            end
            
            fixupCursor()
        elseif eventName == "mouse_scroll" then
            scroll(eventData[2])
            fixupCursor()
        elseif eventName == "mouse_click" then
            hoverHandler(eventData[3], eventData[4], true)
        elseif eventName == "char" then
            local keycode = eventData[2]
            
            if mode == "search" then
                searchValue = searchValue .. keycode
            end
        end

        renderAll()
    end
end

function addTrackNew()
    term.clear()

    term.setCursorPos(2, 2)

    print("IPOD > Add Song")
    print()
    print("Please enter the youtube url of the song")
    write("> ")

    local url = read()

    local info = youcubeapi:request_media(url)

    if info == nil then
        writePopup = function()
            writeColor("(!) ", colors.red)
            writeColor("Couldn't get info", colors.yellow)
            print()
        end
        return
    end

    writePopup = function()
        writeColor("+ ", colors.green)
        writeColor(info.title, colors.white)
        writeColor(" has been added!", colors.green)
        print()
    end
    writeColor("Saving...", colors.cyan)
    addTrack(info.title, "YouTube", info.id)
    sleep(1)
end

updateProjection()
renderAll()
eventLoop()