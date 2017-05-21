---------------
-- LIBRARIES --
---------------
local AceAddon = LibStub("AceAddon-3.0");
local LibCamera = LibStub("LibCamera-1.0");

ReactiveZoom = AceAddon:NewAddon("ReactiveZoom", "AceConsole-3.0");


------------
-- LOCALS --
------------
local targetZoom;
local oldCameraZoomIn = CameraZoomIn;
local oldCameraZoomOut = CameraZoomOut;


--------
-- DB --
--------
local defaults = {
    global = {
        enabled = true,
        addIncrementsAlways = 1,
        addIncrements = 3,
        maxZoomTime = .25,
        incAddDifference = 4,
    },
}


----------
-- CORE --
----------
function ReactiveZoom:OnInitialize()
    -- setup db
    self.db = LibStub("AceDB-3.0"):New("ReactiveZoomDB", defaults, true);

    -- setup chat commands
    self:RegisterChatCommand("reactivezoom", "OpenMenu");
    self:RegisterChatCommand("rz", "OpenMenu");

    -- setup menu
    self:RegisterMenu();

    -- detect DynamicCam and disable if detected
    if (DynamicCam) then
        self:Disable();
        self:Print("DynamicCam detected, disabling ReactiveZoom.")
        self:Print("All features in ReactiveZoom are present in DynamicCam.")
    end

    -- if the addon is turned off in db, turn it off
    if (self.db.global.enabled == false) then
        self:Disable();
    end
end

function ReactiveZoom:OnEnable()
    self.db.global.enabled = true;

    if (not DynamicCam) then
        self:TurnOn();
    end
end

function ReactiveZoom:OnDisable()
    self.db.global.enabled = false;

    if (not DynamicCam) then
        self:TurnOff();
    end
end


-------------------
-- REACTIVE ZOOM --
-------------------
local function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0);
    return math.floor(num * mult + 0.5) / mult;
end

local function clearTargetZoom()
    targetZoom = nil;
end

local function outQuad(t, b, c, d)
    t = t / d;
    return -c * t * (t - 2) + b;
end

local function Zoom(zoomIn, increments, automated)
    increments = increments or 1;

    if (not automated and increments == 1) then
        local currentZoom = GetCameraZoom();

        local addIncrementsAlways = ReactiveZoom.db.global.addIncrementsAlways;
        local addIncrements = ReactiveZoom.db.global.addIncrements;
        local maxZoomTime = ReactiveZoom.db.global.maxZoomTime;
        local incAddDifference = ReactiveZoom.db.global.incAddDifference;

        -- if we've change directions, make sure to reset
        if (zoomIn) then
            if (targetZoom and targetZoom > currentZoom) then
                targetZoom = nil;
            end
        else
            if (targetZoom and targetZoom < currentZoom) then
                targetZoom = nil;
            end
        end
        

        -- scale increments up
        if (targetZoom) then
            local diff = math.abs(targetZoom - currentZoom);

            if (diff > incAddDifference) then
                increments = increments + addIncrementsAlways + addIncrements;
            else
                increments = increments + addIncrementsAlways;
            end
        else
            increments = increments + addIncrementsAlways;
        end

        -- if there is already a target zoom, base off that one, or just use the current zoom
        targetZoom = targetZoom or currentZoom;

        if (zoomIn) then
            targetZoom = math.max(0, targetZoom - increments);
        else
            targetZoom = math.min(39, targetZoom + increments);
        end

        -- if we don't need to zoom because we're at the max limits, then don't
        if ((targetZoom == 39 and currentZoom == 39)
            or (targetZoom == 0 and currentZoom == 0)) then
            return;
        end

        -- round target zoom off to the nearest decimal
        targetZoom = round(targetZoom, 1);

        -- print("ReactiveZoom", targetZoom);

        -- get the current time to zoom if we were going linearly or use maxZoomTime, if that's too high
        local zoomTime = math.min(maxZoomTime, math.abs(targetZoom - currentZoom)/tonumber(GetCVar("cameraZoomSpeed")));

        LibCamera:SetZoom(targetZoom, zoomTime, outQuad, clearTargetZoom);
    else
        if (zoomIn) then
            oldCameraZoomIn(increments, automated);
        else
            oldCameraZoomOut(increments, automated);
        end
    end
end

local function ZoomIn(increments, automated)
    Zoom(true, increments, automated);
end

local function ZoomOut(increments, automated)
    Zoom(false, increments, automated);
end

function ReactiveZoom:TurnOn()
    CameraZoomIn = ZoomIn;
    CameraZoomOut = ZoomOut;
end

function ReactiveZoom:TurnOff()
    CameraZoomIn = oldCameraZoomIn;
    CameraZoomOut = oldCameraZoomOut;
end


-------------
-- OPTIONS --
-------------
local menu = {
    name = "ReactiveZoom",
    handler = ReactiveZoom,
    type = 'group',
    disabled = function() if DynamicCam then return true; end end,
    args = {
        reactiveZoom = {
            type = 'group',
            name = "Options",
            order = 2,
            inline = true,
            args = {
                dynamicCamDetected = {
                    type = 'description',
                    name = "DynamicCam detected. All features in ReactiveZoom are also preset there, use it instead.",
                    hidden = function() if not DynamicCam then return true; end end,
                    width = "full",
                    order = 0,
                },
                enable = {
                    type = 'toggle',
                    name = "Enable",
                    desc = "If the addon is enabled.",
                    get = "IsEnabled",
                    set = function(_, newValue) if (not newValue) then ReactiveZoom:Disable(); else ReactiveZoom:Enable(); end end,
                    order = 1,
                },
                maxZoomTime = {
                    type = 'range',
                    name = "Max Manual Zoom Time",
                    desc = "The most time that the camera will take to adjust to a manually set zoom.",
                    disabled = function() if not ReactiveZoom:IsEnabled() then return true; end end,
                    min = .1,
                    max = 2,
                    step = .05,
                    get = function() return (ReactiveZoom.db.global.maxZoomTime) end,
                    set = function(_, newValue) ReactiveZoom.db.global.maxZoomTime = newValue; end,
                    order = 2,
                    width = "full",
                },
                addIncrementsAlways = {
                    type = 'range',
                    name = "Zoom Increments",
                    desc = "The amount of distance that the camera should travel for each \'tick\' of the mousewheel.",
                    disabled = function() if not ReactiveZoom:IsEnabled() then return true; end end,
                    min = 1,
                    max = 5,
                    step = .25,
                    get = function() return (ReactiveZoom.db.global.addIncrementsAlways + 1) end,
                    set = function(_, newValue) ReactiveZoom.db.global.addIncrementsAlways = newValue - 1; end,
                    order = 3,
                },
                addIncrements = {
                    type = 'range',
                    name = "Additional Increments",
                    desc = "When manually zooming quickly, add this amount of additional increments per \'tick\' of the mousewheel.",
                    disabled = function() if not ReactiveZoom:IsEnabled() then return true; end end,
                    min = 0,
                    max = 5,
                    step = .25,
                    get = function() return (ReactiveZoom.db.global.addIncrements) end,
                    set = function(_, newValue) ReactiveZoom.db.global.addIncrements = newValue; end,
                    order = 4,
                },
                incAddDifference = {
                    type = 'range',
                    name = "Zooming Quickly (Difference)",
                    desc = "The amount of ground that the camera needs to make up before it is considered to be moving quickly. Higher is harder to achieve.",
                    disabled = function() if not ReactiveZoom:IsEnabled() then return true; end end,
                    min = 2,
                    max = 5,
                    step = .5,
                    get = function() return (ReactiveZoom.db.global.incAddDifference) end,
                    set = function(_, newValue) ReactiveZoom.db.global.incAddDifference = newValue; end,
                    order = 5,
                },
            },
        },
    },
};

function ReactiveZoom:OpenMenu()
    -- just open to the frame, double call because blizz bug
    InterfaceOptionsFrame_OpenToCategory(self.menu);
    InterfaceOptionsFrame_OpenToCategory(self.menu);
end

function ReactiveZoom:RegisterMenu()
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("ReactiveZoom", menu);
    self.menu = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ReactiveZoom", "ReactiveZoom");
end
