MS_SLUG, MS = ...
MS.MSG_ADDONNAME = C_AddOns.GetAddOnMetadata( MS_SLUG, "Title" )
MS.MSG_VERSION   = C_AddOns.GetAddOnMetadata( MS_SLUG, "Version" )
MS.MSG_AUTHOR    = C_AddOns.GetAddOnMetadata( MS_SLUG, "Author" )

MS_Data = {}
MS_Options = { sortBy = "lastScan" }

MS.linkPattern = "(|c.-|Hcustomset:.-|r)"
MS.slotTokens = {
	"HeadSlot", "ShoulderSlot", "ShirtSlot", "ChestSlot", "WaistSlot", "LegsSlot",
	"FeetSlot", "WristSlot", "HandsSlot", "BackSlot", "MainHandSlot",
	"SecondaryHandSlot", "TabardSlot"
}
MS.slotNames = { }

function MS.OnLoad()
	SLASH_MS1 = "/MS"
	SlashCmdList["MS"] = function(msg) MS.Command(msg); end
	MogShareFrame:RegisterEvent( "PLAYER_ENTERING_WORLD" )
	MogShareFrame:RegisterEvent( "PLAYER_TARGET_CHANGED" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_BN_WHISPER" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_CHANNEL" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_GUILD" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_INSTANCE_CHAT" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_INSTANCE_CHAT_LEADER" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_OFFICER" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_PARTY" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_PARTY_LEADER" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_RAID" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_RAID_LEADER" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_SAY" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_WHISPER" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_YELL" )
	MogShareFrame:RegisterUnitEvent( "UNIT_MODEL_CHANGED", "target" )
end
function MS.PLAYER_ENTERING_WORLD()
	MS.Prune()
	MS.MakeMissingItemLists()
	MS.provisionalThreshold = MS.GetELOProvisionalThreshold()
end
function MS.PLAYER_TARGET_CHANGED()
	-- I still prefer positive checks
	if UnitExists("target") and UnitIsPlayer("target") then
		if CanInspect("target") and CheckInteractDistance("target",1) then
			NotifyInspect("target")
			MogShareFrame:RegisterEvent("INSPECT_READY")
			MS.pendingGUID = UnitGUID("target")
		end
	end
end
function MS.INSPECT_READY(guid)
	if guid == MS.pendingGUID then
		local targetMogList = C_TransmogCollection.GetInspectItemTransmogInfoList()
		local mogLink = C_TransmogCollection.GetCustomSetHyperlinkFromItemTransmogInfoList(targetMogList)

		MS.SaveLink( mogLink )

		local name, realm = UnitName("target")
		realm = realm or GetRealmName()
		local faction = UnitFactionGroup("target")
		local guildName = GetGuildInfo("target") or ""
		if name and realm and faction then
			MS_Data[mogLink].playerList = MS_Data[mogLink].playerList or {}
			local nameKey = name.."-"..realm.."-"..faction.."-"..guildName
			if not issecretvalue(nameKey) then
				MS_Data[mogLink].playerList[nameKey] = time()
			end
		end

		local className, classFile, classID = UnitClass("target")
		if className and not issecretvalue(className) then
			MS_Data[mogLink].classList = MS_Data[mogLink].classList or {}
			MS_Data[mogLink].classList[className] = time()
			MS_Data[mogLink].classList[1] = nil
			local sortedClasses = {}
			for c in pairs(MS_Data[mogLink].classList) do
				table.insert( sortedClasses, c )
			end
			table.sort(sortedClasses)
			MS_Data[mogLink].classList[1] = table.concat( sortedClasses, ", " )
		end

		if MS_Options.showScans then
			MS.Print(string.format(MS.L["Scanned %s-%s: %s"], name, realm, mogLink))
		end
		-- MS.ScanItems()

		MogShareFrame:UnregisterEvent("INSPECT_READY")
	end
end
function MS.CHAT_MSG_( msg, sender )
	if not issecretvalue(msg) then
		for mogLink in msg:gmatch(MS.linkPattern) do
			MS.SaveLink( mogLink )

			MS_Data[mogLink].sharedBy = MS_Data[mogLink].sharedBy or {}
			MS_Data[mogLink].sharedBy[sender] = time()

			if MS_Options.showScans then
				MS.Print(string.format(MS.L["Shared by %s: %s"], sender, mogLink))
			end
		end
	else
		-- print("chat messages are secret right now.")
		-- can I save in a queue to scan later?
	end
end
MS.CHAT_MSG_BN_WHISPER   = MS.CHAT_MSG_
MS.CHAT_MSG_CHANNEL      = MS.CHAT_MSG_
MS.CHAT_MSG_INSTANCE_CHAT= MS.CHAT_MSG_
MS.CHAT_MSG_INSTANCE_CHAT_LEADER= MS.CHAT_MSG_
MS.CHAT_MSG_OFFICER      = MS.CHAT_MSG_
MS.CHAT_MSG_GUILD        = MS.CHAT_MSG_
MS.CHAT_MSG_PARTY        = MS.CHAT_MSG_
MS.CHAT_MSG_PARTY_LEADER = MS.CHAT_MSG_
MS.CHAT_MSG_RAID         = MS.CHAT_MSG_
MS.CHAT_MSG_RAID_LEADER  = MS.CHAT_MSG_
MS.CHAT_MSG_SAY          = MS.CHAT_MSG_
MS.CHAT_MSG_WHISPER      = MS.CHAT_MSG_
MS.CHAT_MSG_YELL         = MS.CHAT_MSG_
MS.UNIT_MODEL_CHANGED    = MS.PLAYER_TARGET_CHANGED

function MS.Print( msg, showName )
	-- print to the chat frame
	-- set showName to false to suppress the addon name printing
	if (showName == nil) or (showName) then
		msg = "|cffcfb52b"..MS.MSG_ADDONNAME.."> ".."|r"..msg
	end
	DEFAULT_CHAT_FRAME:AddMessage( msg )
end
function MS.SaveLink( mogLink )
	if mogLink then
		local mogData = MS_Data[mogLink] or {}
		mogData.archived = nil
		local ts = time()

		mogData.lastScan = ts

		mogData.eloData = mogData.eloData or {
			rating      = 1500,
			comparisons = 0,
			wins        = 0,
			losses      = 0,
			lastShown   = 0,
		}

		MS_Data[mogLink] = mogData
		if not MS_Data[mogLink].itemList then
			MS.ScanItems(mogLink)
		end
	end
	MS.provisionalThreshold = MS.GetELOProvisionalThreshold()
end
function MS.Prune()
	local ts = time()
	local prune_age = 30 * 86400

	for mogLink, data in pairs( MS_Archive or {} ) do
		if not MS_Data[mogLink] then
			MS_Data[mogLink] = MS_Archive[mogLink]
		end
		MS_Archive[mogLink] = nil
	end
	for mogLink, data in pairs( MS_Data ) do
		if data.archived and ( data.archived + prune_age < ts ) then
			MS_Data[mogLink] = nil
		end
	end
end
function MS.ScanItems( mogLink )
	local list = C_TransmogCollection.GetItemTransmogInfoListFromCustomSetHyperlink( mogLink )
	if list then
		MS_Data[mogLink].itemNames = {}
		for slot, itemInfo in pairs( list ) do
			local sourceInfo = C_TransmogCollection.GetAppearanceSourceInfo( itemInfo.appearanceID )
			if sourceInfo and sourceInfo.itemLink then
				local itemName = GetItemInfo(sourceInfo.itemLink)
				if itemName then
					MS_Data[mogLink].itemNames[itemName] = true
				else
					local item = Item:CreateFromItemLink( sourceInfo.itemLink )
					item:ContinueOnItemLoad(function()
						local itemName = GetItemInfo(sourceInfo.itemLink)
						MS_Data[mogLink].itemNames[itemName] = true
					end)
				end
			end
		end
	end
end
function MS.MakeMissingStep()
	if MS.scanCO then
		local ok, err = coroutine.resume(MS.scanCO)
		if ok then
			if coroutine.status(MS.scanCO) == "dead" then
				local elapsed = time() - MS.scanStart
				MS.Print(string.format(MS.L["Item scan is complete after %s."], SecondsToTime(elapsed)))
				MS.scanStart = nil
				MS.scanCO = nil
				return
			else
				C_Timer.After(0.5, MS.MakeMissingStep)  -- schedule next step
			end
		else
			MS.Print(string.format(MS.L["There was an error (%s)"], err))
			MS.scanCO = nil
		end
	end
end
function MS.MakeMissingItemLists()
	if MS.scanCO and coroutine.status(MS.scanCO) ~= "dead" then
		return  -- already running
	end

	MS.Print(MS.L["Starting Item scan."])
	MS.scanStart = time()

	MS.scanCO = coroutine.create(function()
		for mogLink, data in pairs(MS_Data) do
			if not data.itemNames then
				MS.ScanItems( mogLink )
				coroutine.yield()
			end
		end
	end)

	MS.MakeMissingStep()
end
function MS.Command(msg)
	MogShareDisplayFrame:Show()
end
