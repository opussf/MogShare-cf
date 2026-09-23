MS_SLUG, MS = ...
MS.MSG_ADDONNAME = C_AddOns.GetAddOnMetadata( MS_SLUG, "Title" )
MS.MSG_VERSION   = C_AddOns.GetAddOnMetadata( MS_SLUG, "Version" )
MS.MSG_AUTHOR    = C_AddOns.GetAddOnMetadata( MS_SLUG, "Author" )

MS_Data = {}
MS_Archive = {}
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
	MogShareFrame:RegisterEvent( "CHAT_MSG_GUILD" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_PARTY" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_PARTY_LEADER" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_RAID" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_RAID_LEADER" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_SAY" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_WHISPER" )
	MogShareFrame:RegisterEvent( "CHAT_MSG_YELL" )
end
function MS.PLAYER_ENTERING_WORLD()
	MS.Prune()
end
function MS.PLAYER_TARGET_CHANGED()
	-- I still prefer positive checks
	if UnitExists("target") and UnitIsPlayer("target") then
		if CanInspect("target") and CheckInteractDistance("target",1) then
			-- print("New target:", UnitName("target"))
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
		print("Scanned "..name.."-"..realm..": "..mogLink)

		-- MS.ScanItems()

		MogShareFrame:UnregisterEvent("INSPECT_READY")
	end
end
function MS.CHAT_MSG_( msg, sender )
	if not issecretvalue(msg) then
		for mogLink in msg:gmatch(MS.linkPattern) do
			MS.SaveLink( mogLink )
			print("Sent by "..sender..": "..mogLink)
		end
	else
		-- print("chat messages are secret right now.")
		-- can I save in a queue to scan later?
	end
end
MS.CHAT_MSG_GUILD        = MS.CHAT_MSG_
MS.CHAT_MSG_PARTY        = MS.CHAT_MSG_
MS.CHAT_MSG_PARTY_LEADER = MS.CHAT_MSG_
MS.CHAT_MSG_RAID         = MS.CHAT_MSG_
MS.CHAT_MSG_RAID_LEADER  = MS.CHAT_MSG_
MS.CHAT_MSG_SAY          = MS.CHAT_MSG_
MS.CHAT_MSG_WHISPER      = MS.CHAT_MSG_
MS.CHAT_MSG_YELL         = MS.CHAT_MSG_

function MS.SaveLink( mogLink )
	if mogLink then
		local mogData = MS_Data[mogLink] or (MS_Archive[mogLink] or {})
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
		MS_Archive[mogLink] = nil
	end
end

function MS.Prune()
	local ts = time()
	local prune_age = 30 * 86400
	for mogLink, data in pairs( MS_Archive ) do
		if not data.archived or (data.archived + prune_age < ts) then
			MS_Archive[mogLink] = nil
		end
	end
end

function MS.ScanItems()
	for _, token in ipairs(MS.slotTokens) do
			local slotID = GetInventorySlotInfo(token)

			local slotAppearanceID = targetMogList[slotID].appearanceID
			local slotIllusionID = targetMogList[slotID].illusionID

			MS_Data[guid][MS.slotNames[slotID].."_appearanceID"] = slotAppearanceID
			MS_Data[guid][MS.slotNames[slotID].."_illusionID"] = slotIllusionID

			local sourceItemInfo = C_TransmogCollection.GetSourceInfo(slotAppearanceID)
			if sourceItemInfo then
				local sourceItemID = sourceItemInfo.itemID
				MS_Data[guid][MS.slotNames[slotID].."_sourceItemID"] = sourceItemID

				local item = Item:CreateFromItemID(sourceItemID)
				item:ContinueOnItemLoad(function()
					local itemName, itemLink = C_Item.GetItemInfo( sourceItemID )
					MS_Data[guid][MS.slotNames[slotID].."_sourceItemName"] = itemName
					-- print(token, slotID or "nil", MS.slotNames[slotID], itemLink)
				end)
			end
		end
end
function MS.Command(msg)
	MogShareDisplayFrame:Show()
end
