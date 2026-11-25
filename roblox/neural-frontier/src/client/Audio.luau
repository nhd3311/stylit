-- Hệ thống âm thanh chạy ở máy người chơi (ModuleScript):
--   • 2 SoundGroup "Music" và "SFX" trong SoundService; âm lượng = gốc (AudioConfig.Groups) x thanh chỉnh 0..1
--   • Audio.Play(name, opts): hiệu ứng 2D (giao diện) hoặc 3D (có opts.position). Có pool Sound tái dùng,
--     giới hạn tần suất (throttle), lệch cao độ ngẫu nhiên, dọn Sound thừa khi rảnh
--   • Audio.SetArea(areaId): nhạc nền theo khu vực, chuyển mượt ~1.5s, lặp vô hạn
--   • Audio.PushBossMusic(on): ghi đè bằng nhạc boss khi đang đánh boss
--   • Audio.AutoTrack(): (tuỳ chọn) tự nhận khu vực từ vị trí nhân vật, tự bật nhạc boss khi lại gần boss,
--     phát tiếng Warp khi bị dịch chuyển
-- id = 0 / rỗng thì im lặng, không báo lỗi. Gọi Play/SetArea trước Start cũng được (tự Start).

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("AudioConfig"))
local Config = require(Shared:WaitForChild("Config"))

local Audio = {}

local UNKNOWN_LENGTH = 1.5 -- giây coi như "đang bận" khi Sound chưa tải xong (chưa biết độ dài)
local IDLE_TRIM = 20 -- Sound phụ rảnh quá số giây này thì bị huỷ
local RESTART = { Boss = true, Event = true } -- các bài phát lại từ đầu mỗi lần bật (bài vùng thì phát tiếp chỗ cũ)

local started = false
local tracking = false
local groups = {} -- { Music = SoundGroup, SFX = SoundGroup }
local multipliers = { music = 1, sfx = 1 } -- thanh chỉnh của người chơi (0..1)
local sfxFolder = nil -- Folder trong SoundService: Sound mẫu + Sound 2D
local musicFolder = nil -- Folder trong SoundService: các bài nhạc
local emitter = nil -- Part neo vô hình ở gốc toạ độ, mỗi âm 3D là 1 Attachment trên part này
local templates = {} -- [name] = Sound mẫu (chỉ tạo khi id hợp lệ)
local pools = {} -- [name .. "|2D" hoặc "|3D"] = { voice, ... }
local lastPlayed = {} -- [name] = os.clock() lần phát gần nhất
local warned = {} -- tên SFX lạ đã cảnh báo (chỉ in trong Studio)
local music = { area = nil, boss = false, current = nil, tracks = {} } -- tracks[name] = { name, sound, tween }

-- ================= Tiện ích =================

-- id trong config -> chuỗi content hợp lệ, hoặc nil nếu chưa điền
local function contentId(id)
	if type(id) == "number" then
		if id > 0 then
			return "rbxassetid://" .. string.format("%.0f", math.floor(id))
		end
		return nil
	elseif type(id) == "string" and id ~= "" and id ~= "0" then
		if id:match("^%d+$") then
			return "rbxassetid://" .. id
		end
		return id
	end
	return nil
end

local function clamp01(v, fallback)
	if type(v) ~= "number" or v ~= v then
		return fallback
	end
	return math.clamp(v, 0, 1)
end

-- chạy hàm trong pcall; lỗi chỉ in ra khi test trong Studio, không bao giờ làm hỏng game
local function safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and RunService:IsStudio() then
		warn("[Audio]", err)
	end
end

local function applyVolumes()
	local base = AudioConfig.Groups or {}
	if groups.Music then
		groups.Music.Volume = (base.Music or 1) * multipliers.music
	end
	if groups.SFX then
		groups.SFX.Volume = (base.SFX or 1) * multipliers.sfx
	end
end

-- dùng lại SoundGroup có sẵn cùng tên (nếu ai đó đã đặt trong Studio), không thì tạo mới
local function makeGroup(name)
	local group = SoundService:FindFirstChild(name)
	if not (group and group:IsA("SoundGroup")) then
		group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = SoundService
	end
	return group
end

local function makeFolder(name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = SoundService
	return folder
end

-- ================= Hiệu ứng (SFX) =================

local function buildTemplate(name, def)
	local id = contentId(def.id)
	if not id then
		return nil
	end
	local rollOff = AudioConfig.RollOff or {}
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = def.volume or 0.5
	sound.Looped = false
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = rollOff.min or 12
	sound.RollOffMaxDistance = rollOff.max or 160
	sound.SoundGroup = groups.SFX
	sound.Parent = sfxFolder
	return sound
end

-- 1 "giọng" = 1 bản sao Sound; âm 3D gắn vào Attachment riêng trên emitter
local function newVoice(name, template, spatial)
	local sound = template:Clone()
	sound.SoundGroup = groups.SFX
	local voice = { sound = sound, attachment = nil, busyUntil = 0, startedAt = 0, lastUsed = os.clock() }
	if spatial then
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Parent = emitter
		sound.Parent = attachment
		voice.attachment = attachment
	else
		sound.Parent = sfxFolder
	end
	sound.Ended:Connect(function()
		voice.busyUntil = 0
	end)
	return voice
end

-- lấy 1 giọng rảnh; đầy thì tạo thêm tới `maxVoices`; vẫn đầy thì cắt giọng cũ nhất để phát lại
local function takeVoice(name, template, spatial, maxVoices)
	local key = name .. (if spatial then "|3D" else "|2D")
	local pool = pools[key]
	if not pool then
		pool = {}
		pools[key] = pool
	end
	local now = os.clock()
	local oldest = nil
	for _, voice in pool do
		if now >= voice.busyUntil then
			return voice
		end
		if oldest == nil or voice.startedAt < oldest.startedAt then
			oldest = voice
		end
	end
	if #pool < maxVoices then
		local voice = newVoice(name, template, spatial)
		table.insert(pool, voice)
		return voice
	end
	return oldest
end

-- huỷ các giọng phụ đã rảnh lâu (mỗi pool luôn giữ lại giọng đầu tiên)
local function trimPools()
	local now = os.clock()
	for _, pool in pools do
		for i = #pool, 2, -1 do
			local voice = pool[i]
			if now >= voice.busyUntil and now - voice.lastUsed > IDLE_TRIM then
				table.remove(pool, i)
				if voice.attachment then
					voice.attachment:Destroy()
				else
					voice.sound:Destroy()
				end
			end
		end
	end
end

local function playSfx(name, opts)
	if type(name) ~= "string" then
		return
	end
	Audio.Start()
	local def = AudioConfig.SFX[name]
	if not def then
		if not warned[name] and RunService:IsStudio() then
			warned[name] = true
			warn("[Audio] Unknown sound name: " .. name)
		end
		return
	end
	local template = templates[name]
	if not template then
		return -- id = 0: chưa chọn âm thanh, im lặng
	end
	local now = os.clock()
	if now - (lastPlayed[name] or -math.huge) < (def.throttle or AudioConfig.DefaultThrottle or 0) then
		return
	end
	lastPlayed[name] = now

	if type(opts) ~= "table" then
		opts = {}
	end
	local position = opts.position
	local spatial = typeof(position) == "Vector3"
	local voice = takeVoice(name, template, spatial, math.max(1, def.voices or AudioConfig.DefaultVoices or 4))
	if not voice then
		return
	end
	local sound = voice.sound
	local variance = def.pitchVariance or 0
	local pitch = if type(opts.pitch) == "number" then opts.pitch else 1
	local volume = if type(opts.volume) == "number" then opts.volume else 1
	sound.PlaybackSpeed = math.clamp(pitch * (1 + (math.random() * 2 - 1) * variance), 0.1, 4)
	sound.Volume = math.clamp((def.volume or 0.5) * volume, 0, 10)
	if voice.attachment then
		voice.attachment.Position = emitter.CFrame:PointToObjectSpace(position)
	end
	sound.TimePosition = 0
	sound:Play()
	voice.startedAt = now
	voice.lastUsed = now
	local length = sound.TimeLength
	voice.busyUntil = now + (if length > 0 then length / sound.PlaybackSpeed else UNKNOWN_LENGTH) + 0.05
end

-- ================= Nhạc nền =================

local function hasTrack(name)
	local def = name and AudioConfig.Music[name]
	return def ~= nil and contentId(def.id) ~= nil
end

-- tạo Sound của 1 bài khi cần (nil nếu bài chưa có id)
local function getTrack(name)
	local track = music.tracks[name]
	if track then
		return track
	end
	local def = AudioConfig.Music[name]
	local id = def and contentId(def.id)
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = groups.Music
	sound.Parent = musicFolder
	track = { name = name, sound = sound, tween = nil }
	music.tracks[name] = track
	return track
end

local function fadeTrack(track, target, onDone)
	if track.tween then
		track.tween:Cancel()
	end
	local info = TweenInfo.new(AudioConfig.CrossfadeTime or 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local tween = TweenService:Create(track.sound, info, { Volume = target })
	track.tween = tween
	if onDone then
		tween.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed then
				onDone()
			end
		end)
	end
	tween:Play()
end

-- bài cần phát lúc này: boss (nếu đang bật và có id) > khu vực > bài dự phòng > im lặng
local function desiredTrack()
	if music.boss and hasTrack("Boss") then
		return "Boss"
	end
	local area = music.area or "Hub"
	if hasTrack(area) then
		return area
	end
	local fallback = AudioConfig.MusicFallback
	if fallback and hasTrack(fallback) then
		return fallback
	end
	return nil
end

local function refreshMusic()
	local want = desiredTrack()
	if want == music.current then
		return
	end
	-- bài cũ: nhỏ dần rồi tạm dừng (giữ vị trí để lần sau phát tiếp)
	local old = music.current and music.tracks[music.current]
	if old then
		fadeTrack(old, 0, function()
			if music.current ~= old.name then
				old.sound.Playing = false
			end
		end)
	end
	music.current = want
	local track = want and getTrack(want)
	if track then
		if not track.sound.Playing then
			if RESTART[want] then
				track.sound.TimePosition = 0
			end
			track.sound.Playing = true
		end
		fadeTrack(track, AudioConfig.Music[want].volume or 0.35)
	end
end

-- ================= Tải trước =================

local function preload()
	local sfx = {}
	for _, sound in templates do
		table.insert(sfx, sound)
	end
	if #sfx > 0 then
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(sfx)
		end)
		if not ok and RunService:IsStudio() then
			warn("[Audio] SFX preload failed:", err)
		end
	end
	-- nhạc nặng hơn nên nạp sau hiệu ứng
	local tracks = {}
	for name in AudioConfig.Music do
		local track = getTrack(name)
		if track then
			table.insert(tracks, track.sound)
		end
	end
	if #tracks > 0 then
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(tracks)
		end)
		if not ok and RunService:IsStudio() then
			warn("[Audio] Music preload failed:", err)
		end
	end
end

-- ================= API =================

function Audio.Start()
	if started then
		return
	end
	started = true
	groups.Music = makeGroup("Music")
	groups.SFX = makeGroup("SFX")
	applyVolumes()
	sfxFolder = makeFolder("AudioSFX")
	musicFolder = makeFolder("AudioMusic")

	emitter = Instance.new("Part")
	emitter.Name = "AudioEmitter"
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.CastShadow = false
	emitter.Transparency = 1
	emitter.Size = Vector3.one * 0.2
	emitter.CFrame = CFrame.new()
	emitter.Parent = workspace

	for name, def in AudioConfig.SFX do
		templates[name] = buildTemplate(name, def)
	end

	task.spawn(safe, preload)
	task.spawn(function()
		while true do
			task.wait(10)
			safe(trimPools)
		end
	end)
end

-- opts = { volume = hệ số (mặc định 1), pitch = hệ số cao độ (mặc định 1), position = Vector3 cho âm 3D }
function Audio.Play(name, opts)
	safe(playSfx, name, opts)
end

-- areaId: "Hub", "Habitat", "Event" hoặc id vùng trong Config.Zones; nil = "Hub"
function Audio.SetArea(areaId)
	Audio.Start()
	if type(areaId) ~= "string" or areaId == "" then
		areaId = "Hub"
	end
	if areaId == music.area then
		return
	end
	music.area = areaId
	safe(refreshMusic)
end

-- true: chuyển sang nhạc boss; false: quay về nhạc khu vực
function Audio.PushBossMusic(on)
	Audio.Start()
	on = on == true
	if on == music.boss then
		return
	end
	music.boss = on
	safe(refreshMusic)
end

function Audio.SetMusicVolume(v)
	multipliers.music = clamp01(v, multipliers.music)
	applyVolumes()
end

function Audio.SetSfxVolume(v)
	multipliers.sfx = clamp01(v, multipliers.sfx)
	applyVolumes()
end

-- { music = 0..1, sfx = 0..1 }
function Audio.GetVolumes()
	return { music = multipliers.music, sfx = multipliers.sfx }
end

-- khu vực tại 1 vị trí: "Event" (sàn Glitch Floor) / "Habitat" / id vùng / "Hub"
function Audio.AreaAt(position)
	if typeof(position) ~= "Vector3" then
		return "Hub"
	end
	local e = Config.Event
	if e and e.ArenaCenter then
		local half = (e.Grid or 9) * (e.TileSize or 8) / 2 + 8
		local d = position - e.ArenaCenter
		if math.abs(d.X) <= half and math.abs(d.Z) <= half and d.Y > -30 then
			return "Event"
		end
	end
	local h = Config.Habitat
	if h and h.Center then
		local d = position - h.Center
		if math.abs(d.X) <= h.SizeX / 2 and math.abs(d.Z) <= h.SizeZ / 2 then
			return "Habitat"
		end
	end
	local zone = Config.ZoneAt(position)
	return if zone then zone.id else "Hub"
end

-- Tự theo dõi nhân vật: đổi nhạc theo khu vực, bật nhạc boss khi boss (workspace.Enemies) ở gần,
-- phát "Warp" khi vị trí nhảy xa (Warp, vào/ra Glitch Floor). Gọi 1 lần; gọi lại không sao.
function Audio.AutoTrack()
	Audio.Start()
	if tracking then
		return
	end
	tracking = true
	local bossNames = {}
	for _, zone in Config.Zones do
		if zone.boss and zone.boss.name then
			bossNames[zone.boss.name] = true
		end
	end
	local lastRoot, lastPos, lastBoss = nil, nil, false
	local function step()
		local player = Players.LocalPlayer
		local character = player and player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local pos = root.Position
		-- cùng 1 nhân vật mà nhảy xa trong 1 nhịp = bị dịch chuyển (hồi sinh là nhân vật mới nên không tính)
		if root == lastRoot and lastPos and (pos - lastPos).Magnitude > (AudioConfig.WarpDistance or 80) then
			Audio.Play("Warp")
		end
		lastRoot, lastPos = root, pos
		Audio.SetArea(Audio.AreaAt(pos))
		local near = false
		local enemies = workspace:FindFirstChild("Enemies")
		if enemies then
			local range = AudioConfig.BossMusicRange or 90
			for _, body in enemies:GetChildren() do
				if bossNames[body.Name] and body:IsA("BasePart") and (body.Position - pos).Magnitude <= range then
					near = true
					break
				end
			end
		end
		-- chỉ gọi khi đổi trạng thái để không đè lệnh PushBossMusic gọi tay
		if near ~= lastBoss then
			lastBoss = near
			Audio.PushBossMusic(near)
		end
	end
	task.spawn(function()
		while true do
			safe(step)
			task.wait(AudioConfig.TrackInterval or 0.25)
		end
	end)
end

return Audio
