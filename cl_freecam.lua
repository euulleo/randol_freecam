local Config = lib.load('config')
local FREE_CAM
local offsetRotX, offsetRotY, offsetRotZ = 0.0, 0.0, 0.0
local offsetCoords = {x = 0.0, y = 0.0, z = 0.0}
local precision = 1.0
local speed = 1.0
local currFilter = 1
local camActive = false
local dofOn = false
local dofStrength = 0.5
local dofFar = 150.0
local dofNear = 0.10
local barsOn = false

local function toggleMap()
    local isRadarVisible = not IsRadarHidden()
    DisplayRadar(not isRadarVisible)
end

local function toggleBars()
    barsOn = not barsOn
    if barsOn then
        while barsOn do
            DrawRect(1.0, 1.0, 2.0, 0.23, 0, 0, 0, 255)
            DrawRect(1.0, 0.0, 2.0, 0.23, 0, 0, 0, 255)
            Wait(0)
        end
    end
end

local function resetEverything()
    ClearFocus()
    SetCamUseShallowDofMode(FREE_CAM, false)
    RenderScriptCams(false, false, 0, true, false)
    DestroyCam(FREE_CAM, false)
    offsetRotX = 0.0
    offsetRotY = 0.0
    offsetRotZ = 0.0
    speed = 1.0
    precision = 1.0
    currFov = GetGameplayCamFov()
    currFilter = 1
    ClearTimecycleModifier()
    FREE_CAM = nil
    dofStrength = 0.5
    dofFar = 150.0
    dofNear = 0.10
    dofOn = false
    barsOn = false
end

local function setNewFov(setNewFov)
    if DoesCamExist(FREE_CAM) then
        local currFov = GetCamFov(FREE_CAM)
        local newFov = currFov + setNewFov

        if ((newFov >= Config.MinFov) and (newFov <= Config.MaxFov)) then
            SetCamFov(FREE_CAM, newFov)
        end
    end
end

local function toggleDof()
    dofOn = not dofOn
    if dofOn then
        if DoesCamExist(FREE_CAM) then
            SetCamUseShallowDofMode(FREE_CAM, true)
            SetCamNearDof(FREE_CAM, dofNear)
            SetCamFarDof(FREE_CAM, dofFar)
            SetCamDofStrength(FREE_CAM, dofStrength)
        end
    else
        dofStrength = 0.5
        dofFar = 150.0
        dofNear = 0.10
        SetCamNearDof(FREE_CAM, dofNear)
        SetCamFarDof(FREE_CAM, dofFar)
        SetCamDofStrength(FREE_CAM, dofStrength)
        SetCamUseShallowDofMode(FREE_CAM, false)
        ClearFocus()
    end
end

local function processNewPos(x, y, z)
    local newPos = {x = x, y = y, z = z}
    local moveSpeed = 0.1 * speed

    local function updatePosition(multX, multY, multZ, direction)
        newPos.x = newPos.x + direction * moveSpeed * multX
        newPos.y = newPos.y - direction * moveSpeed * multY
    end

    if IsDisabledControlPressed(1, 32) then -- W (forwards)
        updatePosition(Sin(offsetRotZ), Cos(offsetRotZ), Sin(offsetRotX), -1)
    elseif IsDisabledControlPressed(1, 33) then -- S (backwards)
        updatePosition(Sin(offsetRotZ), Cos(offsetRotZ), Sin(offsetRotX), 1)
    end

    if IsDisabledControlPressed(1, 34) then -- A (left)
        updatePosition(Sin(offsetRotZ + 90.0), Cos(offsetRotZ + 90.0), Sin(offsetRotY), -1)
    elseif IsDisabledControlPressed(1, 35) then -- D (right)
        updatePosition(Sin(offsetRotZ + 90.0), Cos(offsetRotZ + 90.0), Sin(offsetRotY), 1)
    end

    if IsDisabledControlPressed(1, 22) then -- Space (up)
        newPos.z += moveSpeed
    elseif IsDisabledControlPressed(1, 20) then -- Z (down)
        newPos.z -= moveSpeed
    end

    if IsDisabledControlPressed(1, 21) then -- Shift (hold)
        if IsDisabledControlPressed(1, 15) then -- Mouse wheel up (speed up)
            speed = math.min(speed + 0.1, Config.MaxSpeed)
        elseif IsDisabledControlPressed(1, 14) then -- Mouse wheel down (speed down)
            speed = math.max(speed - 0.1, Config.MinSpeed)
        end
    else
        if IsDisabledControlPressed(1, 15) then -- Mouse wheel up (zoom in)
            setNewFov(-1.0)
        elseif IsDisabledControlPressed(1, 14) then -- Mouse wheel down (zoom out)
            setNewFov(1.0)
        end
    end

    offsetRotX = offsetRotX - (GetDisabledControlNormal(1, 2) * precision * 8.0)
    offsetRotZ = offsetRotZ - (GetDisabledControlNormal(1, 1) * precision * 8.0)

    if IsDisabledControlPressed(1, 44) then -- Q (roll left)
        offsetRotY = offsetRotY - precision
    elseif IsDisabledControlPressed(1, 38) then -- E (roll right)
        offsetRotY = offsetRotY + precision
    end

    offsetRotX = math.clamp(offsetRotX, -90.0, 90.0)
    offsetRotY = math.clamp(offsetRotY, -90.0, 90.0)
    offsetRotZ = offsetRotZ % 360.0

    return newPos
end

local function processCamControls()
    DisableFirstPersonCamThisFrame()

    local camCoords = GetCamCoord(FREE_CAM)
    local newPos = processNewPos(camCoords.x, camCoords.y, camCoords.z)
    SetFocusArea(newPos.x, newPos.y, newPos.z, 0.0, 0.0, 0.0)
    SetCamCoord(FREE_CAM, newPos.x, newPos.y, newPos.z)
    SetCamRot(FREE_CAM, offsetRotX, offsetRotY, offsetRotZ, 2)

    for k, v in pairs(Config.DisabledControls) do
        DisableControlAction(0, v, true)
    end

    local currentPos = GetEntityCoords(cache.ped)
    if #(currentPos - vec3(newPos.x, newPos.y, newPos.z)) > Config.MaxDistance then
        if not IsEntityDead(cache.ped) then
            lib.notify({ type = 'error', description = 'You went too far using the free camera.' })
        end
        camActive = false
        lib.hideMenu()
    end

    if dofOn then
        SetUseHiDof()
    end
end

local function toggleCam()
    camActive = not camActive
    if camActive then
        ClearFocus()
        FREE_CAM = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', GetEntityCoords(cache.ped), 0, 0, 0, GetGameplayCamFov() * 1.0)
        SetCamActive(FREE_CAM, true)
        RenderScriptCams(true, false, 0, true, false)
        SetCamAffectsAiming(FREE_CAM, false)

        CreateThread(function()
            while camActive do
                processCamControls()
                Wait(0)
            end
            resetEverything()
        end)
    end
end
 
RegisterCommand(Config.CommandName, function()
    lib.registerMenu({
        id = 'cinematic_cam_menu',
        title = 'Câmera Cinemática',
        position = 'top-right',
        onSideScroll = function(selected, scrollIndex, args)
            if selected == 2 then
                SetTimecycleModifier(Config.Filters[scrollIndex])
                currFilter = scrollIndex
            elseif selected == 6 then
                dofNear = tonumber(Config.NearDof[scrollIndex])
                SetCamNearDof(FREE_CAM, dofNear)
            elseif selected == 7 then
                dofFar = tonumber(Config.FarDof[scrollIndex])
                SetCamFarDof(FREE_CAM, dofFar)
            elseif selected == 8 then
                dofStrength = tonumber(Config.StrengthDof[scrollIndex])
                SetCamDofStrength(FREE_CAM, dofStrength)
            end
        end,
        onCheck = function(selected, checked, args)
            if selected == 1 then
                toggleCam()
            elseif selected == 3 then
                toggleDof()
            elseif selected == 4 then
                toggleBars()
            elseif selected == 5 then
                toggleMap()
            end
        end,
        options = {
    {label = 'Ligar/Desligar Câmera', checked = camActive, icon = 'camera'},
    {label = 'Filtros da Câmera', values = Config.Filters, icon = 'camera', defaultIndex = currFilter, description = 'Use as setas para navegar pelos filtros. Pressione Enter para redefinir para o filtro padrão.'},
    {label = 'Ligar/Desligar Profundidade', checked = dofOn, icon = 'eye', description = 'Ativa ou desativa o efeito de profundidade de campo.'},
    {label = 'Ligar/Desligar Barras Pretas', checked = barsOn, icon = 'film', description = 'Ativa ou desativa as barras cinematográficas.'},
    {label = 'Ligar/Desligar Minimapa', checked = not IsRadarHidden(), icon = 'map', description = 'Ativa ou desativa o minimapa.'},
    {label = 'Profundidade de Campo - Próximo', values = Config.NearDof, icon = 'left-right', description = 'Ajusta a distância do foco próximo.'},
    {label = 'Profundidade de Campo - Distante', values = Config.FarDof, icon = 'left-right', description = 'Ajusta a distância do foco distante.'},
    {label = 'Profundidade de Campo', values = Config.StrengthDof, icon = 'left-right', description = 'Ajusta a intensidade do efeito de profundidade de campo.'},
}

    }, function(selected, scrollIndex, args)
        if selected == 2 then
            ClearTimecycleModifier()
            currFilter = 1
        end
    end)
    lib.showMenu('cinematic_cam_menu')
end)

AddEventHandler('gameEventTriggered', function(event, data)
    if event ~= 'CEventNetworkEntityDamage' then return end
    local victim, victimDied = data[1], data[4]
    if not IsPedAPlayer(victim) then return end
    if victimDied and NetworkGetPlayerIndexFromPed(victim) == cache.playerId and (IsPedDeadOrDying(victim, true) or IsPedFatallyInjured(victim)) then
        if DoesCamExist(FREE_CAM) then
            resetEverything()
        end
    end
end)
