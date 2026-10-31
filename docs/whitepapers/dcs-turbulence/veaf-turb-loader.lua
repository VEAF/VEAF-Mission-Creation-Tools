-- veaf-turb-loader.lua : hook GUI temporaire, à retirer après la mesure de turbulence.
--
-- À copier dans <Saved Games>/DCS/Scripts/Hooks/ avant de lancer DCS.
-- Quand DCS héberge une partie multijoueur, il charge la mission dont le chemin est écrit dans
-- <Saved Games>/DCS/Logs/veaf-load-request.txt, puis efface le fichier. En solo, net.load_mission ne fait
-- rien : il faut héberger un serveur (Multijoueur > Nouveau serveur).
-- Tout est protégé par pcall : ce hook ne doit jamais casser DCS.

local REQUEST = lfs.writedir() .. "Logs\\veaf-load-request.txt"
local next_check = 0

local function say(msg)
    pcall(log.write, "VEAF-TURB-LOADER", log.INFO, msg)
end

local function check()
    local now = DCS.getRealTime()
    if now < next_check then return end
    next_check = now + 1
    local f = io.open(REQUEST, "r")
    if not f then return end
    local path = f:read("*l")
    f:close()
    os.remove(REQUEST)
    if path and #path > 0 then
        say("loading " .. path .. " -> " .. tostring(net.load_mission(path)))
    end
end

DCS.setUserCallbacks({
    onSimulationFrame = function() pcall(check) end,
})
say("hook loaded, watching " .. REQUEST)
