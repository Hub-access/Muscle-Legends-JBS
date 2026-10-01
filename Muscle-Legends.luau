-- Blank-Hub / Muscle Legends：可读命名与中文注释版 v4。
-- 本文件由 v3 重建源码作局部变量改名、添加注释得到；不是作者原稿。
-- 名称按已知用途重建；temporaryValue / capturedValue 等表示用途仍未确定。
-- 同义名称末尾的数字用于区分不同词法作用域，不是游戏数据编号。
-- 校验：去除位置、调试名称并规范化局部绑定后的语法树应与 v3 完全一致。
-- 游戏实测状态见“验证说明.txt”；离线对照不能代替真实游戏功能验证。

-- Reconstructed native Luau; original names/comments are unavailable.
-- Validation and remaining helper details: see verification.json.

-- [重建注释] 重建辅助：把泛型迭代器包装为可继续调用的函数；首个返回值表示本轮是否存在。
local function makeResumableIterator(...)
    local advance = coroutine.wrap(function(...)
        coroutine.yield()

        for key, value in ... do
            coroutine.yield(true, key, value)
        end
    end)

    advance(...)
    return advance
end

-- [重建注释] 重建辅助：闭包共享的可变存储单元。编号不是功能编号；部分单元在不同阶段被复用。
local sharedCells

sharedCells = {
	[47] = {},
	[48] = {},
	[73] = {},
	[76] = {},
	[77] = {},
	[78] = {},
	[85] = {},
	[92] = {},
	[93] = {},
	[113] = {},
	[120] = {},
	[137] = {},
	[138] = {},
	[139] = {},
	[145] = {},
	[146] = {},
	[147] = {},
	[148] = {},
	[150] = {},
	[151] = {},
	[158] = {},
	[159] = {},
	[187] = {},
	[188] = {},
	[189] = {},
	[190] = {},
	[239] = {},
}

local mainWindow

-- [重建注释] 界面初始化：下载并执行原脚本引用的 WindUI，再创建窗口和卡密配置。外部库随上游更新。
do
	local compileSource = loadstring
	local uiDownloadResults, uiDownloadResultCount = (function(...) return {...}, select("#", ...) end)(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))
	local windUI = compileSource(table.unpack(uiDownloadResults, 1, uiDownloadResultCount))()
	local createWindow = windUI.CreateWindow

	local windowOptions = {
		Title = "空白-力量传奇",
		Author = "脚本群1126600419",
		Icon = "layout-grid",
		Folder = "WindUI_Empty",
		Size = UDim2.fromOffset(520, 400),
		ToggleKey = Enum.KeyCode.RightShift,
		Transparent = true,
		Resizable = true,
		OpenButton = { Title = "空白脚本", Icon = "layout-grid", Enabled = true },
	}

	local keySystem = {}
	local accessKeys = table.create(1)
	accessKeys[1] = "空白"
	keySystem.Key = accessKeys
	keySystem.Note = "请输入卡密\n获取卡密请加QQ群 1126600419"
	keySystem.SaveKey = false
	windowOptions.KeySystem = keySystem
	mainWindow = createWindow(windUI, windowOptions)
end

task.wait(0.5)

-- [重建注释] 外观处理：遍历界面后代，将 UIStroke 设为白色，并移除其渐变。
do
	local hui = gethui

	if hui then
		hui = gethui()
	end

	hui = hui or game:GetService("CoreGui")
	local nextEntry = next
	local descendants, temporaryValue = hui:GetDescendants()

	for k, entryValue in nextEntry, descendants, temporaryValue do
		local entryValue2 = entryValue

		if entryValue2:IsA("UIStroke") then
			entryValue2.Color = Color3.new(1, 1, 1)
			local uiGradient = entryValue2:FindFirstChildOfClass("UIGradient")

			if uiGradient then
				uiGradient:Destroy()
			end
		end
	end
end

-- [重建注释] 信息页：保留原脚本的署名、联系按钮和更新记录；这些字符串不构成原创归属证明。
do
	local informationTab = mainWindow:Tab({ Title = "信息", Icon = "info" })
	informationTab:Select()
	informationTab:Paragraph({ Title = "Blank script", Desc = "此脚本由多罗猫和程子乐制作", Icon = "info" })
	local paragraph = informationTab.Paragraph
	local contactParagraphOptions = { Title = "更多信息", Desc = "点击按钮复制内容", Icon = "external-link" }
	local contactButtons = table.create(2)

	contactButtons[1] = {
		Title = "作者QQ",
		Icon = "copy",
		Callback = function()
			setclipboard("多罗猫2361913741 程子乐3277202938")
		end,
	}

	contactButtons[2] = {
		Title = "脚本群",
		Icon = "copy",
		Callback = function()
			setclipboard("QQ群1126600419")
		end,
	}

	contactParagraphOptions.Buttons = contactButtons
	paragraph(informationTab, contactParagraphOptions)
	local changelogSection = informationTab:Section({ Title = "9.24更新日志", Box = true, Opened = true })
	changelogSection:Section({ Title = "1.更换全新ui" })
	changelogSection:Section({ Title = "2.适配力量传奇最新版本" })
end

-- [重建注释] 取得游戏服务和本地玩家。后面的对象名、远程接口名均沿用原脚本。
local Players
Players = game:GetService("Players")
local ReplicatedStorage
ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace
Workspace = game:GetService("Workspace")
local UserInputService, localPlayer, playerReference, playersService, runService, getRootPart, teleportToCFrame, tapKey, muscleEvent, strength
local rebirths, kills, durability

do
	local RunService = game:GetService("RunService")
	local VirtualInputManager = game:GetService("VirtualInputManager")
	UserInputService = game:GetService("UserInputService")
	local VirtualUser = game:GetService("VirtualUser")
	localPlayer = Players.LocalPlayer
	playerReference = localPlayer
	playersService = Players
	runService = RunService
	local inputManager = VirtualInputManager

	-- [重建注释] 初始化行为：移除角色中的 bodyMovementScript，并在角色重新生成时再次处理。
	local removeBodyMovementScript
	do
		local capturedPlayerReference = playerReference
		removeBodyMovementScript = function()
			local character = capturedPlayerReference.Character

			if character then
				if character:FindFirstChild("bodyMovementScript") then
					character.bodyMovementScript:Destroy()
				end
			end
		end
	end

	removeBodyMovementScript()

	playerReference.CharacterAdded:Connect((function(capturedRemoveBodyMovementScript)
		return function()
			task.wait(0.3)
			capturedRemoveBodyMovementScript()
		end
	end)(removeBodyMovementScript))

	-- [重建注释] 移除当前以及后续加入的 RobloxForwardPortals 对象，连接保存在原有 _G.ads 字段。
	local function removeForwardPortalAds()
		local iteratePairs = pairs
		local descendants2 = game:GetDescendants()
		local iteratorNext, iteratorState, iteratorControl = iteratePairs(descendants2)

		for k, entryValue3 in iteratorNext, iteratorState, iteratorControl do
			local entryValue4 = entryValue3

			if entryValue4.Name == "RobloxForwardPortals" then
				entryValue4:Destroy()
			end
		end

		if _G.ads then
			_G.ads:Disconnect()
		end

		_G.ads = game.DescendantAdded:Connect(function(descendant)
			if descendant.Name == "RobloxForwardPortals" then
				descendant:Destroy()
			end
		end)
	end

	removeForwardPortalAds()

	-- [重建注释] 空闲事件：原逻辑通过输入服务短按 Y。这里只添加说明，不改变触发条件。
	playerReference.Idled:Connect((function(capturedInputManager)
		return function()
			capturedInputManager:SendKeyEvent(true, Enum.KeyCode.Y, false, game)
			task.wait(0.05)
			capturedInputManager:SendKeyEvent(false, Enum.KeyCode.Y, false, game)
		end
	end)(inputManager))

	-- [重建注释] 取得本地角色根部件；角色未就绪时返回 nil。
	getRootPart = (function(capturedPlayerReference2)
		return function()
			local character = capturedPlayerReference2.Character
			local humanoidRootPart = character

			if humanoidRootPart then
				humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			end

			return humanoidRootPart
		end
	end)(playerReference)

	-- [重建注释] 移动根部件前清零线速度和角速度；返回是否找到并移动了根部件。
	teleportToCFrame = (function(capturedGetRootPart)
		return function(cFrame)
			local temporaryValue2 = capturedGetRootPart()
			if not temporaryValue2 then
				return false
			end
			temporaryValue2.AssemblyLinearVelocity = Vector3.zero
			temporaryValue2.AssemblyAngularVelocity = Vector3.zero
			temporaryValue2.CFrame = cFrame
			return true
		end
	end)(getRootPart)

	-- [重建注释] 短按指定按键；输入操作的异常由原有 pcall 捕获。
	tapKey = (function(capturedInputManager2)
		return function(keyCode)
			pcall((function(capturedKeyCode)
				return function()
					capturedInputManager2:SendKeyEvent(true, capturedKeyCode, false, game)
					task.wait(0.05)
					capturedInputManager2:SendKeyEvent(false, capturedKeyCode, false, game)
				end
			end)(keyCode))
		end
	end)(inputManager)

	local leaderstats = localPlayer:WaitForChild("leaderstats")
	muscleEvent = localPlayer:WaitForChild("muscleEvent")
	strength = leaderstats:WaitForChild("Strength")
	rebirths = leaderstats:WaitForChild("Rebirths")
	kills = leaderstats:FindFirstChild("Kills") or localPlayer:FindFirstChild("Kills")
	durability = localPlayer:WaitForChild("Durability")
	local gems = localPlayer:FindFirstChild("Gems") or leaderstats:FindFirstChild("Gems")
	local brawls = leaderstats:FindFirstChild("Brawls") or localPlayer:FindFirstChild("Brawls")

	-- [重建注释] 宠物英文名称到中文显示名称的映射；未命中时由翻译函数返回原名称。
	local petNameTranslations = {
		["Apex Overlord"] = "顶峰霸主",
		["Titan Reactor"] = "泰坦反应堆",
		["Plasma Ravager"] = "等离子掠夺者",
		["Reactor Beast"] = "反应堆兽",
		["Volt Talon"] = "伏特爪",
		["Core Pup"] = "核心小狗",
		["Golden Viking"] = "金色维京人",
		["Muscle Sensei"] = "肌肉老师",
		["Neon Guardian"] = "霓虹守护者",
		["Darkstar Hunter"] = "暗星猎手",
		["Lightning Strike Phantom"] = "雷电幻影",
		["Frostwave Legends Penguin"] = "冰波传奇企鹅",
		["Phantom Genesis Dragon"] = "幻影创世龙",
		["Dark Legends Manticore"] = "黑暗蝎尾怪传奇",
		["Ultimate Supernova Pegasus"] = "终极新星飞马",
		["Aether Spirit Bunny"] = "以太仙灵小兔",
		["Cybernetic Showdown Dragon"] = "赛博龙",
		["Red Firecaster"] = "红色释火者",
		["White Pegasus"] = "白色飞马",
		["Golden Pheonix"] = "金色凤凰",
		["Infernal Dragon"] = "地狱火龙",
		["Red Dragon"] = "红色龙",
		["Purple Falcon"] = "紫色猎鹰",
		["Blue Firecaster"] = "蓝色释火者",
		["Yellow Butterfly"] = "黄色蝴蝶",
		["Purple Dragon"] = "紫色龙",
		["Orange Pegasus"] = "橙色飞马",
		["Blue Pheonix"] = "蓝色凤凰",
		["Silver Dog"] = "银色小狗",
		["Dark Golem"] = "黑暗魔像",
		["Green Butterfly"] = "绿色蝴蝶",
		["Crimson Falcon"] = "赤红猎鹰",
		["Orange Hedgehog"] = "橙色刺猬",
		["Blue Birdie"] = "蓝色小鸟",
		["Red Kitty"] = "红色小猫",
		["Blue Bunny"] = "蓝色小兔",
		["Dark Vampy"] = "黑暗德古拉",
		["Flaming Hedgehog"] = "火焰刺猬",
		["Omega Overlord"] = "欧米茄霸主",
		["Swift Samurai"] = "迅捷武士",
		["Powercore Hound"] = "能量核心猎犬",
		["Titanium Hydra"] = "钛金九头蛇",
		["Tribal Overlord"] = "部落霸主",
		["Inferno Unicorn"] = "炼狱独角兽",
		["Ethereal Emperor"] = "空灵帝王",
		["Eclipse Overlord"] = "日蚀霸主",
		["UFO-Drone"] = "UFO无人机",
		["Solar Dragon"] = "太阳龙",
		["RIDEABLE DRAGON MOUNT"] = "可骑乘龙坐骑",
		["Mythic Boss Pet"] = "神话首领宠物",
		["Legendary Boss Pet"] = "传说首领宠物",
		["Rainbow Boss Pet"] = "彩虹首领宠物",
		["Epic Boss Pet"] = "史诗首领宠物",
		["Rare Boss Pet"] = "稀有首领宠物",
		["Common Boss Pet"] = "普通首领宠物",
		["Mighty Monster"] = "强大怪物",
		["Small Fry"] = "小不点",
		["Wild Wizard"] = "狂野法师",
		["Chaos Sorcerer"] = "混乱巫师",
		["Ultra Birdie"] = "超级小鸟",
		["Magic Butterfly"] = "魔法蝴蝶",
		["White Pheonix"] = "白色凤凰",
		["Green Firecaster"] = "绿色释火者",
		["Green FireCaster"] = "绿色释火者",
		["Gold Warrior"] = "黄金战士",
		Moonlight = "月光",
		["Mushroom Sprout"] = "蘑菇苗",
		["Prismcore Hound"] = "棱镜核心猎犬",
		["Venom Bloom"] = "剧毒花",
		["Alien Buddy"] = "外星伙伴",
		["Cosmic Overlord"] = "宇宙霸主",
		Voidling = "虚空之子",
		["Jungle Captain"] = "丛林队长",
		["Mask Of Gold"] = "黄金面具",
		["Radio Rat"] = "收音机老鼠",
		["Cool Guy Larry"] = "酷哥拉里",
		["Golden Champion Phoenix"] = "黄金冠军凤凰",
		Hank = "汉克",
		["Screaming Bones"] = "尖叫骷髅",
		["Sky Hawk"] = "天空鹰",
		["Prismatic Chimera"] = "棱镜奇美拉",
		["Crowned Glory Seraph"] = "冠冕荣耀炽天使",
		["Eclipse Sovereign"] = "日蚀君王",
		["Flame Lord"] = "火焰领主",
		["Toxic Hound"] = "剧毒猎犬",
		["Nebula Lion"] = "星云狮",
		Chops = "肉排",
		["Inferno Drake"] = "炼狱龙",
		["Meteor Beast"] = "流星兽",
		["Planet Bull"] = "行星公牛",
		Blazestone = "焰石",
		["Pebble Dragon"] = "鹅卵石龙",
	}

	local translatePetName
	do
		local capturedPetNameTranslations = petNameTranslations
		translatePetName = function(petName)
			return capturedPetNameTranslations[petName] or petName
		end
	end

	-- [重建注释] 未解决的原行为：此函数只返回 nil，下方仍把它用于光环名称格式化。不能把它描述成有效的翻译表。
	local function unresolvedAuraNameLookup()
		return nil
	end

	local playerTab = mainWindow:Tab({ Title = "玩家", Icon = "user" })
	sharedCells[48][1] = nil

	-- [重建注释] 将统计数值缩写为 K/M/B/T/Qa/Qi。输入为空时按零处理。
	local function formatStatNumber(statValue)
		local n

		if not statValue then
			n = 0
		else
			n = statValue
			if n >= 1e18 then
				return string.format("%.2fQi", n / 1e18)
			end

			if n >= 1e15 then
				return string.format("%.2fQa", n / 1e15)
			end
		end

		if not (n >= 1e12) then
			if not (n >= 1e9) then
				if not (n >= 1000000) then
					if not (n >= 1000) then
						return string.format("%.0f", n)
					end
					return string.format("%.2fK", n / 1000)
				end

				return string.format("%.2fM", n / 1000000)
			end

			return string.format("%.2fB", n / 1e9)
		end

		return string.format("%.2fT", n / 1e12)
	end

	local consumableCatalog = table.create(8)
	consumableCatalog[1] = { eng = "Protein Egg", cn = "蛋" }
	consumableCatalog[2] = { eng = "Tropical Shake", cn = "热带奶昔" }
	consumableCatalog[3] = { eng = "Energy Shake", cn = "能量奶昔" }
	consumableCatalog[4] = { eng = "Protein Shake", cn = "蛋白质奶昔" }
	consumableCatalog[5] = { eng = "ULTRA Shake", cn = "超级奶昔" }
	consumableCatalog[6] = { eng = "Protein Bar", cn = "蛋白质棒" }
	consumableCatalog[7] = { eng = "Energy Bar", cn = "能量棒" }
	consumableCatalog[8] = { eng = "TOUGH Bar", cn = "健壮条" }

	-- [重建注释] 只统计容器直属子对象中名称完全匹配的数量。
	local function countNamedChildren(container, itemName)
		local n = 0
		if not container then
			return 0
		end
		local iterateArray = ipairs
		local children = container:GetChildren()
		local iteratorNext2, iteratorState2, iteratorControl2 = iterateArray(children)

		for k, entryValue5 in iteratorNext2, iteratorState2, iteratorControl2 do
			if entryValue5.Name == itemName then
				n += 1
			end
		end

		return n
	end

	-- [重建注释] 先统计背包和角色；二者总数为零时，再查询 consumablesFolder。
	local countPlayerConsumables
	do
		local capturedCountNamedChildren = countNamedChildren
		countPlayerConsumables = function(player, itemName2)
			if not player then
				return 0
			end
			local temporaryValue3 = capturedCountNamedChildren(player:FindFirstChild("Backpack"), itemName2)
			local temporaryValue4 = capturedCountNamedChildren(player.Character, itemName2)
			if temporaryValue3 + temporaryValue4 > 0 then
				return temporaryValue3 + temporaryValue4
			end
			return capturedCountNamedChildren(player:FindFirstChild("consumablesFolder"), itemName2)
		end
	end

	-- [重建注释] 按名称统计各子文件夹内的对象，用于宠物/光环信息汇总。
	local function countItemsInSubfolders(container2)
		local itemCountsByName = {}

		if container2 then
			local iterateArray2 = ipairs
			local children2 = container2:GetChildren()
			local iteratorNext3, iteratorState3, iteratorControl3 = iterateArray2(children2)

			for k, entryValue6 in iteratorNext3, iteratorState3, iteratorControl3 do
				local entryValue7 = entryValue6

				if entryValue7:IsA("Folder") then
					local iterateArray3 = ipairs
					local children3 = entryValue7:GetChildren()
					local iteratorNext4, iteratorState4, iteratorControl4 = iterateArray3(children3)

					for k2, entryValue8 in iteratorNext4, iteratorState4, iteratorControl4 do
						itemCountsByName[entryValue8.Name] = (itemCountsByName[entryValue8.Name] or 0) + 1
					end
				end
			end
		end

		return itemCountsByName
	end

	-- [重建注释] 把宠物数量整理成已排序的“名称 ×数量”文本列表。
	local formatPetCounts
	do
		local capturedTranslatePetName = translatePetName
		formatPetCounts = function(countsByName)
			local dataTable = {}
			local iteratorNext5, iteratorState5, iteratorControl5 = pairs(countsByName)

			for k, entryValue9 in iteratorNext5, iteratorState5, iteratorControl5 do
				local insert = table.insert
				local formattedText = string.format("%s ×%d", capturedTranslatePetName(k), entryValue9)
				insert(dataTable, formattedText)
			end

			table.sort(dataTable)
			return dataTable
		end
	end

	-- [重建注释] 光环数量文本：沿用 unresolvedAuraNameLookup 的 nil 返回行为，尚未修正该疑点。
	local formatAuraCounts
	do
		local capturedUnresolvedAuraNameLookup = unresolvedAuraNameLookup
		formatAuraCounts = function(countsByName2)
			local dataTable2 = {}
			local iteratorNext6, iteratorState6, iteratorControl6 = pairs(countsByName2)

			for k, entryValue10 in iteratorNext6, iteratorState6, iteratorControl6 do
				local insert = table.insert
				local formattedText2 = string.format("%s ×%d", capturedUnresolvedAuraNameLookup(k), entryValue10)
				insert(dataTable2, formattedText2)
			end

			table.sort(dataTable2)
			return dataTable2
		end
	end

	-- [重建注释] 按 consumableCatalog 的顺序生成玩家消耗品数量文本。
	local formatPlayerConsumables
	do
		local capturedConsumableCatalog, capturedCountPlayerConsumables = consumableCatalog, countPlayerConsumables
		formatPlayerConsumables = function(player2)
			local dataTable3 = {}
			local iteratorNext7, iteratorState7, iteratorControl7 = ipairs(capturedConsumableCatalog)
			local advanceIterator = makeResumableIterator(iteratorNext7, iteratorState7, iteratorControl7)

			while true do
				local packedReturns = table.pack(advanceIterator())

				if packedReturns[1] then
					local temporaryValue5 = packedReturns[3]
					local temporaryValue6 = capturedCountPlayerConsumables(player2, temporaryValue5.eng)

					if temporaryValue6 > 0 then
						local insert = table.insert
						local formattedText3 = string.format("%s ×%d", temporaryValue5.cn, temporaryValue6)
						insert(dataTable3, formattedText3)
					end
				else
					break
				end
			end

			return dataTable3
		end
	end

	-- [重建注释] 玩家设置：体型、速度、视野，以及赠送、消耗品和移动辅助开关。
	local playerControlsSection = playerTab:Section({ Title = "玩家功能", Box = true, Opened = false })

	local playerSettings = {
		Size = { Value = 2, Enabled = false },
		Speed = { Value = 120, Enabled = false },
		FOV = { Value = 70, Enabled = false },
	}

	local changeSpeedSizeRemote = ReplicatedStorage.rEvents:WaitForChild("changeSpeedSizeRemote")

	playerControlsSection:Input({
		Title = "体型大小",
		PlaceholderText = "输入体型",
		Callback = (function(capturedPlayerSettings)
			return function(callbackValue)
				local temporaryValue7 = string.gsub(callbackValue or "", "%s+", "")
				local value = tonumber(temporaryValue7)

				if value then
					if value > 0 then
						capturedPlayerSettings.Size.Value = value
					end
				end
			end
		end)(playerSettings),
	})

	playerControlsSection:Toggle({
		Title = "设置体型",
		Value = false,
		Callback = (function(capturedPlayerSettings2)
			return function(enabled)
				capturedPlayerSettings2.Size.Enabled = enabled
			end
		end)(playerSettings),
	})

	task.spawn((function(capturedPlayerSettings3, capturedLocalPlayer, capturedChangeSpeedSizeRemote)
		return function()
			while task.wait(0.01) do
				if capturedPlayerSettings3.Size.Enabled then
					local character = capturedLocalPlayer.Character

					if character then
						if character:FindFirstChildOfClass("Humanoid") then
							pcall(function()
								capturedChangeSpeedSizeRemote:InvokeServer("changeSize", capturedPlayerSettings3.Size.Value)
							end)
						end
					end
				end
			end
		end
	end)(playerSettings, localPlayer, changeSpeedSizeRemote))

	playerControlsSection:Divider()

	playerControlsSection:Input({
		Title = "移动速度",
		PlaceholderText = "输入速度",
		Callback = (function(capturedPlayerSettings4)
			return function(callbackValue2)
				local temporaryValue8 = string.gsub(callbackValue2 or "", "%s+", "")
				local value = tonumber(temporaryValue8)

				if value then
					if value > 0 then
						capturedPlayerSettings4.Speed.Value = value
					end
				end
			end
		end)(playerSettings),
	})

	playerControlsSection:Toggle({
		Title = "设置速度",
		Value = false,
		Callback = (function(capturedPlayerSettings5)
			return function(enabled)
				capturedPlayerSettings5.Speed.Enabled = enabled
			end
		end)(playerSettings),
	})

	sharedCells[73][1] = nil

	task.spawn((function(capturedSpeedConnectionCell, capturedPlayerSettings6, capturedLocalPlayer2, capturedChangeSpeedSizeRemote2)
		return function()
			capturedSpeedConnectionCell[1] = 486708

			while task.wait(0.01) do
				if capturedPlayerSettings6.Speed.Enabled then
					local character = capturedLocalPlayer2.Character

					if character then
						if character:FindFirstChildOfClass("Humanoid") then
							pcall(function()
								capturedChangeSpeedSizeRemote2:InvokeServer("changeSpeed", capturedPlayerSettings6.Speed.Value)
							end)
						end
					end
				end
			end
		end
	end)(sharedCells[73], playerSettings, localPlayer, changeSpeedSizeRemote))

	playerControlsSection:Divider()

	playerControlsSection:Input({
		Title = "视野范围",
		PlaceholderText = "1 - 120",
		Callback = (function(capturedPlayerSettings7)
			return function(callbackValue3)
				local temporaryValue9 = string.gsub(callbackValue3 or "", "%s+", "")
				local value = tonumber(temporaryValue9)

				if value then
					if value >= 1 then
						if value <= 120 then
							capturedPlayerSettings7.FOV.Value = value
						end
					end
				end
			end
		end)(playerSettings),
	})

	playerControlsSection:Toggle({
		Title = "设置视野",
		Value = false,
		Callback = (function(capturedPlayerSettings8, capturedWorkspace)
			return function(enabled)
				capturedPlayerSettings8.FOV.Enabled = enabled

				if capturedWorkspace.CurrentCamera then
					local currentCamera = capturedWorkspace.CurrentCamera
					local fieldOfView = enabled

					if fieldOfView then
						fieldOfView = capturedPlayerSettings8.FOV.Value
					end

					currentCamera.FieldOfView = fieldOfView or 70
				end
			end
		end)(playerSettings, Workspace),
	})

	task.spawn((function(capturedPlayerSettings9, capturedWorkspace2)
		return function()
			while task.wait(0.01) do
				if capturedPlayerSettings9.FOV.Enabled then
					if capturedWorkspace2.CurrentCamera then
						capturedWorkspace2.CurrentCamera.FieldOfView = capturedPlayerSettings9.FOV.Value
					end
				end
			end
		end
	end)(playerSettings, Workspace))

	playerControlsSection:Divider()
	-- [重建注释] 赠送相关状态：接收者名称、数量、启用标志分别保存在共享单元 76/77/78。
	sharedCells[76][1] = ""
	sharedCells[77][1] = 0
	sharedCells[78][1] = false

	local listGiftRecipientNames
	do
		local capturedPlayers, capturedLocalPlayer3 = Players, localPlayer
		listGiftRecipientNames = function()
			local dataTable4 = {}
			local iterateArray4 = ipairs
			local playerList = capturedPlayers:GetPlayers()
			local iteratorNext8, iteratorState8, iteratorControl8 = iterateArray4(playerList)

			for k, entryValue11 in iteratorNext8, iteratorState8, iteratorControl8 do
				local entryValue12 = entryValue11

				if entryValue12 ~= capturedLocalPlayer3 then
					table.insert(dataTable4, entryValue12.Name)
				end
			end

			table.sort(dataTable4)
			return dataTable4
		end
	end

	local giftRecipientDropdown = playerControlsSection:Dropdown({
		Title = "选择玩家",
		Multi = false,
		Value = "",
		AllowNone = true,
		Values = listGiftRecipientNames(),
		Callback = (function(capturedGiftRecipientCell)
			return function(callbackValue4)
				capturedGiftRecipientCell[1] = callbackValue4 or ""
			end
		end)(sharedCells[76]),
	})

	playerControlsSection:Input({
		Title = "送蛋数量",
		PlaceholderText = "输入数量",
		Callback = (function(capturedGiftAmountCell)
			return function(callbackValue5)
				capturedGiftAmountCell[1] = tonumber(callbackValue5) or 0
			end
		end)(sharedCells[77]),
	})

	-- [重建注释] 赠送循环沿用原有 giftRemote 调用和停止条件；本轮没有在真实账号上触发赠送。
	local sendProteinEggGifts
	do
		local capturedGiftingEnabledCell, capturedGiftAmountCell2, capturedPlayers2, capturedGiftRecipientCell2, capturedLocalPlayer4, capturedReplicatedStorage = sharedCells[78], sharedCells[77], Players, sharedCells[76], localPlayer, ReplicatedStorage
		sendProteinEggGifts = function()
			local n = 0

			if capturedGiftingEnabledCell[1] then
				if capturedGiftAmountCell2[1] > 0 then
					local temporaryValue10 = capturedPlayers2:FindFirstChild(capturedGiftRecipientCell2[1])
					local consumablesFolder = capturedLocalPlayer4:FindFirstChild("consumablesFolder")

					if consumablesFolder then
						while true do
							local proteinEgg = consumablesFolder:FindFirstChild("Protein Egg")
							local loopExitState = nil

							while true do
								if not temporaryValue10 then
									loopExitState = 1
								elseif not proteinEgg then
									loopExitState = 1
									break
								else
									pcall((function(capturedValue, capturedProteinEgg)
										return function()
											capturedReplicatedStorage.rEvents.giftRemote:InvokeServer("giftRequest", capturedValue, capturedProteinEgg)
										end
									end)(temporaryValue10, proteinEgg))

									n += 1
									task.wait(0.1)

									if capturedGiftingEnabledCell[1] then
										if n < capturedGiftAmountCell2[1] then
											temporaryValue10 = capturedPlayers2:FindFirstChild(capturedGiftRecipientCell2[1])
											consumablesFolder = capturedLocalPlayer4:FindFirstChild("consumablesFolder")
											proteinEgg = consumablesFolder

											if proteinEgg then
												loopExitState = 2
												break
											else
												continue
											end
										end
									end
								end

								break
							end

							if loopExitState == 1 then
								capturedGiftingEnabledCell[1] = false
								break
							elseif loopExitState == 2 then
								continue
							end

							break
						end
					else
						capturedGiftingEnabledCell[1] = false
					end
				end
			end

			capturedGiftingEnabledCell[1] = false
		end
	end

	playerControlsSection:Toggle({
		Title = "自动送蛋",
		Value = false,
		Callback = (function(capturedGiftingEnabledCell2, capturedGiftRecipientCell3, capturedGiftAmountCell3, capturedSendProteinEggGifts)
			return function(callbackValue6)
				capturedGiftingEnabledCell2[1] = callbackValue6

				if callbackValue6 then
					if capturedGiftRecipientCell3[1] == "" then
						capturedGiftingEnabledCell2[1] = false
					elseif not (capturedGiftAmountCell3[1] <= 0) then
						task.spawn(capturedSendProteinEggGifts)
					else
						capturedGiftingEnabledCell2[1] = false
					end
				end
			end
		end)(sharedCells[78], sharedCells[76], sharedCells[77], sendProteinEggGifts),
	})

	Players.PlayerAdded:Connect((function(capturedGiftRecipientDropdown, capturedListGiftRecipientNames)
		return function()
			task.wait(0.5)

			pcall(function()
				local capturedGiftRecipientDropdown2 = capturedGiftRecipientDropdown
				local refresh = capturedGiftRecipientDropdown.Refresh
				local returnValues, returnCount = (function(...) return {...}, select("#", ...) end)(capturedListGiftRecipientNames())
				refresh(capturedGiftRecipientDropdown2, table.unpack(returnValues, 1, returnCount))
			end)
		end
	end)(giftRecipientDropdown, listGiftRecipientNames))

	Players.PlayerRemoving:Connect((function(capturedGiftRecipientCell4, capturedGiftRecipientDropdown3, capturedListGiftRecipientNames2)
		return function(callbackValue7)
			if capturedGiftRecipientCell4[1] == callbackValue7.Name then
				capturedGiftRecipientCell4[1] = ""

				pcall(function()
					capturedGiftRecipientDropdown3:Set("")
				end)
			end

			task.wait(0.5)

			pcall(function()
				local capturedGiftRecipientDropdown4 = capturedGiftRecipientDropdown3
				local refresh = capturedGiftRecipientDropdown3.Refresh
				local returnValues2, returnCount2 = (function(...) return {...}, select("#", ...) end)(capturedListGiftRecipientNames2())
				refresh(capturedGiftRecipientDropdown4, table.unpack(returnValues2, 1, returnCount2))
			end)
		end
	end)(sharedCells[76], giftRecipientDropdown, listGiftRecipientNames))

	playerControlsSection:Divider()
	sharedCells[85][1] = false

	local runFortuneWheelLoop
	do
		local capturedFortuneWheelEnabledCell, capturedReplicatedStorage2 = sharedCells[85], ReplicatedStorage
		runFortuneWheelLoop = function()
			while capturedFortuneWheelEnabledCell[1] do
				task.wait()

				pcall(function()
					local fortuneWheel = capturedReplicatedStorage2.shared.catalogs.fortuneWheelChances:FindFirstChild("Fortune Wheel")

					if fortuneWheel then
						capturedReplicatedStorage2.rEvents.openFortuneWheelRemote:InvokeServer("openFortuneWheel", fortuneWheel)
					end
				end)
			end
		end
	end

	playerControlsSection:Toggle({
		Title = "自动转盘",
		Value = false,
		Callback = (function(capturedFortuneWheelEnabledCell2, capturedRunFortuneWheelLoop)
			return function(callbackValue8)
				capturedFortuneWheelEnabledCell2[1] = callbackValue8

				if callbackValue8 then
					task.spawn(capturedRunFortuneWheelLoop)
				end
			end
		end)(sharedCells[85], runFortuneWheelLoop),
	})

	-- [重建注释] 消耗品配置：每项保存工具名称和 muscleEvent 动作名称。
	local consumableUseActions = {}
	local entries = table.create(2)
	entries[1] = "Protein Bar"
	entries[2] = "proteinBar"
	consumableUseActions["蛋白质棒"] = entries
	local entries2 = table.create(2)
	entries2[1] = "Energy Bar"
	entries2[2] = "energyBar"
	consumableUseActions["能量棒"] = entries2
	local entries3 = table.create(2)
	entries3[1] = "TOUGH Bar"
	entries3[2] = "toughBar"
	consumableUseActions["健壮条"] = entries3
	local entries4 = table.create(2)
	entries4[1] = "Protein Shake"
	entries4[2] = "proteinShake"
	consumableUseActions["蛋白质奶昔"] = entries4
	local entries5 = table.create(2)
	entries5[1] = "ULTRA Shake"
	entries5[2] = "ultraShake"
	consumableUseActions["超级奶昔"] = entries5
	local entries6 = table.create(2)
	entries6[1] = "Energy Shake"
	entries6[2] = "energyShake"
	consumableUseActions["能量奶昔"] = entries6
	local entries7 = table.create(2)
	entries7[1] = "Tropical Shake"
	entries7[2] = "tropicalShake"
	consumableUseActions["热带奶昔"] = entries7
	local consumableUseOrder = table.create(7)
	consumableUseOrder[1] = "蛋白质棒"
	consumableUseOrder[2] = "能量棒"
	consumableUseOrder[3] = "健壮条"
	consumableUseOrder[4] = "蛋白质奶昔"
	consumableUseOrder[5] = "超级奶昔"
	consumableUseOrder[6] = "能量奶昔"
	consumableUseOrder[7] = "热带奶昔"
	sharedCells[92][1] = 1
	sharedCells[93][1] = false

	local runConsumableUseLoop
	do
		local capturedConsumableLoopEnabledCell, capturedConsumableIndexCell, capturedConsumableUseOrder, capturedConsumableUseActions, capturedLocalPlayer5, capturedVirtualUser, capturedWorkspace3, capturedMuscleEvent = sharedCells[93], sharedCells[92], consumableUseOrder, consumableUseActions, localPlayer, VirtualUser, Workspace, muscleEvent
		runConsumableUseLoop = function()
			if capturedConsumableLoopEnabledCell[1] then
				local loopEntryState

				if #capturedConsumableUseOrder < capturedConsumableIndexCell[1] then
					loopEntryState = 1
				else
					loopEntryState = 2
				end

				while true do
					if loopEntryState == 1 then
						capturedConsumableIndexCell[1] = 1
						loopEntryState = 2
						continue
					end

					local temporaryValue11 = capturedConsumableUseActions[capturedConsumableUseOrder[capturedConsumableIndexCell[1]]]
					local temporaryValue12 = capturedLocalPlayer5.Backpack:FindFirstChild(temporaryValue11[1])

					if temporaryValue12 then
						local character = capturedLocalPlayer5.Character

						if character then
							if character:FindFirstChildOfClass("Humanoid") then
								character.Humanoid:EquipTool(temporaryValue12)
								task.wait(0.1)
								local cFrame = capturedWorkspace3.CurrentCamera.CFrame
								capturedVirtualUser:Button1Down(Vector2.new(10, 10), cFrame)
								task.wait(0.05)
								local cFrame2 = capturedWorkspace3.CurrentCamera.CFrame
								capturedVirtualUser:Button1Up(Vector2.new(10, 10), cFrame2)
								task.wait(0.1)
								local temporaryValue13 = character:FindFirstChild(temporaryValue11[1])

								if temporaryValue13 then
									pcall((function(capturedValue2, capturedValue3)
										return function()
											capturedMuscleEvent:FireServer(capturedValue2[2], capturedValue3)
										end
									end)(temporaryValue11, temporaryValue13))
								end
							end
						end

						task.wait(0.1)
					else
						capturedConsumableIndexCell[1] += 1
						task.wait(0.2)
					end

					if capturedConsumableLoopEnabledCell[1] then
						if not (#capturedConsumableUseOrder < capturedConsumableIndexCell[1]) then
							loopEntryState = 2
						else
							loopEntryState = 1
						end

						continue
					end

					break
				end
			end
		end
	end

	playerControlsSection:Toggle({
		Title = "自动使用奶昔",
		Value = false,
		Callback = (function(capturedConsumableLoopEnabledCell2, capturedConsumableIndexCell2, capturedRunConsumableUseLoop)
			return function(callbackValue9)
				capturedConsumableLoopEnabledCell2[1] = callbackValue9

				if callbackValue9 then
					capturedConsumableIndexCell2[1] = 1
					task.spawn(capturedRunConsumableUseLoop)
				end
			end
		end)(sharedCells[93], sharedCells[92], runConsumableUseLoop),
	})

	playerControlsSection:Divider()
	-- [重建注释] 移动保护状态：防击飞与位置锁分别保存开关，位置锁额外保存目标位置。
	local movementProtectionSettings = { AntiFling = { Enabled = false }, PositionLock = { Enabled = false, Position = nil } }

	local applyAntiFling
	do
		local capturedLocalPlayer6, capturedMovementProtectionSettings = localPlayer, movementProtectionSettings
		applyAntiFling = function()
			local capturedLocalPlayer7 = capturedLocalPlayer6

			if capturedMovementProtectionSettings.AntiFling.Enabled then
				if capturedLocalPlayer7.Character then
					local humanoidRootPart = capturedLocalPlayer7.Character:FindFirstChild("HumanoidRootPart")

					if humanoidRootPart then
						if humanoidRootPart:FindFirstChild("BodyVelocity") then
							if humanoidRootPart.BodyVelocity.MaxForce == Vector3.new(100000, 0, 100000) then
								humanoidRootPart.BodyVelocity:Destroy()
							end
						end

						local bodyVelocity = Instance.new("BodyVelocity")
						bodyVelocity.MaxForce = Vector3.new(100000, 0, 100000)
						bodyVelocity.Velocity = Vector3.new(0, 0, 0)
						bodyVelocity.P = 1250
						bodyVelocity.Parent = humanoidRootPart
					end
				end
			end
		end
	end

	local removeAntiFlingVelocity
	do
		local capturedGetRootPart2 = getRootPart
		removeAntiFlingVelocity = function()
			local temporaryValue14 = capturedGetRootPart2()

			if temporaryValue14 then
				if temporaryValue14:FindFirstChild("BodyVelocity") then
					if temporaryValue14.BodyVelocity.MaxForce == Vector3.new(100000, 0, 100000) then
						temporaryValue14.BodyVelocity:Destroy()
					end
				end
			end
		end
	end

	playerControlsSection:Toggle({
		Title = "防击飞",
		Value = false,
		Callback = (function(capturedMovementProtectionSettings2, capturedApplyAntiFling, capturedRemoveAntiFlingVelocity)
			return function(enabled)
				capturedMovementProtectionSettings2.AntiFling.Enabled = enabled

				if enabled then
					capturedApplyAntiFling()
				else
					capturedRemoveAntiFlingVelocity()
				end
			end
		end)(movementProtectionSettings, applyAntiFling, removeAntiFlingVelocity),
	})

	localPlayer.CharacterAdded:Connect((function(capturedMovementProtectionSettings3, capturedApplyAntiFling2)
		return function()
			task.wait(0.5)

			if capturedMovementProtectionSettings3.AntiFling.Enabled then
				capturedApplyAntiFling2()
			end
		end
	end)(movementProtectionSettings, applyAntiFling))

	local applyPositionLock
	do
		local capturedApplyAntiFling3, capturedMovementProtectionSettings4, capturedGetRootPart3, capturedRemoveAntiFlingVelocity2 = applyAntiFling, movementProtectionSettings, getRootPart, removeAntiFlingVelocity
		applyPositionLock = function()
			capturedApplyAntiFling3()

			if capturedMovementProtectionSettings4.PositionLock.Enabled then
				if capturedMovementProtectionSettings4.PositionLock.Position then
					local temporaryValue15 = capturedGetRootPart3()

					if temporaryValue15 then
						if temporaryValue15:FindFirstChild("PositionLocker") then
							temporaryValue15.PositionLocker.Position = capturedMovementProtectionSettings4.PositionLock.Position
						else
							capturedRemoveAntiFlingVelocity2()
							local bodyPosition = Instance.new("BodyPosition")
							bodyPosition.Name = "PositionLocker"
							bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
							bodyPosition.Position = capturedMovementProtectionSettings4.PositionLock.Position
							bodyPosition.P = 100000
							bodyPosition.Parent = temporaryValue15
						end
					end
				end
			end
		end
	end

	local removePositionLock
	do
		local capturedGetRootPart4, capturedMovementProtectionSettings5 = getRootPart, movementProtectionSettings
		removePositionLock = function()
			local temporaryValue16 = capturedGetRootPart4()

			if temporaryValue16 then
				if temporaryValue16:FindFirstChild("PositionLocker") then
					temporaryValue16.PositionLocker:Destroy()
				end
			end

			capturedMovementProtectionSettings5.PositionLock.Position = nil
		end
	end

	playerControlsSection:Toggle({
		Title = "锁定位置",
		Value = false,
		Callback = (function(capturedMovementProtectionSettings6, capturedGetRootPart5, capturedApplyPositionLock, capturedRemovePositionLock)
			return function(enabled)
				capturedMovementProtectionSettings6.PositionLock.Enabled = enabled

				if enabled then
					local temporaryValue17 = capturedGetRootPart5()

					if temporaryValue17 then
						capturedMovementProtectionSettings6.PositionLock.Position = temporaryValue17.Position
					end

					capturedApplyPositionLock()
				else
					capturedRemovePositionLock()
				end
			end
		end)(movementProtectionSettings, getRootPart, applyPositionLock, removePositionLock),
	})

	task.spawn((function(capturedMovementProtectionSettings7, capturedApplyPositionLock2)
		return function()
			while task.wait(0.1) do
				if capturedMovementProtectionSettings7.PositionLock.Enabled then
					capturedApplyPositionLock2()
				end
			end
		end
	end)(movementProtectionSettings, applyPositionLock))

	-- [重建注释] 水面碰撞辅助：下方逻辑维护部件集合；开关改变这些部件的 CanCollide。
	local waterCollisionState = {
		Parts = {},
		PartSize = 2048,
		TotalDistance = 50000,
		StartPosition = Vector3.new(-2, -9.5, -2),
	}

	task.spawn((function(capturedWaterCollisionState, capturedWorkspace4)
		return function()
			local n = math.ceil(capturedWaterCollisionState.TotalDistance / capturedWaterCollisionState.PartSize) - 1 + 0
			local n2 = 0

			if n >= 0 then
				local n3 = 0
				local loopExitState2 = nil
				local n4, n5

				while true do
					n4 = math.ceil(capturedWaterCollisionState.TotalDistance / capturedWaterCollisionState.PartSize) - 1 + 0
					n5 = 0

					if n4 >= 0 then
						loopExitState2 = 1
					else
						n2 += 1
						if n2 <= n then
							n3 = n2
							continue
						end
					end

					break
				end

				if loopExitState2 == 1 then
					local n6 = 0
					local iterateArray5 = ipairs
					local entries8 = table.create(4)
					local entries9 = table.create(3)
					local n7 = 0 * capturedWaterCollisionState.PartSize
					entries9[1] = n3 * capturedWaterCollisionState.PartSize
					entries9[2] = n7
					entries9[3] = "Side_" .. n3 .. "_" .. 0
					local entries10 = table.create(3)
					local n8 = 0 * capturedWaterCollisionState.PartSize
					entries10[1] = -n3 * capturedWaterCollisionState.PartSize
					entries10[2] = n8
					entries10[3] = "LeftRight_" .. n3 .. "_" .. 0
					local entries11 = table.create(3)
					local n9 = 0 * capturedWaterCollisionState.PartSize
					entries11[1] = -n3 * capturedWaterCollisionState.PartSize
					entries11[2] = n9
					entries11[3] = "UpLeft_" .. n3 .. "_" .. 0
					local loopExitState3 = nil
					local advanceIterator2, temporaryValue18

					while true do
						local entries12 = table.create(3)
						local n10 = -n6 * capturedWaterCollisionState.PartSize
						entries12[1] = n3 * capturedWaterCollisionState.PartSize
						entries12[2] = n10
						entries12[3] = "UpRight_" .. n3 .. "_" .. n6
						entries8[1] = entries9
						entries8[2] = entries10
						entries8[3] = entries11
						entries8[4] = entries12
						local iteratorNext9, iteratorState9, iteratorControl9 = iterateArray5(entries8)
						advanceIterator2 = makeResumableIterator(iteratorNext9, iteratorState9, iteratorControl9)
						local temporaryValue19, temporaryValue20
						temporaryValue19, temporaryValue20, temporaryValue18 = advanceIterator2()

						if temporaryValue19 then
							loopExitState3 = 1
						else
							local loopExitState4 = nil

							while true do
								n5 += 1

								if n5 <= n4 then
									loopExitState4 = 1
								else
									n2 += 1

									if n2 <= n then
										n3 = n2
										n4 = math.ceil(capturedWaterCollisionState.TotalDistance / capturedWaterCollisionState.PartSize) - 1 + 0
										n5 = -1
										continue
									end
								end

								break
							end

							if loopExitState4 == 1 then
								n6 = n5
								iterateArray5 = ipairs
								entries8 = table.create(4)
								entries9 = table.create(3)
								local n11 = n6 * capturedWaterCollisionState.PartSize
								entries9[1] = n3 * capturedWaterCollisionState.PartSize
								entries9[2] = n11
								entries9[3] = "Side_" .. n3 .. "_" .. n6
								entries10 = table.create(3)
								local n12 = n6 * capturedWaterCollisionState.PartSize
								entries10[1] = -n3 * capturedWaterCollisionState.PartSize
								entries10[2] = n12
								entries10[3] = "LeftRight_" .. n3 .. "_" .. n6
								entries11 = table.create(3)
								local n13 = -n6 * capturedWaterCollisionState.PartSize
								entries11[1] = -n3 * capturedWaterCollisionState.PartSize
								entries11[2] = n13
								entries11[3] = "UpLeft_" .. n3 .. "_" .. n6
								continue
							end
						end

						break
					end

					if loopExitState3 == 1 then
						while true do
							local part = Instance.new("Part")
							part.Size = Vector3.new(capturedWaterCollisionState.PartSize, 1, capturedWaterCollisionState.PartSize)
							part.Position = capturedWaterCollisionState.StartPosition + Vector3.new(temporaryValue18[1], 0, temporaryValue18[2])
							part.Anchored = true
							part.Transparency = 1
							part.CanCollide = false
							part.Name = "Part_" .. temporaryValue18[3]
							part.Parent = capturedWorkspace4
							table.insert(capturedWaterCollisionState.Parts, part)
							local loopExitState5 = nil

							while true do
								local temporaryValue21, temporaryValue22
								temporaryValue21, temporaryValue22, temporaryValue18 = advanceIterator2()

								if temporaryValue21 then
									loopExitState5 = 1
								else
									local loopExitState6 = nil

									while true do
										n5 += 1

										if n5 <= n4 then
											loopExitState6 = 1
										else
											n2 += 1

											if n2 <= n then
												n3 = n2
												n4 = math.ceil(capturedWaterCollisionState.TotalDistance / capturedWaterCollisionState.PartSize) - 1 + 0
												n5 = -1
												continue
											end
										end

										break
									end

									if loopExitState6 == 1 then
										local iterateArray6 = ipairs
										local entries13 = table.create(4)
										local entries14 = table.create(3)
										local n10 = n5 * capturedWaterCollisionState.PartSize
										entries14[1] = n3 * capturedWaterCollisionState.PartSize
										entries14[2] = n10
										entries14[3] = "Side_" .. n3 .. "_" .. n5
										local entries15 = table.create(3)
										local n11 = n5 * capturedWaterCollisionState.PartSize
										entries15[1] = -n3 * capturedWaterCollisionState.PartSize
										entries15[2] = n11
										entries15[3] = "LeftRight_" .. n3 .. "_" .. n5
										local entries16 = table.create(3)
										local n12 = -n5 * capturedWaterCollisionState.PartSize
										entries16[1] = -n3 * capturedWaterCollisionState.PartSize
										entries16[2] = n12
										entries16[3] = "UpLeft_" .. n3 .. "_" .. n5
										local entries17 = table.create(3)
										local n13 = -n5 * capturedWaterCollisionState.PartSize
										entries17[1] = n3 * capturedWaterCollisionState.PartSize
										entries17[2] = n13
										entries17[3] = "UpRight_" .. n3 .. "_" .. n5
										entries13[1] = entries14
										entries13[2] = entries15
										entries13[3] = entries16
										entries13[4] = entries17
										local iteratorNext10, iteratorState10, iteratorControl10 = iterateArray6(entries13)
										advanceIterator2 = makeResumableIterator(iteratorNext10, iteratorState10, iteratorControl10)
										continue
									end
								end

								break
							end

							if loopExitState5 == 1 then
								continue
							end
							break
						end
					end
				end
			end
		end
	end)(waterCollisionState, Workspace))

	playerControlsSection:Toggle({
		Title = "水上行走",
		Value = false,
		Callback = (function(capturedWaterCollisionState2)
			return function(canCollide)
				local iteratorNext11, iteratorState11, iteratorControl11 = ipairs(capturedWaterCollisionState2.Parts)

				for k, entryValue13 in iteratorNext11, iteratorState11, iteratorControl11 do
					local entryValue14 = entryValue13

					if entryValue14 then
						if entryValue14.Parent then
							entryValue14.CanCollide = canCollide
						end
					end
				end
			end
		end)(waterCollisionState),
	})

	-- [重建注释] 跳跃连接存储；关闭无限跳跃时断开该连接。
	sharedCells[113][1] = nil

	playerControlsSection:Toggle({
		Title = "无限跳跃",
		Value = false,
		Callback = (function(capturedJumpConnectionCell, capturedUserInputService, capturedLocalPlayer8)
			return function(infiniteJump)
				_G.InfiniteJump = infiniteJump

				if infiniteJump then
					if not capturedJumpConnectionCell[1] then
						capturedJumpConnectionCell[1] = capturedUserInputService.JumpRequest:Connect(function()
							if _G.InfiniteJump then
								local character = capturedLocalPlayer8.Character
								local humanoid = character

								if humanoid then
									humanoid = character:FindFirstChildOfClass("Humanoid")
								end

								if humanoid then
									humanoid:ChangeState("Jumping")
								end
							end
						end)
					end
				elseif capturedJumpConnectionCell[1] then
					capturedJumpConnectionCell[1]:Disconnect()
					capturedJumpConnectionCell[1] = nil
				end
			end
		end)(sharedCells[113], UserInputService, localPlayer),
	})

	-- [重建注释] 自己/他人的数据面板：统计、宠物、光环和消耗品分别显示。
	local selfInfoSection = playerTab:Section({ Title = "自己", Box = true, Opened = false })
	local selfStatsParagraph = selfInfoSection:Paragraph({ Title = "数据：", Desc = "" })
	local selfPetsParagraph = selfInfoSection:Paragraph({ Title = "宠物：", Desc = "" })
	local selfAurasParagraph = selfInfoSection:Paragraph({ Title = "光环：", Desc = "" })
	local selfConsumablesParagraph = selfInfoSection:Paragraph({ Title = "奶昔：", Desc = "" })
	local otherPlayerInfoSection = playerTab:Section({ Title = "他人", Box = true, Opened = false })
	sharedCells[120][1] = nil

	local listOtherPlayerNames
	do
		local capturedPlayers3, capturedLocalPlayer9 = Players, localPlayer
		listOtherPlayerNames = function()
			local dataTable5 = {}
			local iterateArray7 = ipairs
			local playerList2 = capturedPlayers3:GetPlayers()
			local iteratorNext12, iteratorState12, iteratorControl12 = iterateArray7(playerList2)

			for k, entryValue15 in iteratorNext12, iteratorState12, iteratorControl12 do
				local entryValue16 = entryValue15

				if entryValue16 ~= capturedLocalPlayer9 then
					table.insert(dataTable5, entryValue16.Name)
				end
			end

			table.sort(dataTable5)
			return dataTable5
		end
	end

	local inspectedPlayerDropdown = otherPlayerInfoSection:Dropdown({
		Title = "选择玩家",
		Values = listOtherPlayerNames(),
		Value = "",
		AllowNone = true,
		Callback = (function(capturedInspectedPlayerCell, capturedPlayers4, capturedOtherInfoRefreshCell)
			return function(callbackValue10)
				local flag

				if callbackValue10 then
					flag = callbackValue10 ~= ""

					if flag then
						flag = capturedPlayers4:FindFirstChild(callbackValue10)
					end

					flag = flag or nil
				else
					flag = nil
				end

				capturedInspectedPlayerCell[1] = flag

				if capturedOtherInfoRefreshCell[1] then
					capturedOtherInfoRefreshCell[1]()
				end
			end
		end)(sharedCells[120], Players, sharedCells[48]),
	})

	local otherStatsParagraph = otherPlayerInfoSection:Paragraph({ Title = "数据：", Desc = "" })
	local otherPetsParagraph = otherPlayerInfoSection:Paragraph({ Title = "宠物：", Desc = "" })
	local otherAurasParagraph = otherPlayerInfoSection:Paragraph({ Title = "光环：", Desc = "" })
	local otherConsumablesParagraph = otherPlayerInfoSection:Paragraph({ Title = "奶昔：", Desc = "" })

	Players.PlayerAdded:Connect((function(capturedInspectedPlayerDropdown, capturedListOtherPlayerNames)
		return function()
			task.wait(0.5)

			pcall(function()
				local capturedInspectedPlayerDropdown2 = capturedInspectedPlayerDropdown
				local refresh = capturedInspectedPlayerDropdown.Refresh
				local returnValues3, returnCount3 = (function(...) return {...}, select("#", ...) end)(capturedListOtherPlayerNames())
				refresh(capturedInspectedPlayerDropdown2, table.unpack(returnValues3, 1, returnCount3))
			end)
		end
	end)(inspectedPlayerDropdown, listOtherPlayerNames))

	Players.PlayerRemoving:Connect((function(capturedInspectedPlayerCell2, capturedInspectedPlayerDropdown3, capturedListOtherPlayerNames2, capturedOtherInfoRefreshCell2)
		return function(callbackValue11)
			if capturedInspectedPlayerCell2[1] == callbackValue11 then
				capturedInspectedPlayerCell2[1] = nil

				pcall(function()
					capturedInspectedPlayerDropdown3:Set("")
				end)
			end

			task.wait(0.5)

			pcall(function()
				local capturedInspectedPlayerDropdown4 = capturedInspectedPlayerDropdown3
				local refresh = capturedInspectedPlayerDropdown3.Refresh
				local returnValues4, returnCount4 = (function(...) return {...}, select("#", ...) end)(capturedListOtherPlayerNames2())
				refresh(capturedInspectedPlayerDropdown4, table.unpack(returnValues4, 1, returnCount4))
			end)

			if capturedOtherInfoRefreshCell2[1] then
				capturedOtherInfoRefreshCell2[1]()
			end
		end
	end)(sharedCells[120], inspectedPlayerDropdown, listOtherPlayerNames, sharedCells[48]))

	-- [重建注释] 定义自身信息刷新函数并保存在共享单元 47。
	sharedCells[47][1] = (function(capturedSelfStatsParagraph, capturedFormatStatNumber, capturedStrength, capturedDurability, capturedRebirths, capturedKills, capturedBrawls, capturedGems, capturedCountItemsInSubfolders, capturedLocalPlayer10, capturedFormatPetCounts, capturedSelfPetsParagraph, capturedFormatAuraCounts, capturedSelfAurasParagraph, capturedFormatPlayerConsumables, capturedSelfConsumablesParagraph)
		return function()
			pcall(function()
				local capturedSelfStatsParagraph2 = capturedSelfStatsParagraph
				local setDesc = capturedSelfStatsParagraph.SetDesc
				local format = string.format
				local temporaryValue23 = capturedFormatStatNumber(capturedStrength.Value)
				local temporaryValue24 = capturedFormatStatNumber(capturedDurability.Value)
				local temporaryValue25 = capturedFormatStatNumber(capturedRebirths.Value)
				local capturedFormatStatNumber2 = capturedFormatStatNumber
				local value = capturedKills

				if value then
					value = capturedKills.Value
				end

				local temporaryValue26 = capturedFormatStatNumber2(value or 0)
				local capturedFormatStatNumber3 = capturedFormatStatNumber
				local value2 = capturedBrawls

				if value2 then
					value2 = capturedBrawls.Value
				end

				local temporaryValue27 = capturedFormatStatNumber3(value2 or 0)
				local capturedFormatStatNumber4 = capturedFormatStatNumber
				local value3 = capturedGems

				if value3 then
					value3 = capturedGems.Value
				end

				local returnValues5, returnCount5 = (function(...) return {...}, select("#", ...) end)(capturedFormatStatNumber4(value3 or 0))

				local temporaryValue28 = format([[力量：%s
耐力：%s
重生：%s
击杀：%s
争斗：%s
钻石：%s]], temporaryValue23, temporaryValue24, temporaryValue25, temporaryValue26, temporaryValue27, table.unpack(returnValues5, 1, returnCount5))

				setDesc(capturedSelfStatsParagraph2, temporaryValue28)
			end)

			pcall(function()
				local capturedCountItemsInSubfolders2 = capturedCountItemsInSubfolders
				local returnValues6, returnCount6 = (function(...) return {...}, select("#", ...) end)(capturedLocalPlayer10:FindFirstChild("petsFolder"))
				local temporaryValue29 = capturedCountItemsInSubfolders2(table.unpack(returnValues6, 1, returnCount6))
				local temporaryValue30 = capturedFormatPetCounts(temporaryValue29)
				local capturedSelfPetsParagraph2 = capturedSelfPetsParagraph
				local setDesc = capturedSelfPetsParagraph.SetDesc
				local flag = #temporaryValue30 == 0

				if flag then
					flag = "无"
				end

				setDesc(capturedSelfPetsParagraph2, flag or table.concat(temporaryValue30, "\n"))
			end)

			pcall(function()
				local capturedCountItemsInSubfolders3 = capturedCountItemsInSubfolders
				local returnValues7, returnCount7 = (function(...) return {...}, select("#", ...) end)(capturedLocalPlayer10:FindFirstChild("powerUpsFolder"))
				local temporaryValue31 = capturedCountItemsInSubfolders3(table.unpack(returnValues7, 1, returnCount7))
				local temporaryValue32 = capturedFormatAuraCounts(temporaryValue31)
				local capturedSelfAurasParagraph2 = capturedSelfAurasParagraph
				local setDesc = capturedSelfAurasParagraph.SetDesc
				local flag = #temporaryValue32 == 0

				if flag then
					flag = "无"
				end

				setDesc(capturedSelfAurasParagraph2, flag or table.concat(temporaryValue32, "\n"))
			end)

			pcall(function()
				local temporaryValue33 = capturedFormatPlayerConsumables(capturedLocalPlayer10)
				local capturedSelfConsumablesParagraph2 = capturedSelfConsumablesParagraph
				local setDesc = capturedSelfConsumablesParagraph.SetDesc
				local flag = #temporaryValue33 == 0

				if flag then
					flag = "无"
				end

				setDesc(capturedSelfConsumablesParagraph2, flag or table.concat(temporaryValue33, "\n"))
			end)
		end
	end)(selfStatsParagraph, formatStatNumber, strength, durability, rebirths, kills, brawls, gems, countItemsInSubfolders, localPlayer, formatPetCounts, selfPetsParagraph, formatAuraCounts, selfAurasParagraph, formatPlayerConsumables, selfConsumablesParagraph)

	-- [重建注释] 定义选中玩家的信息刷新函数并保存在共享单元 48。
	sharedCells[48][1] = (function(capturedInspectedPlayerCell3, capturedOtherStatsParagraph, capturedOtherPetsParagraph, capturedOtherAurasParagraph, capturedOtherConsumablesParagraph, capturedFormatStatNumber5, capturedCountItemsInSubfolders4, capturedFormatPetCounts2, capturedFormatAuraCounts2, capturedFormatPlayerConsumables2)
		return function()
			if capturedInspectedPlayerCell3[1] then
				if not capturedInspectedPlayerCell3[1].Parent then
					capturedOtherStatsParagraph:SetDesc("")
					capturedOtherPetsParagraph:SetDesc("")
					capturedOtherAurasParagraph:SetDesc("")
					capturedOtherConsumablesParagraph:SetDesc("")
				else
					local temporaryValue34 = capturedInspectedPlayerCell3[1]

					pcall((function(capturedValue4)
						return function()
							local leaderstats2 = capturedValue4:FindFirstChild("leaderstats")
							local strength2 = leaderstats2

							if strength2 then
								strength2 = leaderstats2:FindFirstChild("Strength")
							end

							local rebirths2 = leaderstats2

							if rebirths2 then
								rebirths2 = leaderstats2:FindFirstChild("Rebirths")
							end

							local durability2 = capturedValue4:FindFirstChild("Durability")
							local kills2

							if leaderstats2 then
								kills2 = leaderstats2:FindFirstChild("Kills") or capturedValue4:FindFirstChild("Kills")
							else
								kills2 = capturedValue4:FindFirstChild("Kills")
							end

							local brawls2

							if leaderstats2 then
								brawls2 = leaderstats2:FindFirstChild("Brawls") or capturedValue4:FindFirstChild("Brawls")
							else
								brawls2 = capturedValue4:FindFirstChild("Brawls")
							end

							local gems2 = capturedValue4:FindFirstChild("Gems")

							if not gems2 then
								gems2 = leaderstats2

								if gems2 then
									gems2 = leaderstats2:FindFirstChild("Gems")
								end
							end

							local capturedOtherStatsParagraph2 = capturedOtherStatsParagraph
							local setDesc = capturedOtherStatsParagraph.SetDesc
							local format = string.format
							local capturedFormatStatNumber6 = capturedFormatStatNumber5
							local temporaryValue35, capturedFormatStatNumber7, temporaryValue36, capturedFormatStatNumber8, value, temporaryValue37, capturedFormatStatNumber9, value2, temporaryValue38, capturedFormatStatNumber10, value3

							if strength2 then
								temporaryValue35 = capturedFormatStatNumber6(strength2.Value or 0)
								capturedFormatStatNumber7 = capturedFormatStatNumber5
								local value4 = durability2

								if value4 then
									value4 = durability2.Value
								end

								value4 = value4 or 0
								temporaryValue36 = capturedFormatStatNumber7(value4)
								capturedFormatStatNumber8 = capturedFormatStatNumber5
								value = rebirths2

								if value then
									value = rebirths2.Value
								end

								value = value or 0
								temporaryValue37 = capturedFormatStatNumber8(value)
								capturedFormatStatNumber9 = capturedFormatStatNumber5
								value2 = kills2

								if value2 then
									value2 = kills2.Value
								end

								value2 = value2 or 0
								temporaryValue38 = capturedFormatStatNumber9(value2)
								capturedFormatStatNumber10 = capturedFormatStatNumber5
								value3 = brawls2

								if value3 then
									value3 = brawls2.Value
								end

								value3 = value3 or 0
							else
								temporaryValue35 = capturedFormatStatNumber6(0)
								capturedFormatStatNumber7 = capturedFormatStatNumber5

								if durability2 then
									temporaryValue36 = capturedFormatStatNumber7(durability2.Value or 0)
									capturedFormatStatNumber8 = capturedFormatStatNumber5
									value = rebirths2

									if value then
										value = rebirths2.Value
									end

									value = value or 0
									temporaryValue37 = capturedFormatStatNumber8(value)
									capturedFormatStatNumber9 = capturedFormatStatNumber5
									value2 = kills2

									if value2 then
										value2 = kills2.Value
									end

									value2 = value2 or 0
									temporaryValue38 = capturedFormatStatNumber9(value2)
									capturedFormatStatNumber10 = capturedFormatStatNumber5
									value3 = brawls2

									if value3 then
										value3 = brawls2.Value
									end

									value3 = value3 or 0
								else
									temporaryValue36 = capturedFormatStatNumber7(0)
									capturedFormatStatNumber8 = capturedFormatStatNumber5

									if rebirths2 then
										temporaryValue37 = capturedFormatStatNumber8(rebirths2.Value or 0)
										capturedFormatStatNumber9 = capturedFormatStatNumber5
										value2 = kills2

										if value2 then
											value2 = kills2.Value
										end

										value2 = value2 or 0
										temporaryValue38 = capturedFormatStatNumber9(value2)
										capturedFormatStatNumber10 = capturedFormatStatNumber5
										value3 = brawls2

										if value3 then
											value3 = brawls2.Value
										end

										value3 = value3 or 0
									else
										temporaryValue37 = capturedFormatStatNumber8(0)
										capturedFormatStatNumber9 = capturedFormatStatNumber5

										if kills2 then
											temporaryValue38 = capturedFormatStatNumber9(kills2.Value or 0)
											capturedFormatStatNumber10 = capturedFormatStatNumber5
											value3 = brawls2

											if value3 then
												value3 = brawls2.Value
											end

											value3 = value3 or 0
										else
											temporaryValue38 = capturedFormatStatNumber9(0)
											capturedFormatStatNumber10 = capturedFormatStatNumber5

											if brawls2 then
												value3 = brawls2.Value or 0
											else
												value3 = 0
											end
										end
									end
								end
							end

							local temporaryValue39 = capturedFormatStatNumber10(value3)
							local capturedFormatStatNumber11 = capturedFormatStatNumber5
							local value4 = gems2

							if value4 then
								value4 = gems2.Value
							end

							local returnValues8, returnCount8 = (function(...) return {...}, select("#", ...) end)(capturedFormatStatNumber11(value4 or 0))

							local temporaryValue40 = format([[力量：%s
耐力：%s
重生：%s
击杀：%s
争斗：%s
钻石：%s]], temporaryValue35, temporaryValue36, temporaryValue37, temporaryValue38, temporaryValue39, table.unpack(returnValues8, 1, returnCount8))

							setDesc(capturedOtherStatsParagraph2, temporaryValue40)
						end
					end)(temporaryValue34))

					pcall((function(capturedValue5)
						return function()
							local capturedCountItemsInSubfolders5 = capturedCountItemsInSubfolders4
							local returnValues9, returnCount9 = (function(...) return {...}, select("#", ...) end)(capturedValue5:FindFirstChild("petsFolder"))
							local temporaryValue41 = capturedCountItemsInSubfolders5(table.unpack(returnValues9, 1, returnCount9))
							local temporaryValue42 = capturedFormatPetCounts2(temporaryValue41)
							local capturedOtherPetsParagraph2 = capturedOtherPetsParagraph
							local setDesc = capturedOtherPetsParagraph.SetDesc
							local flag = #temporaryValue42 == 0

							if flag then
								flag = "无"
							end

							setDesc(capturedOtherPetsParagraph2, flag or table.concat(temporaryValue42, "\n"))
						end
					end)(temporaryValue34))

					pcall((function(capturedValue6)
						return function()
							local capturedCountItemsInSubfolders6 = capturedCountItemsInSubfolders4
							local returnValues10, returnCount10 = (function(...) return {...}, select("#", ...) end)(capturedValue6:FindFirstChild("powerUpsFolder"))
							local temporaryValue43 = capturedCountItemsInSubfolders6(table.unpack(returnValues10, 1, returnCount10))
							local temporaryValue44 = capturedFormatAuraCounts2(temporaryValue43)
							local capturedOtherAurasParagraph2 = capturedOtherAurasParagraph
							local setDesc = capturedOtherAurasParagraph.SetDesc
							local flag = #temporaryValue44 == 0

							if flag then
								flag = "无"
							end

							setDesc(capturedOtherAurasParagraph2, flag or table.concat(temporaryValue44, "\n"))
						end
					end)(temporaryValue34))

					pcall((function(capturedValue7)
						return function()
							local temporaryValue45 = capturedFormatPlayerConsumables2(capturedValue7)
							local capturedOtherConsumablesParagraph2 = capturedOtherConsumablesParagraph
							local setDesc = capturedOtherConsumablesParagraph.SetDesc
							local flag = #temporaryValue45 == 0

							if flag then
								flag = "无"
							end

							setDesc(capturedOtherConsumablesParagraph2, flag or table.concat(temporaryValue45, "\n"))
						end
					end)(temporaryValue34))
				end
			else
				capturedOtherStatsParagraph:SetDesc("")
				capturedOtherPetsParagraph:SetDesc("")
				capturedOtherAurasParagraph:SetDesc("")
				capturedOtherConsumablesParagraph:SetDesc("")
			end
		end
	end)(sharedCells[120], otherStatsParagraph, otherPetsParagraph, otherAurasParagraph, otherConsumablesParagraph, formatStatNumber, countItemsInSubfolders, formatPetCounts, formatAuraCounts, formatPlayerConsumables)
end

-- [重建注释] 初始化两组数据显示，随后每秒在受保护调用中刷新。
sharedCells[47][1]()
sharedCells[48][1]()

task.spawn((function(capturedSelfInfoRefreshCell, capturedOtherInfoRefreshCell3)
	return function()
		while task.wait(1) do
			pcall(capturedSelfInfoRefreshCell[1])
			pcall(capturedOtherInfoRefreshCell3[1])
		end
	end
end)(sharedCells[47], sharedCells[48]))

-- [重建注释] 主要功能页：沿用原有训练、进度转换、岩石和 BOSS 逻辑及默认关闭状态。
do
	local trainingTab = mainWindow:Tab({ Title = "主要", Icon = "dumbbell" })
	local exerciseSection = trainingTab:Section({ Title = "锻炼功能", Box = true })
	sharedCells[137][1] = ""
	sharedCells[138][1] = exerciseSection.Dropdown
	local exerciseDropdownOptions = { Title = "选择锻炼类型", Multi = false, Value = "无", AllowNone = false }
	local exerciseLabels = table.create(5)
	exerciseLabels[1] = "无"
	exerciseLabels[2] = "哑铃"
	exerciseLabels[3] = "仰卧起坐"
	exerciseLabels[4] = "俯卧撑"
	exerciseLabels[5] = "倒立"
	exerciseDropdownOptions.Values = exerciseLabels

	exerciseDropdownOptions.Callback = (function(capturedExerciseChoiceCell)
		return function(callbackValue12)
			if callbackValue12 ~= "无" then
				if callbackValue12 == nil then
					capturedExerciseChoiceCell[1] = ""
				else
					capturedExerciseChoiceCell[1] = callbackValue12
				end
			else
				capturedExerciseChoiceCell[1] = ""
			end
		end
	end)(sharedCells[137])

	sharedCells[138][1](exerciseSection, exerciseDropdownOptions)
	sharedCells[138][1] = false
	sharedCells[139][1] = nil
	-- [重建注释] 中文训练选项对应背包内的工具名称。
	local exerciseToolNames = { ["哑铃"] = "Weight", ["倒立"] = "Handstands", ["仰卧起坐"] = "Situps", ["俯卧撑"] = "Pushups" }

	local runExerciseLoop
	do
		local capturedExerciseStateCell, capturedExerciseChoiceCell2, capturedLocalPlayer11, capturedExerciseToolNames = sharedCells[138], sharedCells[137], localPlayer, exerciseToolNames
		runExerciseLoop = function()
			while capturedExerciseStateCell[1] do
				if capturedExerciseChoiceCell2[1] ~= "" then
					local character = capturedLocalPlayer11.Character
					local backpack = capturedLocalPlayer11.Backpack

					if character then
						if character:FindFirstChild("Humanoid") then
							local temporaryValue46 = capturedExerciseToolNames[capturedExerciseChoiceCell2[1]]

							if temporaryValue46 then
								if backpack:FindFirstChild(temporaryValue46) then
									character.Humanoid:EquipTool(backpack[temporaryValue46])
								end
							end
						end
					end

					local n = 0

					while true do
						n += 1

						if n <= 10 then
							capturedLocalPlayer11.muscleEvent:FireServer("rep")
						else
							break
						end
					end
				end

				task.wait(0.05)
			end
		end
	end

	exerciseSection:Toggle({
		Title = "自动锻炼",
		Value = false,
		Callback = (function(capturedExerciseStateCell2, capturedExerciseThreadCell, capturedRunExerciseLoop)
			return function(callbackValue13)
				capturedExerciseStateCell2[1] = callbackValue13

				if callbackValue13 then
					capturedExerciseThreadCell[1] = task.spawn(capturedRunExerciseLoop)
				elseif capturedExerciseThreadCell[1] then
					task.cancel(capturedExerciseThreadCell[1])
					capturedExerciseThreadCell[1] = nil
				end
			end
		end)(sharedCells[138], sharedCells[139], runExerciseLoop),
	})

	-- [重建注释] 组合训练预设：展示名称、工具名和岩石名保持原值。
	local combinedExercisePresets = table.create(4)
	combinedExercisePresets[1] = { name = "俯卧撑+工业石头", tool = "Pushups", rock = "Industrial Rock" }
	combinedExercisePresets[2] = { name = "俯卧撑+丛林石头", tool = "Pushups", rock = "Ancient Jungle Rock" }
	combinedExercisePresets[3] = { name = "俯卧撑+肌肉石头", tool = "Pushups", rock = "Muscle King Mountain" }
	combinedExercisePresets[4] = { name = "俯卧撑+传奇石头", tool = "Pushups", rock = "Rock Of Legends" }

	local equipPunchAndSendHands
	do
		local capturedLocalPlayer12 = localPlayer
		equipPunchAndSendHands = function()
			local character = capturedLocalPlayer12.Character

			if character then
				if character:FindFirstChild("Humanoid") then
					local iteratePairs2 = pairs
					local children4 = capturedLocalPlayer12.Backpack:GetChildren()
					local iteratorNext13, iteratorState13, iteratorControl13 = iteratePairs2(children4)

					for k, entryValue17 in iteratorNext13, iteratorState13, iteratorControl13 do
						local entryValue18 = entryValue17

						if entryValue18.Name == "Punch" then
							character.Humanoid:EquipTool(entryValue18)
						end
					end

					capturedLocalPlayer12.muscleEvent:FireServer("punch", "leftHand")
					capturedLocalPlayer12.muscleEvent:FireServer("punch", "rightHand")
				end
			end
		end
	end

	local iteratorNext14
	iteratorNext14, sharedCells[145][1], sharedCells[146][1] = ipairs(combinedExercisePresets)

	for k, entryValue19 in iteratorNext14, sharedCells[145][1], sharedCells[146][1] do
		sharedCells[146][1] = entryValue19
		sharedCells[147][1] = false
		sharedCells[148][1] = nil

		exerciseSection:Toggle({
			Title = sharedCells[146][1].name,
			Value = false,
			Callback = (function(capturedReusedSlot147Cell, capturedLocalPlayer13, capturedValue8, capturedReusedSlot148Cell, capturedWorkspace5, capturedRunService)
				return function(callbackValue14)
					capturedReusedSlot147Cell[1] = callbackValue14

					if capturedReusedSlot147Cell[1] then
						local character = capturedLocalPlayer13.Character
						local backpack = capturedLocalPlayer13.Backpack

						if backpack:FindFirstChild(capturedValue8.tool) then
							if character then
								if not character:FindFirstChild(capturedValue8.tool) then
									if character:FindFirstChild("Humanoid") then
										character.Humanoid:EquipTool(backpack[capturedValue8.tool])
									end
								end
							end
						end

						capturedReusedSlot148Cell[1] = task.spawn(function()
							while capturedReusedSlot147Cell[1] do
								capturedLocalPlayer13.muscleEvent:FireServer("rep")

								if capturedWorkspace5:FindFirstChild("machinesFolder") then
									local temporaryValue47 = capturedWorkspace5.machinesFolder:FindFirstChild(capturedValue8.rock)

									if temporaryValue47 then
										if temporaryValue47:FindFirstChild("Rock") then
											if capturedLocalPlayer13.Character then
												if capturedLocalPlayer13.Character:FindFirstChild("LeftHand") then
													pcall((function(capturedValue9)
														return function()
															firetouchinterest(capturedValue9.Rock, capturedLocalPlayer13.Character.LeftHand, 0)
															firetouchinterest(capturedValue9.Rock, capturedLocalPlayer13.Character.LeftHand, 1)
														end
													end)(temporaryValue47))
												end
											end
										end
									end
								end

								if capturedLocalPlayer13.Backpack:FindFirstChild("Punch") then
									if capturedLocalPlayer13.Character then
										if capturedLocalPlayer13.Character:FindFirstChildOfClass("Humanoid") then
											capturedLocalPlayer13.Character:FindFirstChildOfClass("Humanoid"):EquipTool(capturedLocalPlayer13.Backpack.Punch)
											capturedLocalPlayer13.muscleEvent:FireServer("punch", "rightHand")
											capturedLocalPlayer13.muscleEvent:FireServer("punch", "leftHand")
										end
									end
								end

								capturedRunService.RenderStepped:Wait()

								if capturedLocalPlayer13.Backpack:FindFirstChild(capturedValue8.tool) then
									if capturedLocalPlayer13.Character then
										if capturedLocalPlayer13.Character:FindFirstChildOfClass("Humanoid") then
											capturedLocalPlayer13.Character:FindFirstChildOfClass("Humanoid"):EquipTool(capturedLocalPlayer13.Backpack[capturedValue8.tool])
										end
									end
								end
							end
						end)
					else
						if capturedReusedSlot148Cell[1] then
							task.cancel(capturedReusedSlot148Cell[1])
							capturedReusedSlot148Cell[1] = nil
						end

						if capturedLocalPlayer13.Character then
							if capturedLocalPlayer13.Character:FindFirstChild(capturedValue8.tool) then
								capturedLocalPlayer13.Character[capturedValue8.tool].Parent = capturedLocalPlayer13.Backpack
							end
						end
					end
				end
			end)(sharedCells[147], localPlayer, sharedCells[146][1], sharedCells[148], Workspace, runService),
		})

		sharedCells[147] = { [1] = sharedCells[147][1] }
		sharedCells[148] = { [1] = sharedCells[148][1] }
	end

	-- [重建注释] 这一段开始复用共享单元 145—148；旧回调通过此前捕获的单元保留原来的状态。
	local rebirthSection = trainingTab:Section({ Title = "重生功能", Box = true })
	sharedCells[145][1] = 0
	sharedCells[146][1] = false
	sharedCells[147][1] = nil

	rebirthSection:Input({
		Title = "重生次数",
		Value = "",
		Callback = (function(capturedReusedSlot145Cell)
			return function(callbackValue15)
				capturedReusedSlot145Cell[1] = tonumber(callbackValue15) or 0
			end
		end)(sharedCells[145]),
	})

	sharedCells[148][1] = (function(capturedReusedSlot146Cell, capturedLocalPlayer14, capturedReusedSlot145Cell2, capturedReplicatedStorage3)
		return function()
			local dataTable6 = { [3] = {} }

			if capturedReusedSlot146Cell[1] then
				dataTable6[3][1] = false

				pcall((function(capturedValue10)
					return function()
						local leaderstats = capturedLocalPlayer14.leaderstats

						if leaderstats then
							leaderstats = capturedLocalPlayer14.leaderstats:FindFirstChild("Rebirths")
						end

						if capturedReusedSlot145Cell2[1] > 0 then
							if leaderstats then
								if not (capturedReusedSlot145Cell2[1] <= leaderstats.Value) then
									capturedReplicatedStorage3.rEvents.rebirthRemote:InvokeServer("rebirthRequest")
								else
									capturedValue10[1] = true
								end
							else
								capturedReplicatedStorage3.rEvents.rebirthRemote:InvokeServer("rebirthRequest")
							end
						else
							capturedReplicatedStorage3.rEvents.rebirthRemote:InvokeServer("rebirthRequest")
						end
					end
				end)(dataTable6[3]))

				while true do
					if dataTable6[3][1] then
						capturedReusedSlot146Cell[1] = false
						dataTable6[3] = { [1] = dataTable6[3][1] }
					else
						task.wait(0.1)
						dataTable6[3] = { [1] = dataTable6[3][1] }

						if capturedReusedSlot146Cell[1] then
							dataTable6[3][1] = false

							pcall((function(capturedValue11)
								return function()
									local leaderstats = capturedLocalPlayer14.leaderstats

									if leaderstats then
										leaderstats = capturedLocalPlayer14.leaderstats:FindFirstChild("Rebirths")
									end

									if capturedReusedSlot145Cell2[1] > 0 then
										if leaderstats then
											if not (capturedReusedSlot145Cell2[1] <= leaderstats.Value) then
												capturedReplicatedStorage3.rEvents.rebirthRemote:InvokeServer("rebirthRequest")
											else
												capturedValue11[1] = true
											end
										else
											capturedReplicatedStorage3.rEvents.rebirthRemote:InvokeServer("rebirthRequest")
										end
									else
										capturedReplicatedStorage3.rEvents.rebirthRemote:InvokeServer("rebirthRequest")
									end
								end
							end)(dataTable6[3]))

							continue
						end
					end

					break
				end
			end
		end
	end)(sharedCells[146], localPlayer, sharedCells[145], ReplicatedStorage)

	rebirthSection:Toggle({
		Title = "自动重生",
		Value = false,
		Callback = (function(capturedReusedSlot146Cell2, capturedReusedSlot147Cell2, capturedValue12)
			return function(callbackValue16)
				capturedReusedSlot146Cell2[1] = callbackValue16

				if callbackValue16 then
					capturedReusedSlot147Cell2[1] = task.spawn(capturedValue12)
				elseif capturedReusedSlot147Cell2[1] then
					task.cancel(capturedReusedSlot147Cell2[1])
					capturedReusedSlot147Cell2[1] = nil
				end
			end
		end)(sharedCells[146], sharedCells[147], sharedCells[148][1]),
	})

	sharedCells[150][1] = false
	sharedCells[151][1] = nil

	local runMuscleKingTeleportLoop
	do
		local capturedMuscleKingEnabledCell, capturedLocalPlayer15 = sharedCells[150], localPlayer
		runMuscleKingTeleportLoop = function()
			while capturedMuscleKingEnabledCell[1] do
				pcall(function()
					local character = capturedLocalPlayer15.Character

					if character then
						if character:FindFirstChild("HumanoidRootPart") then
							character.HumanoidRootPart.CFrame = CFrame.new(-8625.9296875, 13.566278457641602, -5730.4736328125)
						end
					end
				end)

				task.wait(0.05)
			end
		end
	end

	rebirthSection:Toggle({
		Title = "自动传送肌肉王",
		Value = false,
		Callback = (function(capturedMuscleKingEnabledCell2, capturedMuscleKingThreadCell, capturedRunMuscleKingTeleportLoop)
			return function(callbackValue17)
				capturedMuscleKingEnabledCell2[1] = callbackValue17

				if callbackValue17 then
					capturedMuscleKingThreadCell[1] = task.spawn(capturedRunMuscleKingTeleportLoop)
				elseif capturedMuscleKingThreadCell[1] then
					task.cancel(capturedMuscleKingThreadCell[1])
					capturedMuscleKingThreadCell[1] = nil
				end
			end
		end)(sharedCells[150], sharedCells[151], runMuscleKingTeleportLoop),
	})

	local rockSection = trainingTab:Section({ Title = "石头功能", Box = true })

	-- [重建注释] 岩石配置与条件沿用原值；这里只为已有变量和结构补充用途说明。
	local rockRequirements = {
		Data = {
			["小岛石头-0耐力"] = 0,
			["大石头-100耐力"] = 100,
			["中石头-10耐力"] = 10,
			["沙滩石头-5k耐力"] = 5000,
			["冰霜石头-150k耐力"] = 150000,
			["神话石头-400k耐力"] = 400000,
			["永恒石头-750k耐力"] = 750000,
			["传奇石头-1m耐力"] = 1000000,
			["肌肉石头-5m耐力"] = 5000000,
			["丛林石头-10m耐力"] = 10000000,
			["工业石头-25m耐力"] = 25000000,
		},
		SelectedRock = nil,
	}

	sharedCells[159][1] = (function(capturedRockRequirements)
		return function()
			local dataTable7 = {}
			local iteratorNext15, iteratorState14, iteratorControl14 = pairs(capturedRockRequirements.Data)

			for k, entryValue20 in iteratorNext15, iteratorState14, iteratorControl14 do
				table.insert(dataTable7, k)
			end

			table.sort(dataTable7, function(callbackValue18, callbackValue19)
				return capturedRockRequirements.Data[callbackValue18] > capturedRockRequirements.Data[callbackValue19]
			end)

			return dataTable7
		end
	end)(rockRequirements)

	rockSection:Dropdown({
		Title = "选择岩石",
		Multi = false,
		Value = "无",
		AllowNone = false,
		Values = sharedCells[159][1](),
		Callback = (function(capturedRockRequirements2)
			return function(selectedRock)
				capturedRockRequirements2.SelectedRock = selectedRock
			end
		end)(rockRequirements),
	})

	getgenv().RockFarmRunning = false

	rockSection:Toggle({
		Title = "自动岩石",
		Value = false,
		Callback = (function(capturedRockRequirements3, capturedLocalPlayer16, capturedWorkspace6, capturedEquipPunchAndSendHands)
			return function(rockFarmRunning)
				getgenv().RockFarmRunning = rockFarmRunning

				if rockFarmRunning then
					if capturedRockRequirements3.SelectedRock then
						task.spawn(function()
							while getgenv().RockFarmRunning do
								task.wait(0.12)
								local character = capturedLocalPlayer16.Character
								local durability2 = capturedLocalPlayer16:FindFirstChild("Durability")

								if durability2 then
									if character then
										if character:FindFirstChild("LeftHand") then
											if character:FindFirstChild("RightHand") then
												if capturedRockRequirements3.Data[capturedRockRequirements3.SelectedRock] <= durability2.Value then
													local iteratePairs3 = pairs
													local descendants3 = capturedWorkspace6.machinesFolder:GetDescendants()
													local iteratorNext16, iteratorState15, iteratorControl15 = iteratePairs3(descendants3)

													for k, entryValue21 in iteratorNext16, iteratorState15, iteratorControl15 do
														local entryValue22 = entryValue21

														if entryValue22.Name == "neededDurability" then
															if entryValue22.Value == capturedRockRequirements3.Data[capturedRockRequirements3.SelectedRock] then
																if entryValue22.Parent:FindFirstChild("Rock") then
																	pcall((function(capturedEntryValue, capturedCharacter)
																		return function()
																			firetouchinterest(capturedEntryValue.Parent.Rock, capturedCharacter.RightHand, 0)
																			firetouchinterest(capturedEntryValue.Parent.Rock, capturedCharacter.RightHand, 1)
																			firetouchinterest(capturedEntryValue.Parent.Rock, capturedCharacter.LeftHand, 0)
																			firetouchinterest(capturedEntryValue.Parent.Rock, capturedCharacter.LeftHand, 1)
																		end
																	end)(entryValue22, character))

																	capturedEquipPunchAndSendHands()
																end
															end
														end
													end
												end
											end
										end
									end
								end
							end
						end)
					end
				end
			end
		end)(rockRequirements, localPlayer, Workspace, equipPunchAndSendHands),
	})

	-- [重建注释] BOSS 页：位置保持、目标查找、攻击状态和启停控制。
	local bossSection = trainingTab:Section({ Title = "BOSS功能", Box = true })
	sharedCells[158][1] = 70
	sharedCells[159][1] = "Boss1"
	local vector = Vector3.new(1, 44, -1251)
	local bossMovementState = { on = false }

	local holdRootPositionForDuration
	do
		local capturedPlayerReference3, capturedRunService2, capturedBossMovementState = playerReference, runService, bossMovementState
		holdRootPositionForDuration = function(durationSeconds, targetCFrame)
			local character = capturedPlayerReference3.Character
			local humanoidRootPart = character

			if humanoidRootPart then
				humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			end

			if not humanoidRootPart then
				task.wait(durationSeconds)
			else
				local cFrame = targetCFrame or humanoidRootPart.CFrame
				local now = os.clock()

				local connection = capturedRunService2.RenderStepped:Connect((function(capturedHumanoidRootPart, capturedNow, capturedDurationSeconds, capturedCFrame)
					return function()
						if not capturedBossMovementState.on then
							if capturedHumanoidRootPart.Parent then
								if os.clock() - capturedNow <= capturedDurationSeconds then
									capturedHumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
									capturedHumanoidRootPart.AssemblyAngularVelocity = Vector3.zero
									capturedHumanoidRootPart.CFrame = capturedCFrame
								end
							end
						end
					end
				end)(humanoidRootPart, now, durationSeconds, cFrame))

				task.wait(durationSeconds)

				if connection then
					connection:Disconnect()
				end
			end
		end
	end

	local findBoss
	do
		local capturedWorkspace7, capturedReusedSlot159Cell = Workspace, sharedCells[159]
		findBoss = function(bossName)
			local events = capturedWorkspace7:FindFirstChild("Events")
			local events2 = events

			if events2 then
				local bossArena = events:FindFirstChild("BossArena")
				events2 = bossArena

				if events2 then
					events2 = bossArena:FindFirstChild(bossName or capturedReusedSlot159Cell[1])
				end
			end

			local events3 = events2
			local boss = events3

			if boss then
				boss = events3:FindFirstChild("Boss")
			end

			return boss
		end
	end

	local getBossPosition
	do
		local capturedFindBoss = findBoss
		getBossPosition = function()
			local temporaryValue48 = capturedFindBoss()
			if not temporaryValue48 then
				return
			end
			local position

			if temporaryValue48:IsA("Model") then
				position = temporaryValue48:GetPivot().Position or temporaryValue48.Position
			else
				position = temporaryValue48.Position
			end

			return position
		end
	end

	-- [重建注释] 检查目标模型/部件。注意原式 flag or true 会把 false 变成 true，因此此函数不等价于严格的存活检查。
	local checkBossPresence
	do
		local capturedFindBoss2 = findBoss
		checkBossPresence = function(bossName2)
			local temporaryValue49 = capturedFindBoss2(bossName2)
			if not temporaryValue49 then
				return false
			end
			local flag

			if temporaryValue49:IsA("Model") then
				local humanoid = temporaryValue49:FindFirstChildOfClass("Humanoid")
				flag = humanoid

				if flag then
					flag = humanoid.Health > 0
				end

				flag = flag or true
			else
				flag = temporaryValue49:IsA("BasePart")

				if flag then
					flag = temporaryValue49.Transparency < 1
				end
			end

			return flag
		end
	end

	local bossAttackState = { active = false }
	-- [重建注释] 原脚本的动画资源编号列表，未修改。
	local attackAnimationIds = table.create(8)
	attackAnimationIds[1] = "3638729053"
	attackAnimationIds[2] = "3638767427"
	attackAnimationIds[3] = "507768375"
	attackAnimationIds[4] = "522635514"
	attackAnimationIds[5] = "522638767"
	attackAnimationIds[6] = "182393478"
	attackAnimationIds[7] = "129967390"
	attackAnimationIds[8] = "129967478"

	local startBossAttack
	do
		local capturedBossAttackState, capturedRunService3, capturedGetBossPosition, capturedGetRootPart6, capturedReusedSlot158Cell, capturedAttackAnimationIds, capturedPlayerReference4, capturedMuscleEvent2 = bossAttackState, runService, getBossPosition, getRootPart, sharedCells[158], attackAnimationIds, playerReference, muscleEvent
		startBossAttack = function()
			if not capturedBossAttackState.active then
				capturedBossAttackState.active = true

				capturedBossAttackState.conn = capturedRunService3.RenderStepped:Connect(function()
					local temporaryValue50 = capturedGetBossPosition()
					local temporaryValue51 = capturedGetRootPart6()

					if temporaryValue51 then
						if temporaryValue50 then
							local n = temporaryValue50 + Vector3.new(0, capturedReusedSlot158Cell[1], 0)
							local n2 = temporaryValue50 - n
							local vector2 = Vector3.new(n2.X, 0, n2.Z)

							if vector2.Magnitude < 0.1 then
								vector2 = Vector3.new(0, 0, -1)
							end

							local vector3 = Vector3.zero
							temporaryValue51.AssemblyLinearVelocity = Vector3.zero
							temporaryValue51.AssemblyAngularVelocity = vector3
							local unit = vector2.Unit
							local cframe = CFrame.fromEulerAnglesYXZ
							temporaryValue51.CFrame = CFrame.new(n) * cframe(math.rad(-80), math.atan2(-unit.X, -unit.Z), 0)
						end
					end
				end)

				capturedBossAttackState.thread = task.spawn(function()
					local dataTable8 = { [4] = {}, [5] = {}, [6] = {} }
					local dataTable9 = {}
					local dataTable10 = {}
					dataTable8[4][1], dataTable8[5][1], dataTable8[6][1] = ipairs(capturedAttackAnimationIds)
					local advanceIterator3 = makeResumableIterator(dataTable8[4][1], dataTable8[5][1], dataTable8[6][1])

					while true do
						local packedReturns2 = table.pack(advanceIterator3())

						if packedReturns2[1] then
							dataTable8[6][1] = packedReturns2[3]
							local insert = table.insert
							local flag = packedReturns2[2] % 2 == 1

							if flag then
								flag = dataTable9
							end

							insert(flag or dataTable10, "rbxassetid://" .. dataTable8[6][1])
						else
							break
						end
					end

					dataTable8[4][1] = true
					dataTable8[5][1] = nil
					dataTable8[6][1] = nil

					if capturedBossAttackState.active then
						local n, loopEntryState2, loopExitState7, punch, numberValue, loopExitState8, loopExitState9, loopExitState10

						if not capturedGetBossPosition() then
							local loopExitState11 = nil

							while true do
								task.wait(0.5)
								task.wait(0.05)

								if capturedBossAttackState.active then
									if capturedGetBossPosition() then
										loopExitState11 = 1
										break
									end
								else
									break
								end
							end

							if loopExitState11 == 1 then
								n = 1
								loopEntryState2 = 1
								loopExitState7 = nil

								while true do
									if loopEntryState2 == 1 then
										pcall((function(capturedValue13, capturedValue14, capturedValue15, capturedValue16, capturedValue17)
											return function()
												if capturedPlayerReference4.Character then
													local humanoid = capturedPlayerReference4.Character:FindFirstChildOfClass("Humanoid")

													if humanoid then
														local punch2 = capturedPlayerReference4.Backpack:FindFirstChild("Punch")

														if punch2 then
															humanoid:EquipTool(punch2)
														end

														local capturedMuscleEvent3 = capturedMuscleEvent2
														local fireServer = capturedMuscleEvent2.FireServer
														local str = capturedValue13[1]

														if str then
															str = "leftHand"
														end

														fireServer(capturedMuscleEvent3, "punch", str or "rightHand")
														local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
														local temporaryValue52 = capturedValue13[1]

														if temporaryValue52 then
															temporaryValue52 = capturedValue14[1]
														end

														temporaryValue52 = temporaryValue52 or capturedValue15[1]

														if not temporaryValue52 then
															local temporaryValue53

															if capturedValue13[1] then
																temporaryValue53 = capturedValue16[1] or capturedValue17[1]
															else
																temporaryValue53 = capturedValue17[1]
															end

															if temporaryValue53 then
																local animation = Instance.new("Animation")
																animation.AnimationId = temporaryValue53
																temporaryValue52 = animator:LoadAnimation(animation)

																if capturedValue13[1] then
																	capturedValue14[1] = temporaryValue52
																else
																	capturedValue15[1] = temporaryValue52
																end
															end

															if temporaryValue52 then
																temporaryValue52:Stop(0)
																temporaryValue52:Play(0.1)
															end
														else
															temporaryValue52:Stop(0)
															temporaryValue52:Play(0.1)
														end

														capturedValue13[1] = not capturedValue13[1]
													end
												end
											end
										end)(dataTable8[4], dataTable8[5], dataTable8[6], dataTable9, dataTable10))

										loopEntryState2 = 2
										continue
									end

									task.wait(0.05)

									if capturedBossAttackState.active then
										if not capturedGetBossPosition() then
											task.wait(0.5)
											loopEntryState2 = 2
											continue
										else
											n += 1

											if n % 4 == 0 then
												punch = capturedPlayerReference4.Backpack:FindFirstChild("Punch")

												if punch then
													loopExitState7 = 1
													break
												else
													loopEntryState2 = 1
													continue
												end
											else
												loopEntryState2 = 1
												continue
											end
										end
									end

									break
								end

								if loopExitState7 == 1 then
									while true do
										numberValue = punch:FindFirstChildOfClass("NumberValue")
										loopExitState8 = nil

										while true do
											if numberValue then
												numberValue.Value = 0.01
											end

											loopExitState9 = nil

											while true do
												pcall((function(capturedValue18, capturedValue19, capturedValue20, capturedValue21, capturedValue22)
													return function()
														if capturedPlayerReference4.Character then
															local humanoid = capturedPlayerReference4.Character:FindFirstChildOfClass("Humanoid")

															if humanoid then
																local punch2 = capturedPlayerReference4.Backpack:FindFirstChild("Punch")

																if punch2 then
																	humanoid:EquipTool(punch2)
																end

																local capturedMuscleEvent4 = capturedMuscleEvent2
																local fireServer = capturedMuscleEvent2.FireServer
																local str = capturedValue18[1]

																if str then
																	str = "leftHand"
																end

																fireServer(capturedMuscleEvent4, "punch", str or "rightHand")
																local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
																local temporaryValue54 = capturedValue18[1]

																if temporaryValue54 then
																	temporaryValue54 = capturedValue19[1]
																end

																temporaryValue54 = temporaryValue54 or capturedValue20[1]

																if not temporaryValue54 then
																	local temporaryValue55

																	if capturedValue18[1] then
																		temporaryValue55 = capturedValue21[1] or capturedValue22[1]
																	else
																		temporaryValue55 = capturedValue22[1]
																	end

																	if temporaryValue55 then
																		local animation = Instance.new("Animation")
																		animation.AnimationId = temporaryValue55
																		temporaryValue54 = animator:LoadAnimation(animation)

																		if capturedValue18[1] then
																			capturedValue19[1] = temporaryValue54
																		else
																			capturedValue20[1] = temporaryValue54
																		end
																	end

																	if temporaryValue54 then
																		temporaryValue54:Stop(0)
																		temporaryValue54:Play(0.1)
																	end
																else
																	temporaryValue54:Stop(0)
																	temporaryValue54:Play(0.1)
																end

																capturedValue18[1] = not capturedValue18[1]
															end
														end
													end
												end)(dataTable8[4], dataTable8[5], dataTable8[6], dataTable9, dataTable10))

												loopExitState10 = nil

												while true do
													task.wait(0.05)

													if capturedBossAttackState.active then
														if not capturedGetBossPosition() then
															task.wait(0.5)
														else
															loopExitState10 = 1
															break
														end
													else
														break
													end
												end

												if loopExitState10 == 1 then
													n += 1

													if n % 4 == 0 then
														loopExitState9 = 1
														break
													else
														continue
													end
												end

												break
											end

											if loopExitState9 == 1 then
												punch = capturedPlayerReference4.Backpack:FindFirstChild("Punch")
												numberValue = punch

												if numberValue then
													loopExitState8 = 1
													break
												else
													continue
												end
											end

											break
										end

										if loopExitState8 == 1 then
											continue
										end
										break
									end
								end
							end
						else
							n = 1

							pcall((function(capturedValue23, capturedValue24, capturedValue25, capturedValue26, capturedValue27)
								return function()
									if capturedPlayerReference4.Character then
										local humanoid = capturedPlayerReference4.Character:FindFirstChildOfClass("Humanoid")

										if humanoid then
											local punch2 = capturedPlayerReference4.Backpack:FindFirstChild("Punch")

											if punch2 then
												humanoid:EquipTool(punch2)
											end

											local capturedMuscleEvent5 = capturedMuscleEvent2
											local fireServer = capturedMuscleEvent2.FireServer
											local str = capturedValue23[1]

											if str then
												str = "leftHand"
											end

											fireServer(capturedMuscleEvent5, "punch", str or "rightHand")
											local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
											local temporaryValue56 = capturedValue23[1]

											if temporaryValue56 then
												temporaryValue56 = capturedValue24[1]
											end

											temporaryValue56 = temporaryValue56 or capturedValue25[1]

											if not temporaryValue56 then
												local temporaryValue57

												if capturedValue23[1] then
													temporaryValue57 = capturedValue26[1] or capturedValue27[1]
												else
													temporaryValue57 = capturedValue27[1]
												end

												if temporaryValue57 then
													local animation = Instance.new("Animation")
													animation.AnimationId = temporaryValue57
													temporaryValue56 = animator:LoadAnimation(animation)

													if capturedValue23[1] then
														capturedValue24[1] = temporaryValue56
													else
														capturedValue25[1] = temporaryValue56
													end
												end

												if temporaryValue56 then
													temporaryValue56:Stop(0)
													temporaryValue56:Play(0.1)
												end
											else
												temporaryValue56:Stop(0)
												temporaryValue56:Play(0.1)
											end

											capturedValue23[1] = not capturedValue23[1]
										end
									end
								end
							end)(dataTable8[4], dataTable8[5], dataTable8[6], dataTable9, dataTable10))

							loopEntryState2 = 2
							loopExitState7 = nil

							while true do
								if loopEntryState2 == 1 then
									pcall((function(capturedValue28, capturedValue29, capturedValue30, capturedValue31, capturedValue32)
										return function()
											if capturedPlayerReference4.Character then
												local humanoid = capturedPlayerReference4.Character:FindFirstChildOfClass("Humanoid")

												if humanoid then
													local punch2 = capturedPlayerReference4.Backpack:FindFirstChild("Punch")

													if punch2 then
														humanoid:EquipTool(punch2)
													end

													local capturedMuscleEvent6 = capturedMuscleEvent2
													local fireServer = capturedMuscleEvent2.FireServer
													local str = capturedValue28[1]

													if str then
														str = "leftHand"
													end

													fireServer(capturedMuscleEvent6, "punch", str or "rightHand")
													local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
													local temporaryValue58 = capturedValue28[1]

													if temporaryValue58 then
														temporaryValue58 = capturedValue29[1]
													end

													temporaryValue58 = temporaryValue58 or capturedValue30[1]

													if not temporaryValue58 then
														local temporaryValue59

														if capturedValue28[1] then
															temporaryValue59 = capturedValue31[1] or capturedValue32[1]
														else
															temporaryValue59 = capturedValue32[1]
														end

														if temporaryValue59 then
															local animation = Instance.new("Animation")
															animation.AnimationId = temporaryValue59
															temporaryValue58 = animator:LoadAnimation(animation)

															if capturedValue28[1] then
																capturedValue29[1] = temporaryValue58
															else
																capturedValue30[1] = temporaryValue58
															end
														end

														if temporaryValue58 then
															temporaryValue58:Stop(0)
															temporaryValue58:Play(0.1)
														end
													else
														temporaryValue58:Stop(0)
														temporaryValue58:Play(0.1)
													end

													capturedValue28[1] = not capturedValue28[1]
												end
											end
										end
									end)(dataTable8[4], dataTable8[5], dataTable8[6], dataTable9, dataTable10))

									loopEntryState2 = 2
									continue
								end

								task.wait(0.05)

								if capturedBossAttackState.active then
									if not capturedGetBossPosition() then
										task.wait(0.5)
										loopEntryState2 = 2
										continue
									else
										n += 1

										if n % 4 == 0 then
											punch = capturedPlayerReference4.Backpack:FindFirstChild("Punch")

											if punch then
												loopExitState7 = 1
												break
											else
												loopEntryState2 = 1
												continue
											end
										else
											loopEntryState2 = 1
											continue
										end
									end
								end

								break
							end

							if loopExitState7 == 1 then
								while true do
									numberValue = punch:FindFirstChildOfClass("NumberValue")
									loopExitState8 = nil

									while true do
										if numberValue then
											numberValue.Value = 0.01
										end

										loopExitState9 = nil

										while true do
											pcall((function(capturedValue33, capturedValue34, capturedValue35, capturedValue36, capturedValue37)
												return function()
													if capturedPlayerReference4.Character then
														local humanoid = capturedPlayerReference4.Character:FindFirstChildOfClass("Humanoid")

														if humanoid then
															local punch2 = capturedPlayerReference4.Backpack:FindFirstChild("Punch")

															if punch2 then
																humanoid:EquipTool(punch2)
															end

															local capturedMuscleEvent7 = capturedMuscleEvent2
															local fireServer = capturedMuscleEvent2.FireServer
															local str = capturedValue33[1]

															if str then
																str = "leftHand"
															end

															fireServer(capturedMuscleEvent7, "punch", str or "rightHand")
															local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
															local temporaryValue60 = capturedValue33[1]

															if temporaryValue60 then
																temporaryValue60 = capturedValue34[1]
															end

															temporaryValue60 = temporaryValue60 or capturedValue35[1]

															if not temporaryValue60 then
																local temporaryValue61

																if capturedValue33[1] then
																	temporaryValue61 = capturedValue36[1] or capturedValue37[1]
																else
																	temporaryValue61 = capturedValue37[1]
																end

																if temporaryValue61 then
																	local animation = Instance.new("Animation")
																	animation.AnimationId = temporaryValue61
																	temporaryValue60 = animator:LoadAnimation(animation)

																	if capturedValue33[1] then
																		capturedValue34[1] = temporaryValue60
																	else
																		capturedValue35[1] = temporaryValue60
																	end
																end

																if temporaryValue60 then
																	temporaryValue60:Stop(0)
																	temporaryValue60:Play(0.1)
																end
															else
																temporaryValue60:Stop(0)
																temporaryValue60:Play(0.1)
															end

															capturedValue33[1] = not capturedValue33[1]
														end
													end
												end
											end)(dataTable8[4], dataTable8[5], dataTable8[6], dataTable9, dataTable10))

											loopExitState10 = nil

											while true do
												task.wait(0.05)

												if capturedBossAttackState.active then
													if not capturedGetBossPosition() then
														task.wait(0.5)
													else
														loopExitState10 = 1
														break
													end
												else
													break
												end
											end

											if loopExitState10 == 1 then
												n += 1

												if n % 4 == 0 then
													loopExitState9 = 1
													break
												else
													continue
												end
											end

											break
										end

										if loopExitState9 == 1 then
											punch = capturedPlayerReference4.Backpack:FindFirstChild("Punch")
											numberValue = punch

											if numberValue then
												loopExitState8 = 1
												break
											else
												continue
											end
										end

										break
									end

									if loopExitState8 == 1 then
										continue
									end
									break
								end
							end
						end
					end

					dataTable8[4] = { [1] = dataTable8[4][1] }
					dataTable8[5] = { [1] = dataTable8[5][1] }
					dataTable8[6] = { [1] = dataTable8[6][1] }
				end)
			end
		end
	end

	local stopBossAttack
	do
		local capturedBossAttackState2 = bossAttackState
		stopBossAttack = function()
			if capturedBossAttackState2.active then
				capturedBossAttackState2.active = false

				if capturedBossAttackState2.conn then
					capturedBossAttackState2.conn:Disconnect()
					capturedBossAttackState2.conn = nil
				end

				if capturedBossAttackState2.thread then
					pcall(task.cancel, capturedBossAttackState2.thread)
					capturedBossAttackState2.thread = nil
				end
			end
		end
	end

	-- [重建注释] BOSS 控制对象：方法名及其原有启动、停止顺序保持不变。
	local bossController = {
		running = false,
		start = (function(capturedStartBossAttack, capturedCheckBossPresence, capturedReusedSlot159Cell2, capturedHoldRootPositionForDuration, capturedGetRootPart7, capturedVector)
			return function(callbackValue20)
				if not callbackValue20.running then
					callbackValue20.running = true
					capturedStartBossAttack()

					task.spawn((function(capturedValue38)
						return function()
							if capturedValue38.running then
								task.wait(2)

								if capturedValue38.running then
									local n = 1
									local loopExitState12 = nil
									local str

									while true do
										str = "Boss" .. n

										if capturedCheckBossPresence(str) then
											break
										else
											n += 1
											if not (n <= 5) then
												loopExitState12 = 1
												break
											end
										end
									end

									local flag, temporaryValue62, vector2, loopExitState13, flag2, n2, str2

									if loopExitState12 == 1 then
										while true do
											flag = true
											_G.chestOpen = true
											capturedHoldRootPositionForDuration(10)
											_G.chestOpen = false
											temporaryValue62 = capturedGetRootPart7()

											if temporaryValue62 then
												vector2 = Vector3.zero
												temporaryValue62.AssemblyLinearVelocity = Vector3.zero
												temporaryValue62.AssemblyAngularVelocity = vector2
												temporaryValue62.CFrame = CFrame.new(capturedVector)
											end

											loopExitState13 = nil

											while true do
												if capturedValue38.running then
													task.wait(2)

													if capturedValue38.running then
														flag2 = false
														n2 = 0

														while true do
															n2 += 1

															if n2 <= 5 then
																str2 = "Boss" .. n2

																if capturedCheckBossPresence(str2) then
																	flag2 = true
																	flag = false

																	if str2 ~= capturedReusedSlot159Cell2[1] then
																		capturedReusedSlot159Cell2[1] = str2
																	end

																	break
																end
															else
																break
															end
														end

														if not flag2 then
															if not flag then
																loopExitState13 = 1
																break
															else
																continue
															end
														else
															continue
														end
													end
												end

												break
											end

											if loopExitState13 == 1 then
												continue
											end
											break
										end
									else
										local loopExitState14 = nil

										while true do
											local flag3 = true

											if str ~= capturedReusedSlot159Cell2[1] then
												capturedReusedSlot159Cell2[1] = str
											end

											local loopExitState15 = nil

											while true do
												if not flag3 then
													loopExitState15 = 1
												elseif capturedValue38.running then
													task.wait(2)

													if capturedValue38.running then
														flag3 = false
														local n3 = 0
														local loopExitState16 = nil

														while true do
															n3 += 1

															if n3 <= 5 then
																str = "Boss" .. n3
																if capturedCheckBossPresence(str) then
																	loopExitState16 = 1
																	break
																end
															else
																break
															end
														end

														if loopExitState16 == 1 then
															loopExitState15 = 2
															break
														else
															continue
														end
													end
												end

												break
											end

											if loopExitState15 == 1 then
												loopExitState14 = 1
												break
											elseif loopExitState15 == 2 then
												continue
											end

											break
										end

										if loopExitState14 == 1 then
											while true do
												flag = true
												_G.chestOpen = true
												capturedHoldRootPositionForDuration(10)
												_G.chestOpen = false
												temporaryValue62 = capturedGetRootPart7()

												if temporaryValue62 then
													vector2 = Vector3.zero
													temporaryValue62.AssemblyLinearVelocity = Vector3.zero
													temporaryValue62.AssemblyAngularVelocity = vector2
													temporaryValue62.CFrame = CFrame.new(capturedVector)
												end

												loopExitState13 = nil

												while true do
													if capturedValue38.running then
														task.wait(2)

														if capturedValue38.running then
															flag2 = false
															n2 = 0

															while true do
																n2 += 1

																if n2 <= 5 then
																	str2 = "Boss" .. n2

																	if capturedCheckBossPresence(str2) then
																		flag2 = true
																		flag = false

																		if str2 ~= capturedReusedSlot159Cell2[1] then
																			capturedReusedSlot159Cell2[1] = str2
																		end

																		break
																	end
																else
																	break
																end
															end

															if not flag2 then
																if not flag then
																	loopExitState13 = 1
																	break
																else
																	continue
																end
															else
																continue
															end
														end
													end

													break
												end

												if loopExitState13 == 1 then
													continue
												end
												break
											end
										end
									end
								end
							end
						end
					end)(callbackValue20))
				end
			end
		end)(startBossAttack, checkBossPresence, sharedCells[159], holdRootPositionForDuration, getRootPart, vector),
		stop = (function(capturedStopBossAttack)
			return function(callbackValue21)
				callbackValue21.running = false
				capturedStopBossAttack()
			end
		end)(stopBossAttack),
	}

	_G.chestOpen = false

	task.spawn((function(capturedGetRootPart8, capturedWorkspace8)
		return function()
			while true do
				task.wait(0.4)

				if _G.chestOpen then
					local temporaryValue63 = capturedGetRootPart8()
					local bossChest = capturedWorkspace8:FindFirstChild("BossChest")

					if temporaryValue63 then
						if bossChest then
							local iterateArray8 = ipairs
							local descendants4 = bossChest:GetDescendants()
							local iteratorNext17, iteratorState16, iteratorControl16 = iterateArray8(descendants4)
							local advanceIterator4 = makeResumableIterator(iteratorNext17, iteratorState16, iteratorControl16)

							while true do
								local packedReturns3 = table.pack(advanceIterator4())

								if packedReturns3[1] then
									local temporaryValue64 = packedReturns3[3]

									pcall((function(capturedValue39, capturedValue40)
										return function()
											if capturedValue39:IsA("ProximityPrompt") then
												if capturedValue39.Enabled then
													fireproximityprompt(capturedValue39)
												elseif capturedValue39:IsA("ClickDetector") then
													fireclickdetector(capturedValue39)
												elseif capturedValue39:IsA("BasePart") then
													if capturedValue39.CanTouch then
														if capturedValue39.Transparency < 1 then
															firetouchinterest(capturedValue39, capturedValue40, 0)
															task.wait(0.05)
															firetouchinterest(capturedValue39, capturedValue40, 1)
														end
													end
												end
											elseif capturedValue39:IsA("ClickDetector") then
												fireclickdetector(capturedValue39)
											elseif capturedValue39:IsA("BasePart") then
												if capturedValue39.CanTouch then
													if capturedValue39.Transparency < 1 then
														firetouchinterest(capturedValue39, capturedValue40, 0)
														task.wait(0.05)
														firetouchinterest(capturedValue39, capturedValue40, 1)
													end
												end
											end
										end
									end)(temporaryValue64, temporaryValue63))
								else
									break
								end
							end
						end
					end
				end
			end
		end
	end)(getRootPart, Workspace))

	task.spawn((function(capturedGetRootPart9, capturedBossMovementState2, capturedVector2)
		return function()
			while true do
				task.wait(1)
				local temporaryValue65 = capturedGetRootPart9()

				if temporaryValue65 then
					if not (temporaryValue65.Position.Y < -500) then
						continue
					end

					if not capturedBossMovementState2.on then
						pcall((function(capturedValue41)
							return function()
								local vector2 = Vector3.zero
								capturedValue41.AssemblyLinearVelocity = Vector3.zero
								capturedValue41.AssemblyAngularVelocity = vector2
								capturedValue41.CFrame = CFrame.new(capturedVector2)
							end
						end)(temporaryValue65))
					end
				end
			end
		end
	end)(getRootPart, bossMovementState, vector))

	bossSection:Slider({
		Title = "高度",
		Value = { Min = 10, Max = 200, Default = 70 },
		Step = 1,
		Callback = (function(capturedReusedSlot158Cell2)
			return function(callbackValue22)
				capturedReusedSlot158Cell2[1] = callbackValue22
			end
		end)(sharedCells[158]),
	})

	bossSection:Toggle({
		Title = "自动击杀BOSS",
		Value = false,
		Callback = (function(capturedBossController)
			return function(callbackValue23)
				if callbackValue23 then
					capturedBossController:start()
				else
					capturedBossController:stop()
				end
			end
		end)(bossController),
	})
end

-- [重建注释] 器材页和坐标配置。二元数组为“地区名称、器材列表”，器材项为“名称、X、Y、Z”。
local equipmentTab
equipmentTab = mainWindow:Tab({ Title = "器材", Icon = "dumbbell" })
local equipmentRegions
equipmentRegions = table.create(8)
local islandEquipmentRegion
islandEquipmentRegion = table.create(2)

do
	local entries18 = table.create(1)
	local entries19 = table.create(4)
	entries19[1] = "卧推"
	entries19[2] = -143
	entries19[3] = 13
	entries19[4] = 1977
	entries18[1] = entries19
	islandEquipmentRegion[1] = "小岛"
	islandEquipmentRegion[2] = entries18
end

local frostEquipmentRegion
frostEquipmentRegion = table.create(2)

do
	local entries20 = table.create(3)
	local entries21 = table.create(4)
	entries21[1] = "杠铃"
	entries21[2] = -2917
	entries21[3] = 12
	entries21[4] = -210
	sharedCells[187][1] = table.create(4)
	sharedCells[187][1][1] = "深蹲"
	sharedCells[187][1][2] = -2720
	sharedCells[187][1][3] = 9
	sharedCells[187][1][4] = -591
	sharedCells[188][1] = table.create(4)
	sharedCells[188][1][1] = "卧推"
	sharedCells[188][1][2] = -3009
	sharedCells[188][1][3] = 71
	sharedCells[188][1][4] = -338
	entries20[1] = entries21
	entries20[2] = sharedCells[187][1]
	entries20[3] = sharedCells[188][1]
	frostEquipmentRegion[1] = "冰霜健身房"
	frostEquipmentRegion[2] = entries20
end

local mythicalEquipmentRegion
mythicalEquipmentRegion = table.create(2)
local mythicalEquipmentEntries = table.create(3)
sharedCells[187][1] = table.create(4)
sharedCells[187][1][1] = "卧推"
sharedCells[187][1][2] = 2370
sharedCells[187][1][3] = 71
sharedCells[187][1][4] = 1243
sharedCells[188][1] = table.create(4)
sharedCells[188][1][1] = "引体向上"
sharedCells[188][1][2] = 2487
sharedCells[188][1][3] = 67
sharedCells[188][1][4] = 848
sharedCells[189][1] = table.create(4)
sharedCells[189][1][1] = "石头"
sharedCells[189][1][2] = 2668
sharedCells[189][1][3] = 42
sharedCells[189][1][4] = 1203
mythicalEquipmentEntries[1] = sharedCells[187][1]
mythicalEquipmentEntries[2] = sharedCells[188][1]
mythicalEquipmentEntries[3] = sharedCells[189][1]
mythicalEquipmentRegion[1] = "神话健身房"
mythicalEquipmentRegion[2] = mythicalEquipmentEntries

do
	local entries22 = table.create(2)
	sharedCells[187][1] = table.create(1)
	sharedCells[188][1] = table.create(4)
	sharedCells[188][1][1] = "卧推"
	sharedCells[188][1][2] = 4110
	sharedCells[188][1][3] = 1052
	sharedCells[188][1][4] = -3802
	sharedCells[187][1][1] = sharedCells[188][1]
	entries22[1] = "永恒健身房"
	entries22[2] = sharedCells[187][1]
	local entries23 = table.create(2)
	sharedCells[188][1] = table.create(4)
	sharedCells[189][1] = table.create(4)
	sharedCells[189][1][1] = "哑铃"
	sharedCells[189][1][2] = 4532
	sharedCells[189][1][3] = 1033
	sharedCells[189][1][4] = -4003
	sharedCells[190][1] = table.create(4)
	sharedCells[190][1][1] = "深蹲"
	sharedCells[190][1][2] = 4440
	sharedCells[190][1][3] = 1016
	sharedCells[190][1][4] = -4058
	local entries24 = table.create(4)
	entries24[1] = "卧推"
	entries24[2] = 4110
	entries24[3] = 1052
	entries24[4] = -3802
	local entries25 = table.create(4)
	entries25[1] = "引体向上"
	entries25[2] = 4304
	entries25[3] = 1057
	entries25[4] = -4122
	sharedCells[188][1][1] = sharedCells[189][1]
	sharedCells[188][1][2] = sharedCells[190][1]
	sharedCells[188][1][3] = entries24
	sharedCells[188][1][4] = entries25
	entries23[1] = "传奇健身房"
	entries23[2] = sharedCells[188][1]
	sharedCells[187][1] = table.create(2)
	sharedCells[189][1] = table.create(4)
	sharedCells[190][1] = table.create(4)
	sharedCells[190][1][1] = "哑铃"
	sharedCells[190][1][2] = -8773
	sharedCells[190][1][3] = 58
	sharedCells[190][1][4] = -5664
	local entries26 = table.create(4)
	entries26[1] = "深蹲"
	entries26[2] = -8758
	entries26[3] = 42
	entries26[4] = -6043
	local entries27 = table.create(4)
	entries27[1] = "卧推"
	entries27[2] = -8590
	entries27[3] = 78
	entries27[4] = -6045
	local entries28 = table.create(4)
	entries28[1] = "石头"
	entries28[2] = -8942
	entries28[3] = 52
	entries28[4] = -5692
	sharedCells[189][1][1] = sharedCells[190][1]
	sharedCells[189][1][2] = entries26
	sharedCells[189][1][3] = entries27
	sharedCells[189][1][4] = entries28
	sharedCells[187][1][1] = "肌肉健身房"
	sharedCells[187][1][2] = sharedCells[189][1]
	sharedCells[188][1] = table.create(2)
	sharedCells[190][1] = table.create(4)
	local entries29 = table.create(4)
	entries29[1] = "哑铃"
	entries29[2] = -8653
	entries29[3] = 48
	entries29[4] = 2089
	local entries30 = table.create(4)
	entries30[1] = "深蹲"
	entries30[2] = -8377
	entries30[3] = 31
	entries30[4] = 2864
	local entries31 = table.create(4)
	entries31[1] = "卧推"
	entries31[2] = -8175
	entries31[3] = 92
	entries31[4] = 1913
	local entries32 = table.create(4)
	entries32[1] = "石头"
	entries32[2] = -8617
	entries32[3] = 41
	entries32[4] = 2677
	sharedCells[190][1][1] = entries29
	sharedCells[190][1][2] = entries30
	sharedCells[190][1][3] = entries31
	sharedCells[190][1][4] = entries32
	sharedCells[188][1][1] = "丛林健身房"
	sharedCells[188][1][2] = sharedCells[190][1]
	sharedCells[189][1] = table.create(2)
	local entries33 = table.create(4)
	local entries34 = table.create(4)
	entries34[1] = "哑铃"
	entries34[2] = -5502
	entries34[3] = 103
	entries34[4] = 4639
	local entries35 = table.create(4)
	entries35[1] = "深蹲"
	entries35[2] = -5207
	entries35[3] = 103
	entries35[4] = 5454
	local entries36 = table.create(4)
	entries36[1] = "卧推"
	entries36[2] = -5015
	entries36[3] = 145
	entries36[4] = 4467
	local entries37 = table.create(4)
	entries37[1] = "石头"
	entries37[2] = -5456
	entries37[3] = 95
	entries37[4] = 5232
	entries33[1] = entries34
	entries33[2] = entries35
	entries33[3] = entries36
	entries33[4] = entries37
	sharedCells[189][1][1] = "工业健身房"
	sharedCells[189][1][2] = entries33
	equipmentRegions[1] = islandEquipmentRegion
	equipmentRegions[2] = frostEquipmentRegion
	equipmentRegions[3] = mythicalEquipmentRegion
	equipmentRegions[4] = entries22
	equipmentRegions[5] = entries23
end

equipmentRegions[6] = sharedCells[187][1]
equipmentRegions[7] = sharedCells[188][1]
equipmentRegions[8] = sharedCells[189][1]

do
	local iteratorNext18, iteratorState17, iteratorControl17 = ipairs(equipmentRegions)
	local advanceIterator5 = makeResumableIterator(iteratorNext18, iteratorState17, iteratorControl17)
	local temporaryValue66, temporaryValue67, temporaryValue68 = advanceIterator5()

	if temporaryValue66 then
		local temporaryValue69 = temporaryValue68[1]
		local temporaryValue70 = temporaryValue68[2]
		sharedCells[187][1] = {}
		sharedCells[188][1], sharedCells[189][1], sharedCells[190][1] = ipairs(temporaryValue70)
		local advanceIterator6 = makeResumableIterator(sharedCells[188][1], sharedCells[189][1], sharedCells[190][1])
		local temporaryValue71, temporaryValue72, temporaryValue73 = advanceIterator6()
		local temporaryValue74, dataTable11, loopEntryState3, temporaryValue75, advanceIterator7, temporaryValue76, temporaryValue77, temporaryValue78, temporaryValue79, temporaryValue80, temporaryValue81

		if temporaryValue71 then
			local temporaryValue82

			repeat
				table.insert(sharedCells[187][1], temporaryValue73[1])
				local temporaryValue83
				temporaryValue82, temporaryValue83, temporaryValue73 = advanceIterator6()
			until not temporaryValue82

			sharedCells[188][1] = sharedCells[187][1][1]
			sharedCells[189][1] = equipmentTab:Section({ Title = temporaryValue69 })
			temporaryValue74 = sharedCells[189][1]
			sharedCells[190][1] = sharedCells[189][1].Dropdown

			dataTable11 = {
				Title = "选择器材",
				Values = sharedCells[187][1],
				Value = sharedCells[188][1],
				Callback = (function(capturedReusedSlot188Cell)
					return function(callbackValue24)
						capturedReusedSlot188Cell[1] = callbackValue24
					end
				end)(sharedCells[188]),
			}

			loopEntryState3 = 1

			while true do
				if loopEntryState3 ~= 1 then
					table.insert(sharedCells[187][1], temporaryValue75[1])
					temporaryValue76, temporaryValue77, temporaryValue75 = advanceIterator7()

					if temporaryValue76 then
						loopEntryState3 = 2
					else
						sharedCells[188][1] = sharedCells[187][1][1]
						sharedCells[189][1] = equipmentTab:Section({ Title = temporaryValue78 })
						temporaryValue74 = sharedCells[189][1]
						sharedCells[190][1] = sharedCells[189][1].Dropdown

						dataTable11 = {
							Title = "选择器材",
							Values = sharedCells[187][1],
							Value = sharedCells[188][1],
							Callback = (function(capturedReusedSlot188Cell2)
								return function(callbackValue25)
									capturedReusedSlot188Cell2[1] = callbackValue25
								end
							end)(sharedCells[188]),
						}

						loopEntryState3 = 1
					end

					continue
				end

				sharedCells[190][1](temporaryValue74, dataTable11)

				sharedCells[189][1]:Button({
					Title = "使用",
					Callback = (function(capturedValue42, capturedReusedSlot188Cell3, capturedTeleportToCFrame, capturedTapKey)
						return function()
							local iteratorNext19, iteratorState18, iteratorControl18 = ipairs(capturedValue42)

							for k, entryValue23 in iteratorNext19, iteratorState18, iteratorControl18 do
								local entryValue24 = entryValue23

								if entryValue24[1] == capturedReusedSlot188Cell3[1] then
									local capturedTeleportToCFrame2 = capturedTeleportToCFrame
									local returnValues11, returnCount11 = (function(...) return {...}, select("#", ...) end)(CFrame.new(entryValue24[2], entryValue24[3], entryValue24[4]))
									capturedTeleportToCFrame2(table.unpack(returnValues11, 1, returnCount11))
									task.wait(0.4)
									local n = 1

									repeat
										capturedTapKey(Enum.KeyCode.E)
										task.wait(0.1)
										n += 1
									until not (n <= 5)

									return
								end
							end
						end
					end)(temporaryValue70, sharedCells[188], teleportToCFrame, tapKey),
				})

				sharedCells[188] = { [1] = sharedCells[188][1] }
				temporaryValue79, temporaryValue80, temporaryValue81 = advanceIterator5()

				if temporaryValue79 then
					temporaryValue78 = temporaryValue81[1]
					temporaryValue70 = temporaryValue81[2]
					sharedCells[187][1] = {}
					sharedCells[188][1], sharedCells[189][1], sharedCells[190][1] = ipairs(temporaryValue70)
					advanceIterator7 = makeResumableIterator(sharedCells[188][1], sharedCells[189][1], sharedCells[190][1])
					temporaryValue76, temporaryValue77, temporaryValue75 = advanceIterator7()

					if temporaryValue76 then
						loopEntryState3 = 2
					else
						sharedCells[188][1] = sharedCells[187][1][1]
						sharedCells[189][1] = equipmentTab:Section({ Title = temporaryValue78 })
						temporaryValue74 = sharedCells[189][1]
						sharedCells[190][1] = sharedCells[189][1].Dropdown

						dataTable11 = {
							Title = "选择器材",
							Values = sharedCells[187][1],
							Value = sharedCells[188][1],
							Callback = (function(capturedReusedSlot188Cell4)
								return function(callbackValue26)
									capturedReusedSlot188Cell4[1] = callbackValue26
								end
							end)(sharedCells[188]),
						}

						loopEntryState3 = 1
					end

					continue
				end

				break
			end
		else
			sharedCells[188][1] = sharedCells[187][1][1]
			sharedCells[189][1] = equipmentTab:Section({ Title = temporaryValue69 })
			local temporaryValue84 = sharedCells[189][1]
			sharedCells[190][1] = sharedCells[189][1].Dropdown

			local dataTable12 = {
				Title = "选择器材",
				Values = sharedCells[187][1],
				Value = sharedCells[188][1],
				Callback = (function(capturedReusedSlot188Cell5)
					return function(callbackValue27)
						capturedReusedSlot188Cell5[1] = callbackValue27
					end
				end)(sharedCells[188]),
			}

			local loopExitState17 = nil

			while true do
				sharedCells[190][1](temporaryValue84, dataTable12)

				sharedCells[189][1]:Button({
					Title = "使用",
					Callback = (function(capturedValue43, capturedReusedSlot188Cell6, capturedTeleportToCFrame3, capturedTapKey2)
						return function()
							local iteratorNext20, iteratorState19, iteratorControl19 = ipairs(capturedValue43)

							for k, entryValue25 in iteratorNext20, iteratorState19, iteratorControl19 do
								local entryValue26 = entryValue25

								if entryValue26[1] == capturedReusedSlot188Cell6[1] then
									local capturedTeleportToCFrame4 = capturedTeleportToCFrame3
									local returnValues12, returnCount12 = (function(...) return {...}, select("#", ...) end)(CFrame.new(entryValue26[2], entryValue26[3], entryValue26[4]))
									capturedTeleportToCFrame4(table.unpack(returnValues12, 1, returnCount12))
									task.wait(0.4)
									local n = 1

									repeat
										capturedTapKey2(Enum.KeyCode.E)
										task.wait(0.1)
										n += 1
									until not (n <= 5)

									return
								end
							end
						end
					end)(temporaryValue70, sharedCells[188], teleportToCFrame, tapKey),
				})

				sharedCells[188] = { [1] = sharedCells[188][1] }
				local temporaryValue85, temporaryValue86, temporaryValue87 = advanceIterator5()

				if temporaryValue85 then
					temporaryValue78 = temporaryValue87[1]
					temporaryValue70 = temporaryValue87[2]
					sharedCells[187][1] = {}
					sharedCells[188][1], sharedCells[189][1], sharedCells[190][1] = ipairs(temporaryValue70)
					advanceIterator7 = makeResumableIterator(sharedCells[188][1], sharedCells[189][1], sharedCells[190][1])
					local temporaryValue88, temporaryValue89
					temporaryValue88, temporaryValue89, temporaryValue75 = advanceIterator7()

					if temporaryValue88 then
						loopExitState17 = 1
						break
					else
						sharedCells[188][1] = sharedCells[187][1][1]
						sharedCells[189][1] = equipmentTab:Section({ Title = temporaryValue78 })
						temporaryValue84 = sharedCells[189][1]
						sharedCells[190][1] = sharedCells[189][1].Dropdown

						dataTable12 = {
							Title = "选择器材",
							Values = sharedCells[187][1],
							Value = sharedCells[188][1],
							Callback = (function(capturedReusedSlot188Cell7)
								return function(callbackValue28)
									capturedReusedSlot188Cell7[1] = callbackValue28
								end
							end)(sharedCells[188]),
						}
					end
				else
					break
				end
			end

			if loopExitState17 == 1 then
				loopEntryState3 = 2

				while true do
					if loopEntryState3 ~= 1 then
						table.insert(sharedCells[187][1], temporaryValue75[1])
						temporaryValue76, temporaryValue77, temporaryValue75 = advanceIterator7()

						if temporaryValue76 then
							loopEntryState3 = 2
						else
							sharedCells[188][1] = sharedCells[187][1][1]
							sharedCells[189][1] = equipmentTab:Section({ Title = temporaryValue78 })
							temporaryValue74 = sharedCells[189][1]
							sharedCells[190][1] = sharedCells[189][1].Dropdown

							dataTable11 = {
								Title = "选择器材",
								Values = sharedCells[187][1],
								Value = sharedCells[188][1],
								Callback = (function(capturedReusedSlot188Cell8)
									return function(callbackValue29)
										capturedReusedSlot188Cell8[1] = callbackValue29
									end
								end)(sharedCells[188]),
							}

							loopEntryState3 = 1
						end

						continue
					end

					sharedCells[190][1](temporaryValue74, dataTable11)

					sharedCells[189][1]:Button({
						Title = "使用",
						Callback = (function(capturedValue44, capturedReusedSlot188Cell9, capturedTeleportToCFrame5, capturedTapKey3)
							return function()
								local iteratorNext21, iteratorState20, iteratorControl20 = ipairs(capturedValue44)

								for k, entryValue27 in iteratorNext21, iteratorState20, iteratorControl20 do
									local entryValue28 = entryValue27

									if entryValue28[1] == capturedReusedSlot188Cell9[1] then
										local capturedTeleportToCFrame6 = capturedTeleportToCFrame5
										local returnValues13, returnCount13 = (function(...) return {...}, select("#", ...) end)(CFrame.new(entryValue28[2], entryValue28[3], entryValue28[4]))
										capturedTeleportToCFrame6(table.unpack(returnValues13, 1, returnCount13))
										task.wait(0.4)
										local n = 1

										repeat
											capturedTapKey3(Enum.KeyCode.E)
											task.wait(0.1)
											n += 1
										until not (n <= 5)

										return
									end
								end
							end
						end)(temporaryValue70, sharedCells[188], teleportToCFrame, tapKey),
					})

					sharedCells[188] = { [1] = sharedCells[188][1] }
					temporaryValue79, temporaryValue80, temporaryValue81 = advanceIterator5()

					if temporaryValue79 then
						temporaryValue78 = temporaryValue81[1]
						temporaryValue70 = temporaryValue81[2]
						sharedCells[187][1] = {}
						sharedCells[188][1], sharedCells[189][1], sharedCells[190][1] = ipairs(temporaryValue70)
						advanceIterator7 = makeResumableIterator(sharedCells[188][1], sharedCells[189][1], sharedCells[190][1])
						temporaryValue76, temporaryValue77, temporaryValue75 = advanceIterator7()

						if temporaryValue76 then
							loopEntryState3 = 2
						else
							sharedCells[188][1] = sharedCells[187][1][1]
							sharedCells[189][1] = equipmentTab:Section({ Title = temporaryValue78 })
							temporaryValue74 = sharedCells[189][1]
							sharedCells[190][1] = sharedCells[189][1].Dropdown

							dataTable11 = {
								Title = "选择器材",
								Values = sharedCells[187][1],
								Value = sharedCells[188][1],
								Callback = (function(capturedReusedSlot188Cell10)
									return function(callbackValue30)
										capturedReusedSlot188Cell10[1] = callbackValue30
									end
								end)(sharedCells[188]),
							}

							loopEntryState3 = 1
						end

						continue
					end

					break
				end
			end
		end
	end
end

-- [重建注释] 宠物页：水晶选择与开启、各类宠物的购买和进化控件。
local petsTab
petsTab = mainWindow:Tab({ Title = "宠物", Icon = "paw-print" })

do
	local crystalSection = petsTab:Section({ Title = "水晶功能", Box = true })
	local crystalLabels = {}
	local crystalNamesByLabel = {}

	sharedCells[187][1], sharedCells[188][1], sharedCells[189][1] = pairs({
		["Blue Crystal"] = "蓝色水晶",
		["Green Crystal"] = "绿色水晶",
		["Frost Crystal"] = "冰霜水晶",
		["Mythical Crystal"] = "神话水晶",
		["Inferno Crystal"] = "地狱火水晶",
		["Legends Crystal"] = "传奇水晶",
		["Galaxy Oracle Crystal"] = "银河水晶",
		["Muscle Elite Crystal"] = "肌肉水晶",
		["Jungle Crystal"] = "丛林水晶",
		["Industrial Crystal"] = "工业水晶",
	})

	for k, entryValue29 in sharedCells[187][1], sharedCells[188][1], sharedCells[189][1] do
		table.insert(crystalLabels, entryValue29)
		crystalNamesByLabel[entryValue29] = k
	end

	table.sort(crystalLabels)
	sharedCells[187][1] = nil
	sharedCells[188][1] = 1

	crystalSection:Dropdown({
		Title = "选择水晶",
		Multi = false,
		Value = "",
		AllowNone = true,
		Values = crystalLabels,
		Callback = (function(capturedReusedSlot187Cell, capturedCrystalNamesByLabel)
			return function(callbackValue31)
				capturedReusedSlot187Cell[1] = capturedCrystalNamesByLabel[callbackValue31]
			end
		end)(sharedCells[187], crystalNamesByLabel),
	})

	sharedCells[189][1] = crystalSection.Dropdown
	local dataTable13 = { Title = "开启数量", Multi = false, Value = "1", AllowNone = false }
	local entries38 = table.create(3)
	entries38[1] = "1"
	entries38[2] = "3"
	entries38[3] = "10"
	dataTable13.Values = entries38

	dataTable13.Callback = (function(capturedReusedSlot188Cell11)
		return function(callbackValue32)
			capturedReusedSlot188Cell11[1] = tonumber(callbackValue32) or 1
		end
	end)(sharedCells[188])

	sharedCells[189][1](crystalSection, dataTable13)
	sharedCells[189][1] = false
	sharedCells[190][1] = nil

	local runCrystalOpenLoop
	do
		local capturedReusedSlot189Cell, capturedReusedSlot187Cell2, capturedReplicatedStorage4, capturedReusedSlot188Cell12 = sharedCells[189], sharedCells[187], ReplicatedStorage, sharedCells[188]
		runCrystalOpenLoop = function()
			while capturedReusedSlot189Cell[1] do
				task.wait(0.1)

				if capturedReusedSlot187Cell2[1] then
					pcall(function()
						capturedReplicatedStorage4.rEvents.openCrystalRemote:InvokeServer("openCrystalBulk", capturedReusedSlot187Cell2[1], capturedReusedSlot188Cell12[1])
					end)
				end
			end
		end
	end

	crystalSection:Toggle({
		Title = "自动开水晶",
		Value = false,
		Callback = (function(capturedReusedSlot189Cell2, capturedReusedSlot187Cell3, capturedReusedSlot190Cell, capturedRunCrystalOpenLoop)
			return function(callbackValue33)
				capturedReusedSlot189Cell2[1] = callbackValue33

				if callbackValue33 then
					if not capturedReusedSlot187Cell3[1] then
						capturedReusedSlot189Cell2[1] = false
					else
						capturedReusedSlot190Cell[1] = task.spawn(capturedRunCrystalOpenLoop)
					end
				elseif capturedReusedSlot190Cell[1] then
					task.cancel(capturedReusedSlot190Cell[1])
					capturedReusedSlot190Cell[1] = nil
				end
			end
		end)(sharedCells[189], sharedCells[187], sharedCells[190], runCrystalOpenLoop),
	})
end

petsTab:Section({ Title = "购买宠物or光环" })
local petShopCatalog
petShopCatalog = {}

do
	local entries39 = table.create(6)
	local entries40 = table.create(2)
	entries40[1] = "顶峰霸主"
	entries40[2] = "Apex Overlord"
	local entries41 = table.create(2)
	entries41[1] = "泰坦反应堆"
	entries41[2] = "Titan Reactor"
	local entries42 = table.create(2)
	entries42[1] = "等离子掠夺者"
	entries42[2] = "Plasma Ravager"
	local entries43 = table.create(2)
	entries43[1] = "反应堆兽"
	entries43[2] = "Reactor Beast"
	local entries44 = table.create(2)
	entries44[1] = "伏特爪"
	entries44[2] = "Volt Talon"
	local entries45 = table.create(2)
	entries45[1] = "核心小狗"
	entries45[2] = "Core Pup"
	entries39[1] = entries40
	entries39[2] = entries41
	entries39[3] = entries42
	entries39[4] = entries43
	entries39[5] = entries44
	entries39[6] = entries45
	petShopCatalog["工业水晶"] = entries39
end

do
	local entries46 = table.create(6)
	local entries47 = table.create(2)
	entries47[1] = "金色维京人"
	entries47[2] = "Golden Viking"
	local entries48 = table.create(2)
	entries48[1] = "大超新星光环"
	entries48[2] = "Grand Supernova"
	local entries49 = table.create(2)
	entries49[1] = "永恒超级打击光环"
	entries49[2] = "Eternal Megastrike"
	local entries50 = table.create(2)
	entries50[1] = "肌肉老师"
	entries50[2] = "Muscle Sensei"
	local entries51 = table.create(2)
	entries51[1] = "熵爆光环"
	entries51[2] = "Entropic Blast"
	local entries52 = table.create(2)
	entries52[1] = "霓虹守护者"
	entries52[2] = "Neon Guardian"
	entries46[1] = entries47
	entries46[2] = entries48
	entries46[3] = entries49
	entries46[4] = entries50
	entries46[5] = entries51
	entries46[6] = entries52
	petShopCatalog["丛林水晶"] = entries46
end

do
	local entries53 = table.create(6)
	local entries54 = table.create(2)
	entries54[1] = "超能炼狱光环"
	entries54[2] = "Ultra Inferno"
	local entries55 = table.create(2)
	entries55[1] = "蔚蓝苔原光环"
	entries55[2] = "Azure Tundra"
	local entries56 = table.create(2)
	entries56[1] = "永恒打击利维坦"
	entries56[2] = "Eternal Strike Leviathan"
	local entries57 = table.create(2)
	entries57[1] = "雷电幻影"
	entries57[2] = "Lightning Strike Phantom"
	local entries58 = table.create(2)
	entries58[1] = "暗星猎手"
	entries58[2] = "Darkstar Hunter"
	local entries59 = table.create(2)
	entries59[1] = "肌肉之王光环"
	entries59[2] = "Muscle King"
	entries53[1] = entries54
	entries53[2] = entries55
	entries53[3] = entries56
	entries53[4] = entries57
	entries53[5] = entries58
	entries53[6] = entries59
	petShopCatalog["肌肉水晶"] = entries53
end

do
	local entries60 = table.create(6)
	local entries61 = table.create(2)
	entries61[1] = "冰波传奇企鹅"
	entries61[2] = "Frostwave Legends Penguin"
	local entries62 = table.create(2)
	entries62[1] = "幻影创世龙"
	entries62[2] = "Phantom Genesis Dragon"
	local entries63 = table.create(2)
	entries63[1] = "黑暗蝎尾怪传奇"
	entries63[2] = "Dark Legends Manticore"
	local entries64 = table.create(2)
	entries64[1] = "终极新星飞马"
	entries64[2] = "Ultimate Supernova Pegasus"
	local entries65 = table.create(2)
	entries65[1] = "以太仙灵小兔"
	entries65[2] = "Aether Spirit Bunny"
	local entries66 = table.create(2)
	entries66[1] = "赛博龙"
	entries66[2] = "Cybernetic Showdown Dragon"
	entries60[1] = entries61
	entries60[2] = entries62
	entries60[3] = entries63
	entries60[4] = entries64
	entries60[5] = entries65
	entries60[6] = entries66
	petShopCatalog["传奇水晶"] = entries60
end

do
	local entries67 = table.create(6)
	local entries68 = table.create(2)
	entries68[1] = "史诗光环"
	entries68[2] = "Epic"
	local entries69 = table.create(2)
	entries69[1] = "红色释火者"
	entries69[2] = "Red Firecaster"
	local entries70 = table.create(2)
	entries70[1] = "白色飞马"
	entries70[2] = "White Pegasus"
	local entries71 = table.create(2)
	entries71[1] = "金色凤凰"
	entries71[2] = "Golden Pheonix"
	local entries72 = table.create(2)
	entries72[1] = "独特光环"
	entries72[2] = "Unique"
	local entries73 = table.create(2)
	entries73[1] = "地狱火龙"
	entries73[2] = "Infernal Dragon"
	entries67[1] = entries68
	entries67[2] = entries69
	entries67[3] = entries70
	entries67[4] = entries71
	entries67[5] = entries72
	entries67[6] = entries73
	petShopCatalog["永恒水晶"] = entries67
end

do
	local entries74 = table.create(4)
	local entries75 = table.create(2)
	entries75[1] = "红色龙"
	entries75[2] = "Red Dragon"
	local entries76 = table.create(2)
	entries76[1] = "稀有光环"
	entries76[2] = "Rare"
	local entries77 = table.create(2)
	entries77[1] = "紫色猎鹰"
	entries77[2] = "Purple Falcon"
	local entries78 = table.create(2)
	entries78[1] = "蓝色释火者"
	entries78[2] = "Blue Firecaster"
	entries74[1] = entries75
	entries74[2] = entries76
	entries74[3] = entries77
	entries74[4] = entries78
	petShopCatalog["神话水晶"] = entries74
end

do
	local entries79 = table.create(5)
	local entries80 = table.create(2)
	entries80[1] = "黄色蝴蝶"
	entries80[2] = "Yellow Butterfly"
	local entries81 = table.create(2)
	entries81[1] = "高级光环"
	entries81[2] = "Advanced"
	local entries82 = table.create(2)
	entries82[1] = "紫色龙"
	entries82[2] = "Purple Dragon"
	local entries83 = table.create(2)
	entries83[1] = "橙色飞马"
	entries83[2] = "Orange Pegasus"
	local entries84 = table.create(2)
	entries84[1] = "蓝色凤凰"
	entries84[2] = "Blue Pheonix"
	entries79[1] = entries80
	entries79[2] = entries81
	entries79[3] = entries82
	entries79[4] = entries83
	entries79[5] = entries84
	petShopCatalog["冰霜水晶"] = entries79
end

do
	local entries85 = table.create(5)
	local entries86 = table.create(2)
	entries86[1] = "银色小狗"
	entries86[2] = "Silver Dog"
	local entries87 = table.create(2)
	entries87[1] = "黑暗魔像"
	entries87[2] = "Dark Golem"
	local entries88 = table.create(2)
	entries88[1] = "绿色蝴蝶"
	entries88[2] = "Green Butterfly"
	local entries89 = table.create(2)
	entries89[1] = "基础光环"
	entries89[2] = "Basic"
	local entries90 = table.create(2)
	entries90[1] = "赤红猎鹰"
	entries90[2] = "Crimson Falcon"
	entries85[1] = entries86
	entries85[2] = entries87
	entries85[3] = entries88
	entries85[4] = entries89
	entries85[5] = entries90
	petShopCatalog["沙滩水晶"] = entries85
end

do
	local entries91 = table.create(5)
	local entries92 = table.create(2)
	entries92[1] = "橙色刺猬"
	entries92[2] = "Orange Hedgehog"
	local entries93 = table.create(2)
	entries93[1] = "蓝色小鸟"
	entries93[2] = "Blue Birdie"
	local entries94 = table.create(2)
	entries94[1] = "红色小猫"
	entries94[2] = "Red Kitty"
	local entries95 = table.create(2)
	entries95[1] = "蓝色小兔"
	entries95[2] = "Blue Bunny"
	local entries96 = table.create(2)
	entries96[1] = "黑暗德古拉"
	entries96[2] = "Dark Vampy"
	entries91[1] = entries92
	entries91[2] = entries93
	entries91[3] = entries94
	entries91[4] = entries95
	entries91[5] = entries96
	petShopCatalog["大厅水晶"] = entries91
end

do
	-- [重建注释] 按名称查找宠物商店条目；先查 cPetShopFolder，再扫描名称含 shop 的文件夹。
	local findPetShopEntry
	do
		local capturedReplicatedStorage5 = ReplicatedStorage
		findPetShopEntry = function(petName2)
			local shared = capturedReplicatedStorage5:FindFirstChild("shared")

			if shared then
				local runtime = shared:FindFirstChild("runtime")

				if runtime then
					local cPetShopFolder = runtime:FindFirstChild("cPetShopFolder")

					if cPetShopFolder then
						if cPetShopFolder:FindFirstChild(petName2) then
							return cPetShopFolder:FindFirstChild(petName2)
						end
					end

					local iterateArray9 = ipairs
					local children5 = runtime:GetChildren()
					local iteratorNext22, iteratorState21, iteratorControl21 = iterateArray9(children5)
					local advanceIterator8 = makeResumableIterator(iteratorNext22, iteratorState21, iteratorControl21)
					local matchingShopEntry

					while true do
						local packedReturns4 = table.pack(advanceIterator8())

						if packedReturns4[1] then
							local runtimeFolder = packedReturns4[3]

							if runtimeFolder:IsA("Folder") then
								if runtimeFolder.Name:lower():find("shop") then
									matchingShopEntry = runtimeFolder:FindFirstChild(petName2)
									if matchingShopEntry then
										break
									end
								end
							end
						else
							return nil
						end
					end

					return matchingShopEntry
				end
			end

			return nil
		end
	end

	-- [重建注释] 按类别生成宠物商店区域，分别维护选择项及自动购买/进化任务状态。
	local createPetShopSection
	do
		local capturedPetsTab, capturedPetShopCatalog, capturedFindPetShopEntry, capturedReplicatedStorage6 = petsTab, petShopCatalog, findPetShopEntry, ReplicatedStorage
		createPetShopSection = function(categoryName)
			local petShopSection = capturedPetsTab:Section({ Title = categoryName, Box = true })
			local petDisplayNames = {}
			local petNamesByLabel = {}
			local iteratorNext23, iteratorState22, iteratorControl22 = ipairs(capturedPetShopCatalog[categoryName])
			local advanceIterator9 = makeResumableIterator(iteratorNext23, iteratorState22, iteratorControl22)

			while true do
				local packedReturns5 = table.pack(advanceIterator9())

				if packedReturns5[1] then
					local petCatalogEntry = packedReturns5[3]
					local petDisplayName = petCatalogEntry[1]
					local internalPetName = petCatalogEntry[2]
					table.insert(petDisplayNames, petDisplayName)
					petNamesByLabel[petDisplayName] = internalPetName
				else
					break
				end
			end

			local petShopState = { selected = nil, buyThread = nil, evolveThread = nil, autoBuy = false, autoEvolve = false }

			petShopSection:Dropdown({
				Title = "选择",
				Multi = false,
				Value = "",
				AllowNone = true,
				Values = petDisplayNames,
				Callback = (function(capturedPetShopState, capturedPetNamesByLabel)
					return function(callbackValue34)
						capturedPetShopState.selected = capturedPetNamesByLabel[callbackValue34]
					end
				end)(petShopState, petNamesByLabel),
			})

			petShopSection:Toggle({
				Title = "自动购买",
				Value = false,
				Callback = (function(capturedPetShopState2)
					return function(autoBuy)
						capturedPetShopState2.autoBuy = autoBuy

						if autoBuy then
							if not capturedPetShopState2.selected then
								capturedPetShopState2.autoBuy = false
							else
								capturedPetShopState2.buyThread = task.spawn(function()
									while capturedPetShopState2.autoBuy do
										task.wait(0.5)
										local selected = capturedPetShopState2.selected

										if selected then
											pcall((function(capturedSelected)
												return function()
													local temporaryValue90 = capturedFindPetShopEntry(capturedSelected)

													if temporaryValue90 then
														capturedReplicatedStorage6.rEvents.cPetShopRemote:InvokeServer(temporaryValue90)
													end
												end
											end)(selected))
										end
									end
								end)
							end
						elseif capturedPetShopState2.buyThread then
							task.cancel(capturedPetShopState2.buyThread)
							capturedPetShopState2.buyThread = nil
						end
					end
				end)(petShopState),
			})

			petShopSection:Toggle({
				Title = "自动进化",
				Value = false,
				Callback = (function(capturedPetShopState3)
					return function(autoEvolve)
						capturedPetShopState3.autoEvolve = autoEvolve

						if autoEvolve then
							if not capturedPetShopState3.selected then
								capturedPetShopState3.autoEvolve = false
							else
								capturedPetShopState3.evolveThread = task.spawn(function()
									while capturedPetShopState3.autoEvolve do
										task.wait(0.5)
										local selected = capturedPetShopState3.selected

										if selected then
											pcall((function(capturedSelected2)
												return function()
													capturedReplicatedStorage6.rEvents.petEvolveEvent:FireServer("evolvePet", capturedSelected2)
												end
											end)(selected))
										end
									end
								end)
							end
						elseif capturedPetShopState3.evolveThread then
							task.cancel(capturedPetShopState3.evolveThread)
							capturedPetShopState3.evolveThread = nil
						end
					end
				end)(petShopState),
			})

			return petShopSection
		end
	end

	local entries97 = table.create(9)
	entries97[1] = "工业水晶"
	entries97[2] = "丛林水晶"
	entries97[3] = "肌肉水晶"
	entries97[4] = "传奇水晶"
	entries97[5] = "永恒水晶"
	entries97[6] = "神话水晶"
	entries97[7] = "冰霜水晶"
	entries97[8] = "沙滩水晶"
	entries97[9] = "大厅水晶"
	local iteratorNext24, iteratorState23, iteratorControl23 = ipairs(entries97)

	for k, entryValue30 in iteratorNext24, iteratorState23, iteratorControl23 do
		createPetShopSection(entryValue30)
	end
end

do
	-- [重建注释] 目标列表：wl 为白名单，bl 为指定目标；ka/kb 是原字段，分别跟踪两种循环。字段名保持不变。
	local targetNameLists = { wl = {}, bl = {} }
	local combatLoopGenerations = { ka = 0, kb = 0 }
	local combatSettings = { ka = false, kb = false, wlF = false }
	local gravityOverrideState = { on = false, conn = nil, orig = nil }

	-- [重建注释] 忽略大小写判断名称是否在列表中；未命中时沿用原逻辑的隐式 nil。
	local function containsNameIgnoreCase(names, candidateName)
		local iteratorNext25, iteratorState24, iteratorControl24 = ipairs(names)
		local advanceIterator10 = makeResumableIterator(iteratorNext25, iteratorState24, iteratorControl24)

		while true do
			local packedReturns6 = table.pack(advanceIterator10())

			if packedReturns6[1] then
				if packedReturns6[3]:lower() == candidateName:lower() then
					return true
				end
			else
				break
			end
		end
	end

	-- [重建注释] 要求目标拥有存活 Humanoid 和 HumanoidRootPart；空对象的返回值仍按原逻辑保留。
	local function hasLivingCharacter(player3)
		local character = player3

		if character then
			character = player3.Character
		end

		local humanoid = character

		if humanoid then
			humanoid = character:FindFirstChildOfClass("Humanoid")
		end

		local flag = humanoid

		if flag then
			flag = humanoid.Health > 0
		end

		if flag then
			flag = character:FindFirstChild("HumanoidRootPart") ~= nil
		end

		return flag
	end

	-- [重建注释] 读取 ForceField 或 SpawnProtectedUntil 属性判断出生保护。
	local function hasSpawnProtection(player4)
		if player4 then
			if player4.Character then
				if player4.Character:FindFirstChildOfClass("ForceField") then
					return true
				end
				local attribute = player4.Character:GetAttribute("SpawnProtectedUntil")
				local flag = typeof(attribute) == "number"

				if flag then
					flag = workspace:GetServerTimeNow() < attribute
				end

				return flag
			end
		end

		return false
	end

	-- [重建注释] 返回本地存活角色、Humanoid、根部件三个值；失败时无返回值。
	local getLivingLocalCharacter
	do
		local capturedPlayerReference5 = playerReference
		getLivingLocalCharacter = function()
			local character = capturedPlayerReference5.Character
			local humanoid = character

			if humanoid then
				humanoid = character:FindFirstChildOfClass("Humanoid")
			end

			local humanoidRootPart = character

			if humanoidRootPart then
				humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			end

			if humanoid then
				if humanoid.Health > 0 then
					if humanoidRootPart then
						return character, humanoid, humanoidRootPart
					end
				end
			end
		end
	end

	local attackSelectedPlayer
	do
		local capturedHasLivingCharacter, capturedHasSpawnProtection, capturedPlayerReference6, capturedGetLivingLocalCharacter, capturedRunService4 = hasLivingCharacter, hasSpawnProtection, playerReference, getLivingLocalCharacter, runService
		attackSelectedPlayer = function(callbackValue35, callbackValue36)
			if capturedHasLivingCharacter(callbackValue35) then
				if not capturedHasSpawnProtection(callbackValue35) then
					if not capturedHasSpawnProtection(capturedPlayerReference6) then
						local temporaryValue91, temporaryValue92, temporaryValue93 = capturedGetLivingLocalCharacter()
						local humanoidRootPart = callbackValue35.Character:FindFirstChild("HumanoidRootPart")

						if temporaryValue93 then
							if humanoidRootPart then
								local n = 1

								repeat
									temporaryValue93.CFrame = humanoidRootPart.CFrame * CFrame.new(0, callbackValue36, 0)
									temporaryValue93.AssemblyLinearVelocity = Vector3.zero
									temporaryValue93.AssemblyAngularVelocity = Vector3.zero
									capturedRunService4.Heartbeat:Wait()
									n += 1
								until not (n <= 2)

								local temporaryValue94 = capturedGetLivingLocalCharacter()
								local humanoid = callbackValue35.Character:FindFirstChildOfClass("Humanoid")

								if temporaryValue94 then
									if humanoid then
										if not capturedHasSpawnProtection(callbackValue35) then
											local leftHand = temporaryValue94:FindFirstChild("LeftHand") or temporaryValue94:FindFirstChild("RightHand")

											if leftHand then
												local punch = temporaryValue94:FindFirstChild("Punch") or capturedPlayerReference6.Backpack:FindFirstChild("Punch")
												local humanoid2 = temporaryValue94:FindFirstChildOfClass("Humanoid")

												if punch then
													if punch.Parent ~= temporaryValue94 then
														if humanoid2 then
															humanoid2:EquipTool(punch)
														end
													end
												end

												local health = humanoid.Health

												if pcall((function(capturedHumanoidRootPart2, capturedLeftHand)
													return function()
														firetouchinterest(capturedHumanoidRootPart2, capturedLeftHand, 0)
														firetouchinterest(capturedHumanoidRootPart2, capturedLeftHand, 1)
														local muscleEvent2 = capturedPlayerReference6.muscleEvent
														local muscleEvent22 = muscleEvent2
														local fireServer = muscleEvent2.FireServer
														local flag = capturedLeftHand.Name == "LeftHand"

														if flag then
															flag = "leftHand"
														end

														fireServer(muscleEvent22, "punch", flag or "rightHand")
													end
												end)(humanoidRootPart, leftHand)) then
													local n2 = 1

													while true do
														capturedRunService4.Heartbeat:Wait()

														if capturedHasLivingCharacter(callbackValue35) then
															if not (humanoid.Health < health) then
																if capturedHasSpawnProtection(callbackValue35) then
																	return false, false
																end
																n2 += 1
																if n2 <= 4 then
																	continue
																end
																return false, true
															end
														end

														break
													end

													return true, true
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end

			return false, false
		end
	end

	-- [重建注释] 条件循环：由 shouldContinue 决定继续，由 performIteration 的结果决定等待方式。
	local spawnConditionalLoop
	do
		local capturedRunService5 = runService
		spawnConditionalLoop = function(shouldContinue, performIteration)
			task.spawn((function(capturedShouldContinue, capturedPerformIteration)
				return function()
					while capturedShouldContinue() do
						if not capturedPerformIteration() then
							task.wait(0.1)
						else
							capturedRunService5.Heartbeat:Wait()
						end
					end
				end
			end)(shouldContinue, performIteration))
		end
	end

	local startAllTargetsLoop
	do
		local capturedCombatLoopGenerations, capturedSpawnConditionalLoop, capturedCombatSettings, capturedPlayersService, capturedPlayerReference7, capturedContainsNameIgnoreCase, capturedTargetNameLists, capturedHasLivingCharacter2, capturedHasSpawnProtection2, capturedAttackSelectedPlayer = combatLoopGenerations, spawnConditionalLoop, combatSettings, playersService, playerReference, containsNameIgnoreCase, targetNameLists, hasLivingCharacter, hasSpawnProtection, attackSelectedPlayer
		startAllTargetsLoop = function()
			capturedCombatLoopGenerations.ka = capturedCombatLoopGenerations.ka + 1
			local ka = capturedCombatLoopGenerations.ka

			capturedSpawnConditionalLoop((function(capturedKa)
				return function()
					local ka2 = capturedCombatSettings.ka

					if ka2 then
						ka2 = capturedCombatLoopGenerations.ka == capturedKa
					end

					return ka2
				end
			end)(ka), (function(capturedKa2)
				return function()
					local flag = false
					local iterateArray10 = ipairs
					local playerList3 = capturedPlayersService:GetPlayers()
					local iteratorNext26, iteratorState25, iteratorControl25 = iterateArray10(playerList3)
					local advanceIterator11 = makeResumableIterator(iteratorNext26, iteratorState25, iteratorControl25)

					while true do
						local packedReturns7 = table.pack(advanceIterator11())
						local temporaryValue95 = packedReturns7[3]

						if packedReturns7[1] then
							local temporaryValue96 = temporaryValue95

							if temporaryValue96 ~= capturedPlayerReference7 then
								if not capturedContainsNameIgnoreCase(capturedTargetNameLists.wl, temporaryValue96.Name) then
									if capturedHasLivingCharacter2(temporaryValue96) then
										if not capturedHasSpawnProtection2(temporaryValue96) then
											flag = true
											local n = 1
											local loopExitState18 = nil

											while true do
												local loopExitState19, temporaryValue97

												if capturedCombatSettings.ka then
													if capturedCombatLoopGenerations.ka ~= capturedKa2 then
														loopExitState19 = nil

														while true do
															packedReturns7 = table.pack(advanceIterator11())
															temporaryValue97 = packedReturns7[3]

															if packedReturns7[1] then
																temporaryValue96 = temporaryValue97

																if temporaryValue96 ~= capturedPlayerReference7 then
																	if not capturedContainsNameIgnoreCase(capturedTargetNameLists.wl, temporaryValue96.Name) then
																		if capturedHasLivingCharacter2(temporaryValue96) then
																			if not capturedHasSpawnProtection2(temporaryValue96) then
																				loopExitState19 = 1
																				break
																			end
																		end
																	end
																end
															else
																break
															end
														end

														if loopExitState19 == 1 then
															continue
														end
													elseif capturedHasLivingCharacter2(temporaryValue96) then
														if not capturedHasSpawnProtection2(temporaryValue96) then
															if capturedContainsNameIgnoreCase(capturedTargetNameLists.wl, temporaryValue96.Name) then
																loopExitState19 = nil

																while true do
																	packedReturns7 = table.pack(advanceIterator11())
																	temporaryValue97 = packedReturns7[3]

																	if packedReturns7[1] then
																		temporaryValue96 = temporaryValue97

																		if temporaryValue96 ~= capturedPlayerReference7 then
																			if not capturedContainsNameIgnoreCase(capturedTargetNameLists.wl, temporaryValue96.Name) then
																				if capturedHasLivingCharacter2(temporaryValue96) then
																					if not capturedHasSpawnProtection2(temporaryValue96) then
																						loopExitState19 = 1
																						break
																					end
																				end
																			end
																		end
																	else
																		break
																	end
																end

																if loopExitState19 == 1 then
																	continue
																end
															else
																loopExitState18 = 1
																break
															end
														else
															loopExitState19 = nil

															while true do
																packedReturns7 = table.pack(advanceIterator11())
																temporaryValue97 = packedReturns7[3]

																if packedReturns7[1] then
																	temporaryValue96 = temporaryValue97

																	if temporaryValue96 ~= capturedPlayerReference7 then
																		if not capturedContainsNameIgnoreCase(capturedTargetNameLists.wl, temporaryValue96.Name) then
																			if capturedHasLivingCharacter2(temporaryValue96) then
																				if not capturedHasSpawnProtection2(temporaryValue96) then
																					loopExitState19 = 1
																					break
																				end
																			end
																		end
																	end
																else
																	break
																end
															end

															if loopExitState19 == 1 then
																continue
															end
														end
													else
														loopExitState19 = nil

														while true do
															packedReturns7 = table.pack(advanceIterator11())
															temporaryValue97 = packedReturns7[3]

															if packedReturns7[1] then
																temporaryValue96 = temporaryValue97

																if temporaryValue96 ~= capturedPlayerReference7 then
																	if not capturedContainsNameIgnoreCase(capturedTargetNameLists.wl, temporaryValue96.Name) then
																		if capturedHasLivingCharacter2(temporaryValue96) then
																			if not capturedHasSpawnProtection2(temporaryValue96) then
																				loopExitState19 = 1
																				break
																			end
																		end
																	end
																end
															else
																break
															end
														end

														if loopExitState19 == 1 then
															continue
														end
													end

													break
												end

												loopExitState19 = nil

												while true do
													packedReturns7 = table.pack(advanceIterator11())
													temporaryValue97 = packedReturns7[3]

													if packedReturns7[1] then
														temporaryValue96 = temporaryValue97

														if temporaryValue96 ~= capturedPlayerReference7 then
															if not capturedContainsNameIgnoreCase(capturedTargetNameLists.wl, temporaryValue96.Name) then
																if capturedHasLivingCharacter2(temporaryValue96) then
																	if not capturedHasSpawnProtection2(temporaryValue96) then
																		loopExitState19 = 1
																		break
																	end
																end
															end
														end
													else
														break
													end
												end

												if loopExitState19 == 1 then
													continue
												end
												break
											end

											if loopExitState18 == 1 then
												while true do
													local temporaryValue98, temporaryValue99 = capturedAttackSelectedPlayer(temporaryValue96, 3.5)
													local temporaryValue100 = temporaryValue98
													local loopEntryState4

													if not temporaryValue99 then
														loopEntryState4 = 1
													else
														if not temporaryValue100 then
															task.wait(0.05)
														end

														loopEntryState4 = 2
													end

													local loopExitState20 = nil

													while true do
														if loopEntryState4 == 1 then
															packedReturns7 = table.pack(advanceIterator11())
															local temporaryValue101 = packedReturns7[3]

															if packedReturns7[1] then
																temporaryValue96 = temporaryValue101

																if temporaryValue96 ~= capturedPlayerReference7 then
																	if not capturedContainsNameIgnoreCase(capturedTargetNameLists.wl, temporaryValue96.Name) then
																		if capturedHasLivingCharacter2(temporaryValue96) then
																			if not capturedHasSpawnProtection2(temporaryValue96) then
																				n = 0
																				loopEntryState4 = 2
																			else
																				loopEntryState4 = 1
																			end

																			continue
																		end
																	end
																end

																loopEntryState4 = 1
																continue
															end

															break
														else
															n += 1

															if n <= 4 then
																if capturedCombatSettings.ka then
																	if capturedCombatLoopGenerations.ka ~= capturedKa2 then
																		loopEntryState4 = 1
																	elseif capturedHasLivingCharacter2(temporaryValue96) then
																		if not capturedHasSpawnProtection2(temporaryValue96) then
																			if capturedContainsNameIgnoreCase(capturedTargetNameLists.wl, temporaryValue96.Name) then
																				loopEntryState4 = 1
																			else
																				loopExitState20 = 1
																				break
																			end
																		else
																			loopEntryState4 = 1
																		end
																	else
																		loopEntryState4 = 1
																	end
																else
																	loopEntryState4 = 1
																end
															else
																loopEntryState4 = 1
															end
														end
													end

													if loopExitState20 == 1 then
														continue
													end
													break
												end
											end

											return flag
										end
									end
								end
							end
						else
							break
						end
					end

					return flag
				end
			end)(ka))
		end
	end

	-- [重建注释] 原有重力覆盖：启用时保存旧重力，停用时断开连接并恢复。
	local setGravityOverride
	do
		local capturedGetLivingLocalCharacter2, capturedGravityOverrideState, capturedWorkspace9, capturedRunService6 = getLivingLocalCharacter, gravityOverrideState, Workspace, runService
		setGravityOverride = function(enabled2)
			local temporaryValue102, temporaryValue103, temporaryValue104 = capturedGetLivingLocalCharacter2()

			if enabled2 then
				if not capturedGravityOverrideState.on then
					capturedGravityOverrideState.on = true
					capturedGravityOverrideState.orig = capturedWorkspace9.Gravity
					capturedWorkspace9.Gravity = 0

					capturedGravityOverrideState.conn = capturedRunService6.Heartbeat:Connect(function()
						capturedWorkspace9.Gravity = 0
						local temporaryValue105, temporaryValue106, temporaryValue107 = capturedGetLivingLocalCharacter2()

						if temporaryValue107 then
							local assemblyLinearVelocity = temporaryValue107.AssemblyLinearVelocity
							temporaryValue107.AssemblyLinearVelocity = Vector3.new(assemblyLinearVelocity.X, 0, assemblyLinearVelocity.Z)
						end
					end)
				end

				if temporaryValue104 then
					local assemblyLinearVelocity = temporaryValue104.AssemblyLinearVelocity
					temporaryValue104.AssemblyLinearVelocity = Vector3.new(assemblyLinearVelocity.X, 0, assemblyLinearVelocity.Z)
					temporaryValue104.AssemblyAngularVelocity = Vector3.zero
				end
			else
				if capturedGravityOverrideState.conn then
					capturedGravityOverrideState.conn:Disconnect()
					capturedGravityOverrideState.conn = nil
				end

				if capturedGravityOverrideState.on then
					capturedWorkspace9.Gravity = capturedGravityOverrideState.orig or 196.2
				end

				capturedGravityOverrideState.on = false
			end
		end
	end

	local startListedTargetsLoop
	do
		local capturedCombatLoopGenerations2, capturedSpawnConditionalLoop2, capturedCombatSettings2, capturedPlayersService2, capturedPlayerReference8, capturedContainsNameIgnoreCase2, capturedTargetNameLists2, capturedHasLivingCharacter3, capturedHasSpawnProtection3, capturedSetGravityOverride, capturedAttackSelectedPlayer2 = combatLoopGenerations, spawnConditionalLoop, combatSettings, playersService, playerReference, containsNameIgnoreCase, targetNameLists, hasLivingCharacter, hasSpawnProtection, setGravityOverride, attackSelectedPlayer
		startListedTargetsLoop = function()
			capturedCombatLoopGenerations2.kb = capturedCombatLoopGenerations2.kb + 1
			local kb = capturedCombatLoopGenerations2.kb

			capturedSpawnConditionalLoop2((function(capturedKb)
				return function()
					local kb2 = capturedCombatSettings2.kb

					if kb2 then
						kb2 = capturedCombatLoopGenerations2.kb == capturedKb
					end

					return kb2
				end
			end)(kb), (function(capturedKb2)
				return function()
					local dataTable14 = { [1] = {} }
					dataTable14[1][1] = nil
					local iterateArray11 = ipairs
					local playerList4 = capturedPlayersService2:GetPlayers()
					local iteratorNext27, iteratorState26, iteratorControl26 = iterateArray11(playerList4)
					local advanceIterator12 = makeResumableIterator(iteratorNext27, iteratorState26, iteratorControl26)
					local packedReturns8 = table.pack(advanceIterator12())

					if packedReturns8[1] then
						local loopExitState21 = nil
						local temporaryValue108

						while true do
							temporaryValue108 = packedReturns8[3]

							if temporaryValue108 ~= capturedPlayerReference8 then
								loopExitState21 = 1
							else
								packedReturns8 = table.pack(advanceIterator12())
								if packedReturns8[1] then
									continue
								end
							end

							break
						end

						if loopExitState21 == 1 then
							while true do
								local loopExitState22

								if capturedContainsNameIgnoreCase2(capturedTargetNameLists2.bl, temporaryValue108.Name) then
									if capturedHasLivingCharacter3(temporaryValue108) then
										if not capturedHasSpawnProtection3(temporaryValue108) then
											dataTable14[1][1] = temporaryValue108
											break
										else
											loopExitState22 = nil

											while true do
												packedReturns8 = table.pack(advanceIterator12())

												if packedReturns8[1] then
													temporaryValue108 = packedReturns8[3]
													if temporaryValue108 ~= capturedPlayerReference8 then
														loopExitState22 = 1
														break
													end
												else
													break
												end
											end

											if loopExitState22 == 1 then
												continue
											end
										end
									else
										loopExitState22 = nil

										while true do
											packedReturns8 = table.pack(advanceIterator12())

											if packedReturns8[1] then
												temporaryValue108 = packedReturns8[3]
												if temporaryValue108 ~= capturedPlayerReference8 then
													loopExitState22 = 1
													break
												end
											else
												break
											end
										end

										if loopExitState22 == 1 then
											continue
										end
									end

									break
								end

								loopExitState22 = nil

								while true do
									packedReturns8 = table.pack(advanceIterator12())

									if packedReturns8[1] then
										temporaryValue108 = packedReturns8[3]
										if temporaryValue108 ~= capturedPlayerReference8 then
											loopExitState22 = 1
											break
										end
									else
										break
									end
								end

								if loopExitState22 == 1 then
									continue
								end
								break
							end
						end
					end

					if not dataTable14[1][1] then
						capturedSetGravityOverride(false)
						return false
					end
					capturedSetGravityOverride(true)

					pcall((function(capturedValue45)
						return function()
							local temporaryValue109 = nil
							local temporaryValue110 = nil
							local temporaryValue111 = nil
							local temporaryValue112 = nil
							local temporaryValue113 = nil
							local temporaryValue114 = nil
							local temporaryValue115 = nil
							local temporaryValue116 = nil
							local temporaryValue117 = nil
							local temporaryValue118 = nil
							local temporaryValue119 = nil
							local temporaryValue120 = nil
							local temporaryValue121

							while true do
								if capturedCombatSettings2.kb then
									if capturedCombatLoopGenerations2.kb == capturedKb2 then
										if capturedValue45[1].Parent == capturedPlayersService2 then
											if capturedContainsNameIgnoreCase2(capturedTargetNameLists2.bl, capturedValue45[1].Name) then
												if capturedHasLivingCharacter3(capturedValue45[1]) then
													if not capturedHasSpawnProtection3(capturedValue45[1]) then
														local select2 = select
														local packedReturns9 = table.pack(capturedAttackSelectedPlayer2(capturedValue45[1], 10))
														temporaryValue109 = if packedReturns9.n >= 4 then packedReturns9[4] else temporaryValue109
														temporaryValue110 = if packedReturns9.n >= 5 then packedReturns9[5] else temporaryValue110
														temporaryValue111 = if packedReturns9.n >= 6 then packedReturns9[6] else temporaryValue111
														temporaryValue112 = if packedReturns9.n >= 7 then packedReturns9[7] else temporaryValue112
														temporaryValue113 = if packedReturns9.n >= 8 then packedReturns9[8] else temporaryValue113
														temporaryValue114 = if packedReturns9.n >= 10 then packedReturns9[10] else temporaryValue114
														temporaryValue115 = if packedReturns9.n >= 11 then packedReturns9[11] else temporaryValue115
														temporaryValue116 = if packedReturns9.n >= 12 then packedReturns9[12] else temporaryValue116
														temporaryValue117 = if packedReturns9.n >= 13 then packedReturns9[13] else temporaryValue117
														temporaryValue118 = if packedReturns9.n >= 14 then packedReturns9[14] else temporaryValue118
														temporaryValue119 = if packedReturns9.n >= 15 then packedReturns9[15] else temporaryValue119
														temporaryValue120 = if packedReturns9.n >= 16 then packedReturns9[16] else temporaryValue120
														temporaryValue121 = if packedReturns9.n >= 24 then packedReturns9[24] else temporaryValue121
														local returnValues14, returnCount14 = (function(...) return {...}, select("#", ...) end)(table.unpack(packedReturns9, 1, packedReturns9.n))

														if not select2(2, table.unpack(returnValues14, 1, returnCount14)) then
															task.wait(0.1)
														end

														continue
													end
												end
											end
										end
									end
								end

								break
							end
						end
					end)(dataTable14[1]))

					capturedSetGravityOverride(false)
					dataTable14[1] = { [1] = dataTable14[1][1] }
					return true
				end
			end)(kb))
		end
	end

	local setFriendsWhitelist
	do
		local capturedPlayerReference9, capturedContainsNameIgnoreCase3, capturedTargetNameLists3, capturedPlayersService3, capturedCombatSettings3 = playerReference, containsNameIgnoreCase, targetNameLists, playersService, combatSettings
		setFriendsWhitelist = function(callbackValue37)
			if callbackValue37 then
				local function addFriendToWhitelist(player5)
					if player5 ~= capturedPlayerReference9 then
						if player5:IsFriendsWith(capturedPlayerReference9.UserId) then
							if not capturedContainsNameIgnoreCase3(capturedTargetNameLists3.wl, player5.Name) then
								table.insert(capturedTargetNameLists3.wl, player5.Name)
							end
						end
					end
				end

				local iterateArray12 = ipairs
				local playerList5 = capturedPlayersService3:GetPlayers()
				local iteratorNext28, iteratorState27, iteratorControl27 = iterateArray12(playerList5)
				local advanceIterator13 = makeResumableIterator(iteratorNext28, iteratorState27, iteratorControl27)

				while true do
					local packedReturns10 = table.pack(advanceIterator13())
					local temporaryValue122 = packedReturns10[3]

					if packedReturns10[1] then
						addFriendToWhitelist(temporaryValue122)
					else
						break
					end
				end

				capturedPlayersService3.PlayerAdded:Connect((function(capturedAddFriendToWhitelist)
					return function(callbackValue38)
						if capturedCombatSettings3.wlF then
							capturedAddFriendToWhitelist(callbackValue38)
						end
					end
				end)(addFriendToWhitelist))

				task.spawn((function(capturedAddFriendToWhitelist2)
					return function()
						while capturedCombatSettings3.wlF do
							task.wait(3)
							local iterateArray13 = ipairs
							local playerList6 = capturedPlayersService3:GetPlayers()
							local iteratorNext29, iteratorState28, iteratorControl28 = iterateArray13(playerList6)
							local advanceIterator14 = makeResumableIterator(iteratorNext29, iteratorState28, iteratorControl28)

							while true do
								local packedReturns11 = table.pack(advanceIterator14())

								if packedReturns11[1] then
									capturedAddFriendToWhitelist2(packedReturns11[3])
								else
									break
								end
							end
						end
					end
				end)(addFriendToWhitelist))
			end
		end
	end

	local combatTab = mainWindow:Tab({ Title = "击杀", Icon = "sword" })

	local listCombatPlayerNames
	do
		local capturedPlayersService4, capturedPlayerReference10 = playersService, playerReference
		listCombatPlayerNames = function()
			local dataTable15 = {}
			local iterateArray14 = ipairs
			local playerList7 = capturedPlayersService4:GetPlayers()
			local iteratorNext30, iteratorState29, iteratorControl29 = iterateArray14(playerList7)

			for k, entryValue31 in iteratorNext30, iteratorState29, iteratorControl29 do
				local entryValue32 = entryValue31

				if entryValue32 ~= capturedPlayerReference10 then
					dataTable15[#dataTable15 + 1] = entryValue32.Name
				end
			end

			return dataTable15
		end
	end

	-- [重建注释] 从列表末尾开始按不区分大小写的名称移除匹配项。
	local function removeNameIgnoreCase(names2, nameToRemove)
		local n = #names2 - -1 + -1
		local temporaryValue123

		while n >= 1 do
			if names2[n]:lower() == nameToRemove:lower() then
				table.remove(names2, temporaryValue123)
			end

			n += -1
		end
	end

	combatTab:Section({ Title = "自动击杀" })

	combatTab:Toggle({
		Title = "击杀所有人",
		Callback = (function(capturedCombatSettings4, capturedStartAllTargetsLoop, capturedCombatLoopGenerations3)
			return function(ka)
				capturedCombatSettings4.ka = ka

				if ka then
					capturedStartAllTargetsLoop()
				else
					capturedCombatLoopGenerations3.ka = capturedCombatLoopGenerations3.ka + 1
				end
			end
		end)(combatSettings, startAllTargetsLoop, combatLoopGenerations),
	})

	combatTab:Toggle({
		Title = "好友自动白名单",
		Callback = (function(capturedCombatSettings5, capturedSetFriendsWhitelist)
			return function(wlF)
				capturedCombatSettings5.wlF = wlF
				capturedSetFriendsWhitelist(wlF)
			end
		end)(combatSettings, setFriendsWhitelist),
	})

	combatTab:Toggle({
		Title = "击杀列表目标",
		Callback = (function(capturedCombatSettings6, capturedStartListedTargetsLoop, capturedCombatLoopGenerations4, capturedSetGravityOverride2)
			return function(kb)
				capturedCombatSettings6.kb = kb

				if kb then
					capturedStartListedTargetsLoop()
				else
					capturedCombatLoopGenerations4.kb = capturedCombatLoopGenerations4.kb + 1
					capturedSetGravityOverride2(false)
				end
			end
		end)(combatSettings, startListedTargetsLoop, combatLoopGenerations, setGravityOverride),
	})

	combatTab:Section({ Title = "白名单" })

	local whitelistAddDropdown = combatTab:Dropdown({
		Title = "添加",
		Values = listCombatPlayerNames(),
		Callback = (function(capturedContainsNameIgnoreCase4, capturedTargetNameLists4)
			return function(callbackValue39)
				if callbackValue39 then
					if not capturedContainsNameIgnoreCase4(capturedTargetNameLists4.wl, callbackValue39) then
						table.insert(capturedTargetNameLists4.wl, callbackValue39)
					end
				end
			end
		end)(containsNameIgnoreCase, targetNameLists),
	})

	local whitelistRemoveDropdown = combatTab:Dropdown({
		Title = "移除",
		Values = {},
		Callback = (function(capturedRemoveNameIgnoreCase, capturedTargetNameLists5)
			return function(callbackValue40)
				capturedRemoveNameIgnoreCase(capturedTargetNameLists5.wl, callbackValue40)
			end
		end)(removeNameIgnoreCase, targetNameLists),
	})

	local whitelistParagraph = combatTab:Paragraph({ Title = "白名单", Desc = "无" })

	combatTab:Button({
		Title = "清空",
		Callback = (function(capturedTargetNameLists6)
			return function()
				capturedTargetNameLists6.wl = {}
			end
		end)(targetNameLists),
	})

	combatTab:Section({ Title = "击杀列表" })

	local targetListAddDropdown = combatTab:Dropdown({
		Title = "添加",
		Values = listCombatPlayerNames(),
		Callback = (function(capturedContainsNameIgnoreCase5, capturedTargetNameLists7)
			return function(callbackValue41)
				if callbackValue41 then
					if not capturedContainsNameIgnoreCase5(capturedTargetNameLists7.bl, callbackValue41) then
						table.insert(capturedTargetNameLists7.bl, callbackValue41)
					end
				end
			end
		end)(containsNameIgnoreCase, targetNameLists),
	})

	local targetListRemoveDropdown = combatTab:Dropdown({
		Title = "移除",
		Values = {},
		Callback = (function(capturedRemoveNameIgnoreCase2, capturedTargetNameLists8)
			return function(callbackValue42)
				capturedRemoveNameIgnoreCase2(capturedTargetNameLists8.bl, callbackValue42)
			end
		end)(removeNameIgnoreCase, targetNameLists),
	})

	local targetListParagraph = combatTab:Paragraph({ Title = "击杀列表", Desc = "无" })

	combatTab:Button({
		Title = "清空",
		Callback = (function(capturedTargetNameLists9)
			return function()
				capturedTargetNameLists9.bl = {}
			end
		end)(targetNameLists),
	})

	playersService.PlayerAdded:Connect((function(capturedListCombatPlayerNames, capturedWhitelistAddDropdown, capturedTargetListAddDropdown)
		return function()
			task.wait(1)
			local temporaryValue124 = capturedListCombatPlayerNames()
			capturedWhitelistAddDropdown:Refresh(temporaryValue124)
			capturedTargetListAddDropdown:Refresh(temporaryValue124)
		end
	end)(listCombatPlayerNames, whitelistAddDropdown, targetListAddDropdown))

	playersService.PlayerRemoving:Connect((function(capturedListCombatPlayerNames2, capturedWhitelistAddDropdown2, capturedTargetListAddDropdown2)
		return function()
			task.wait(0.5)
			local temporaryValue125 = capturedListCombatPlayerNames2()
			capturedWhitelistAddDropdown2:Refresh(temporaryValue125)
			capturedTargetListAddDropdown2:Refresh(temporaryValue125)
		end
	end)(listCombatPlayerNames, whitelistAddDropdown, targetListAddDropdown))

	task.spawn((function(capturedWhitelistParagraph, capturedTargetNameLists10, capturedTargetListParagraph, capturedWhitelistRemoveDropdown, capturedTargetListRemoveDropdown)
		return function()
			while true do
				task.wait(0.5)

				pcall(function()
					local capturedWhitelistParagraph2 = capturedWhitelistParagraph
					local setDesc = capturedWhitelistParagraph.SetDesc
					local str

					if #capturedTargetNameLists10.wl == 0 then
						str = "无"
					else
						str = table.concat(capturedTargetNameLists10.wl, ", ")
					end

					setDesc(capturedWhitelistParagraph2, str)
					local capturedTargetListParagraph2 = capturedTargetListParagraph
					local setDesc2 = capturedTargetListParagraph.SetDesc
					local flag = #capturedTargetNameLists10.bl == 0

					if flag then
						flag = "无"
					end

					setDesc2(capturedTargetListParagraph2, flag or table.concat(capturedTargetNameLists10.bl, ", "))
					capturedWhitelistRemoveDropdown:Refresh(capturedTargetNameLists10.wl)
					capturedTargetListRemoveDropdown:Refresh(capturedTargetNameLists10.bl)
				end)
			end
		end
	end)(whitelistParagraph, targetNameLists, targetListParagraph, whitelistRemoveDropdown, targetListRemoveDropdown))
end

do
	-- [重建注释] 从输入文本提取最多三个数字，组成 Vector3；不足三个时返回 nil。保留多返回值辅助逻辑。
	local function parsePositionText(positionText)
		local coordinateValues = {}
		local iteratorNext31, iteratorState30, iteratorControl30 = string.gmatch(positionText or "", "%-?%d+%.?%d*")
		local advanceIterator15 = makeResumableIterator(iteratorNext31, iteratorState30, iteratorControl30)
		local temporaryValue126 = nil
		local temporaryValue127 = nil
		local temporaryValue128 = nil
		local temporaryValue129 = nil
		local temporaryValue130 = nil
		local temporaryValue131 = nil
		local temporaryValue132 = nil
		local temporaryValue133 = nil
		local packedReturns12 = table.pack(advanceIterator15())
		local vector

		if packedReturns12[1] then
			local temporaryValue134

			while true do
				local insert = table.insert
				packedReturns12 = table.pack(tonumber(packedReturns12[2]))
				temporaryValue126 = if packedReturns12.n >= 3 then packedReturns12[3] else temporaryValue126
				temporaryValue127 = if packedReturns12.n >= 4 then packedReturns12[4] else temporaryValue127
				temporaryValue128 = if packedReturns12.n >= 5 then packedReturns12[5] else temporaryValue128
				temporaryValue129 = if packedReturns12.n >= 6 then packedReturns12[6] else temporaryValue129
				temporaryValue130 = if packedReturns12.n >= 7 then packedReturns12[7] else temporaryValue130
				temporaryValue131 = if packedReturns12.n >= 9 then packedReturns12[9] else temporaryValue131
				temporaryValue132 = if packedReturns12.n >= 10 then packedReturns12[10] else temporaryValue132
				temporaryValue133 = if packedReturns12.n >= 11 then packedReturns12[11] else temporaryValue133
				temporaryValue134 = if packedReturns12.n >= 24 then packedReturns12[24] else temporaryValue134
				local returnValues15, returnCount15 = (function(...) return {...}, select("#", ...) end)(table.unpack(packedReturns12, 1, packedReturns12.n))
				insert(coordinateValues, table.unpack(returnValues15, 1, returnCount15))

				if #coordinateValues ~= 3 then
					packedReturns12 = table.pack(advanceIterator15())
					if packedReturns12[1] then
						continue
					end
				end

				break
			end

			if #coordinateValues == 3 then
				vector = Vector3.new(coordinateValues[1], coordinateValues[2], coordinateValues[3]) or nil
			else
				vector = nil
			end
		else
			vector = #coordinateValues == 3

			if vector then
				vector = Vector3.new(coordinateValues[1], coordinateValues[2], coordinateValues[3])
			end

			vector = vector or nil
		end

		return vector
	end

	local teleportTab = mainWindow:Tab({ Title = "传送", Icon = "map-pin" })
	sharedCells[239][1] = "0, 0, 0"
	teleportTab:Section({ Title = "坐标传送" })

	teleportTab:Input({
		Title = "位置 (X, Y, Z)",
		Value = "0, 0, 0",
		Placeholder = "例如: 1, 44, -1251",
		Callback = (function(capturedPositionTextCell)
			return function(callbackValue43)
				capturedPositionTextCell[1] = callbackValue43
			end
		end)(sharedCells[239]),
	})

	teleportTab:Button({
		Title = "传送",
		Callback = (function(capturedParsePositionText, capturedPositionTextCell2, capturedTeleportToCFrame7)
			return function()
				local temporaryValue135 = capturedParsePositionText(capturedPositionTextCell2[1])

				if temporaryValue135 then
					local capturedTeleportToCFrame8 = capturedTeleportToCFrame7
					local returnValues16, returnCount16 = (function(...) return {...}, select("#", ...) end)(CFrame.new(temporaryValue135))
					capturedTeleportToCFrame8(table.unpack(returnValues16, 1, returnCount16))
				end
			end
		end)(parsePositionText, sharedCells[239], teleportToCFrame),
	})

	teleportTab:Button({
		Title = "复制当前位置到剪切板",
		Callback = (function(capturedGetRootPart10, capturedPositionTextCell3)
			return function()
				local temporaryValue136 = capturedGetRootPart10()

				if temporaryValue136 then
					local position = temporaryValue136.Position
					local str = string.format("%.0f, %.0f, %.0f", position.X, position.Y, position.Z)

					pcall((function(capturedStr)
						return function()
							setclipboard(capturedStr)
						end
					end)(str))

					capturedPositionTextCell3[1] = str
				end
			end
		end)(getRootPart, sharedCells[239]),
	})

	-- [重建注释] 固定传送预设及坐标，按原脚本的顺序创建按钮。
	local teleportPresets = table.create(15)
	local entries98 = table.create(1)
	local returnValues17, returnCount17 = (function(...) return {...}, select("#", ...) end)(CFrame.new(2, 88, 243))

	do
		local values = table.pack("大厅", table.unpack(returnValues17, 1, returnCount17))
		table.move(values, 1, values.n, 1, entries98)
	end

	local entries99 = table.create(1)
	local returnValues18, returnCount18 = (function(...) return {...}, select("#", ...) end)(CFrame.new(-38, 7, 1894))

	do
		local values = table.pack("小岛", table.unpack(returnValues18, 1, returnCount18))
		table.move(values, 1, values.n, 1, entries99)
	end

	local entries100 = table.create(1)
	local returnValues19, returnCount19 = (function(...) return {...}, select("#", ...) end)(CFrame.new(-2623, 7, -409))

	do
		local values = table.pack("冰霜健身房", table.unpack(returnValues19, 1, returnCount19))
		table.move(values, 1, values.n, 1, entries100)
	end

	local entries101 = table.create(1)
	local returnValues20, returnCount20 = (function(...) return {...}, select("#", ...) end)(CFrame.new(2250, 7, 1073))

	do
		local values = table.pack("神话健身房", table.unpack(returnValues20, 1, returnCount20))
		table.move(values, 1, values.n, 1, entries101)
	end

	local entries102 = table.create(1)
	local returnValues21, returnCount21 = (function(...) return {...}, select("#", ...) end)(CFrame.new(-6758, 7, -1284))

	do
		local values = table.pack("永恒健身房", table.unpack(returnValues21, 1, returnCount21))
		table.move(values, 1, values.n, 1, entries102)
	end

	local entries103 = table.create(1)
	local returnValues22, returnCount22 = (function(...) return {...}, select("#", ...) end)(CFrame.new(4603, 991, -3897))

	do
		local values = table.pack("传奇健身房", table.unpack(returnValues22, 1, returnCount22))
		table.move(values, 1, values.n, 1, entries103)
	end

	local entries104 = table.create(1)
	local returnValues23, returnCount23 = (function(...) return {...}, select("#", ...) end)(CFrame.new(-8625, 17, -5730))

	do
		local values = table.pack("肌肉之王", table.unpack(returnValues23, 1, returnCount23))
		table.move(values, 1, values.n, 1, entries104)
	end

	local entries105 = table.create(1)
	local returnValues24, returnCount24 = (function(...) return {...}, select("#", ...) end)(CFrame.new(-8685, 6, 2392))

	do
		local values = table.pack("丛林健身房", table.unpack(returnValues24, 1, returnCount24))
		table.move(values, 1, values.n, 1, entries105)
	end

	local entries106 = table.create(1)
	local returnValues25, returnCount25 = (function(...) return {...}, select("#", ...) end)(CFrame.new(-5563, 60, 4942))

	do
		local values = table.pack("工业丛林", table.unpack(returnValues25, 1, returnCount25))
		table.move(values, 1, values.n, 1, entries106)
	end

	local entries107 = table.create(1)
	local returnValues26, returnCount26 = (function(...) return {...}, select("#", ...) end)(CFrame.new(-32, 49, -1216))

	do
		local values = table.pack("BOSS祭坛", table.unpack(returnValues26, 1, returnCount26))
		table.move(values, 1, values.n, 1, entries107)
	end

	local entries108 = table.create(1)
	local returnValues27, returnCount27 = (function(...) return {...}, select("#", ...) end)(CFrame.new(69, 22, 416))

	do
		local values = table.pack("附魔台", table.unpack(returnValues27, 1, returnCount27))
		table.move(values, 1, values.n, 1, entries108)
	end

	local entries109 = table.create(1)
	local returnValues28, returnCount28 = (function(...) return {...}, select("#", ...) end)(CFrame.new(1952, 1, 6180))

	do
		local values = table.pack("无转盘岛", table.unpack(returnValues28, 1, returnCount28))
		table.move(values, 1, values.n, 1, entries109)
	end

	local entries110 = table.create(1)
	local returnValues29, returnCount29 = (function(...) return {...}, select("#", ...) end)(CFrame.new(4472, 119, -8849))

	do
		local values = table.pack("熔岩争斗", table.unpack(returnValues29, 1, returnCount29))
		table.move(values, 1, values.n, 1, entries110)
	end

	local entries111 = table.create(1)
	local returnValues30, returnCount30 = (function(...) return {...}, select("#", ...) end)(CFrame.new(987, 17, -7440))

	do
		local values = table.pack("沙漠争斗", table.unpack(returnValues30, 1, returnCount30))
		table.move(values, 1, values.n, 1, entries111)
	end

	local entries112 = table.create(1)
	local returnValues31, returnCount31 = (function(...) return {...}, select("#", ...) end)(CFrame.new(-1863, 17, -6292))

	do
		local values = table.pack("海滩争斗", table.unpack(returnValues31, 1, returnCount31))
		table.move(values, 1, values.n, 1, entries112)
	end

	teleportPresets[1] = entries98
	teleportPresets[2] = entries99
	teleportPresets[3] = entries100
	teleportPresets[4] = entries101
	teleportPresets[5] = entries102
	teleportPresets[6] = entries103
	teleportPresets[7] = entries104
	teleportPresets[8] = entries105
	teleportPresets[9] = entries106
	teleportPresets[10] = entries107
	teleportPresets[11] = entries108
	teleportPresets[12] = entries109
	teleportPresets[13] = entries110
	teleportPresets[14] = entries111
	teleportPresets[15] = entries112
	teleportTab:Section({ Title = "地点" })
	local iteratorNext32, iteratorState31, iteratorControl31 = ipairs(teleportPresets)

	for k, entryValue33 in iteratorNext32, iteratorState31, iteratorControl31 do
		local entryValue34 = entryValue33

		teleportTab:Button({
			Title = entryValue34[1],
			Callback = (function(capturedTeleportToCFrame9, capturedEntryValue2)
				return function()
					capturedTeleportToCFrame9(capturedEntryValue2[2])
				end
			end)(teleportToCFrame, entryValue34),
		})
	end
end

-- [重建注释] 重建辅助：重新绑定外层共享单元；已经创建的闭包继续持有各自捕获的旧单元。
sharedCells[47] = { [1] = sharedCells[47][1] }
sharedCells[48] = { [1] = sharedCells[48][1] }
sharedCells[73] = { [1] = sharedCells[73][1] }
sharedCells[76] = { [1] = sharedCells[76][1] }
sharedCells[77] = { [1] = sharedCells[77][1] }
sharedCells[78] = { [1] = sharedCells[78][1] }
sharedCells[85] = { [1] = sharedCells[85][1] }
sharedCells[92] = { [1] = sharedCells[92][1] }
sharedCells[93] = { [1] = sharedCells[93][1] }
sharedCells[113] = { [1] = sharedCells[113][1] }
sharedCells[120] = { [1] = sharedCells[120][1] }
sharedCells[137] = { [1] = sharedCells[137][1] }
sharedCells[138] = { [1] = sharedCells[138][1] }
sharedCells[139] = { [1] = sharedCells[139][1] }
sharedCells[145] = { [1] = sharedCells[145][1] }
sharedCells[146] = { [1] = sharedCells[146][1] }
sharedCells[147] = { [1] = sharedCells[147][1] }
sharedCells[150] = { [1] = sharedCells[150][1] }
sharedCells[151] = { [1] = sharedCells[151][1] }
sharedCells[158] = { [1] = sharedCells[158][1] }
sharedCells[159] = { [1] = sharedCells[159][1] }
sharedCells[187] = { [1] = sharedCells[187][1] }
sharedCells[188] = { [1] = sharedCells[188][1] }
sharedCells[189] = { [1] = sharedCells[189][1] }
sharedCells[190] = { [1] = sharedCells[190][1] }
sharedCells[239] = { [1] = sharedCells[239][1] }