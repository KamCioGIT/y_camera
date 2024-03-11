local cam
local inCam = false
local cameraProp
local FOV_MAX = 80.0
local FOV_MIN = 7.5
local ZOOM_SPEED = 10.0
local fov = (FOV_MAX + FOV_MIN) * 0.5
local pitch = 0.0

local function helpText()
    SetTextComponentFormat("STRING")
    AddTextComponentString(locale('help.exit')..': ~INPUT_CELLPHONE_CANCEL~\n'..locale('help.take')..': ~INPUT_CELLPHONE_SELECT~');
    DisplayHelpTextFromStringLabel(0, false, true, 1)
end

local function takePicture()
    SendNUIMessage({
        message = 'camera',
        toggle = false
    })
    Wait(10)
    local tookPic = lib.callback.await('qbx_camera:server:takePicture', false)
    if not tookPic then
        exports.qbx_core:Notify(locale('error.takePicture'), 'error')
    end
end

local function HandleZoom()
    if IsControlJustPressed(0, 241) then
        fov = math.max(fov - ZOOM_SPEED, FOV_MIN)
    end
    if IsControlJustPressed(0, 242) then
        fov = math.min(fov + ZOOM_SPEED, FOV_MAX)
    end

    local current_fov = GetCamFov(cam)
    if math.abs(fov - current_fov) < 0.1 then
        fov = current_fov
    end
    SetCamFov(cam, current_fov + (fov - current_fov) * 0.05)
end

local function resetCamera()
    SendNUIMessage({
        message = 'camera',
        toggle = false
    })
    inCam = false
    DestroyCam(cam, false)
    cam = nil
    RenderScriptCams(false, false, 0, true, false)
    DeleteObject(cameraProp)
    cameraProp = nil
    ClearPedTasks(cache.ped)
    DisplayHud(true)
    DisplayRadar(true)
    ClearTimecycleModifier()
end

local function handleCameraControls()
    local multiplier = fov / 50
    local heading = GetEntityHeading(cache.ped) + (0 - GetControlNormal(2, 1) * (5 * multiplier))
    SetEntityHeading(cache.ped, heading)
    pitch += (0 - GetControlNormal(2, 2) * (5 * multiplier))
    pitch = math.clamp(pitch, -90.0, 90.0)
    SetCamRot(cam, pitch, 0.0, heading, 2)
end

local function openCamera()
    SetNuiFocus(false, false)
    DisplayHud(false);
    DisplayRadar(false);
    inCam = true
    SetTimecycleModifier("default")
    lib.requestAnimDict("amb@world_human_paparazzi@male@base", 1500)
    TaskPlayAnim(cache.ped, "amb@world_human_paparazzi@male@base", "base", 2.0, 2.0, -1, 51, 1, false, false, false)

    local coords = GetEntityCoords(cache.ped)
    cameraProp = CreateObject(`prop_pap_camera_01`, coords.x, coords.y, coords.z + 0.2, true, true, true)

    AttachEntityToEntity(cameraProp, cache.ped, GetPedBoneIndex(cache.ped, 28422), 0, 0, 0, 0, 0, 0, true, false, false, false, 2, true)
    cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    AttachCamToEntity(cam, cameraProp, 0.075, -0.30, 0, true)
    SetCamRot(cam, 0.0, 0.0, GetEntityHeading(cameraProp) / 360, 2)
    SetCamFov(cam, fov)
    RenderScriptCams(true, false, 0, true, false)

    SendNUIMessage({
        message = 'camera',
        toggle = true
    })

    CreateThread(function()
        while inCam do
            if IsEntityDead(cache.ped) then
                resetCamera()
                break
            end
            helpText()
            handleCameraControls()
            HandleZoom()
            if IsControlJustPressed(1, 176) or IsControlJustPressed(1, 24) then
                inCam = false
                qbx.playAudio({
                    audioName = 'Camera_Shoot',
                    audioRef = 'Phone_Soundset_Franklin',
                    source = cameraProp
                })
                takePicture()
                resetCamera()
            elseif IsControlJustPressed(1, 194) then
                resetCamera()
            end
            Wait(0)
        end
    end)
end

RegisterNetEvent('qbx_camera:client:openCamera', function()
    if inCam then return end
    openCamera()
end)

RegisterNetEvent('qbx_camera:client:openPhoto', function(source, data)
    SendNUIMessage({
        message = 'photo',
        toggle = true,
        source = source,
        title = data.title,
        subText = data.description
    })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('closePhoto', function()
    SetNuiFocus(false, false)
    SendNUIMessage({
        message = 'photo',
        toggle = false
    })
end)

local function editPicture(slot)
    local items = exports.ox_inventory:GetPlayerItems()
    local slotData = items[slot]
    if not slotData then return end

    local input = lib.inputDialog(locale('input.title'), {
        {type = 'input', label = locale('input.photoTitle'), required = false, min = 0, max = 32, value = slotData.metadata.title or ''},
        {type = 'input', label = locale('input.description'), required = false, min = 0, max = 128, value = slotData.metadata.description or ''}
    })

    if not input then return end
    if lib.callback.await('qbx_camera:server:editItem', false, slot, input) then
        exports.qbx_core:Notify(locale('success.edited'), 'success')
    else
        exports.qbx_core:Notify(locale('error.edit'), 'error')
    end
end
exports('EditPicture', editPicture)

local function copyURL(slot)
    local items = exports.ox_inventory:GetPlayerItems()
    local slotData = items[slot]
    if not slotData then return end
    local url = slotData.metadata.source
    if url then
        lib.setClipboard(url)
        exports.qbx_core:Notify(locale('success.copied'), 'success')
    end
end
exports('CopyURL', copyURL)