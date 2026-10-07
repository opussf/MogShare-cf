MS_SLUG, MS = ...

StaticPopupDialogs["MS_EDIT_NAME"] = {
	text = MS.L["Name this set:"],
	button1 = SAVE,
	button2 = CANCEL,
	hasEditBox = true,
	maxLetters = 60,
	OnShow = function(self, data)
		self.EditBox:SetText(MS_Data[data.link].name or "")
		self.EditBox:HighlightText()
	end,
	OnAccept = function(self, data)
		local text = self.EditBox:GetText()
		MS_Data[data.link].name = (text ~= "") and text or nil
		MS.UIUpdate()
	end,
	EditBoxOnEnterPressed = function(self)
		local b1 = _G[self:GetParent():GetName().."Button1"]
		b1:Click()
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

function MS.UI_ContextMenuCallBack( owner, root )
	-- root:CreateTitle("Hi Frank")
	root:CreateButton(MS_Data[owner.link].name and MS.L["Edit Name"] or MS.L["Add Name"],
			function()
				StaticPopup_Show("MS_EDIT_NAME", nil, nil, {link=owner.link})
			end)
	root:CreateDivider()
	root:CreateButton(MS.L["Reset Rank"],
			function()
				MS_Data[owner.link].eloData = {
					rating      = 1500,
					comparisons = 0,
					wins        = 0,
					losses      = 0,
					lastShown   = 0,
				}
			end)
end

-- mixin
MS.Set_mixin = {}

function MS.Set_mixin:OnRowClick(button)
	if button == "RightButton" then
		MenuUtil.CreateContextMenu(self, MS.UI_ContextMenuCallBack)

		return
	end
	if self.link then
		if IsModifiedClick("CHATLINK") then
			-- shift-click: insert the link into the open chat edit box
			HandleModifiedItemClick(self.link)
		else
			-- plainclick
			local linkType, linkData = self.link:match("|H(%a+):(.-)|h")
			local actor = DressUpFrame.ModelScene:GetPlayerActor()
			if actor then
				actor:Undress()
			end
			SetItemRef(linkType..":"..linkData, self.link, button)
		end
	end
	MS.SelectRow(self)
	-- print("Row clicked:", self.Text:GetText())
	-- self is the row button itself, so self.Text / self.ActionButton work here too
end
function MS.Set_mixin:OnActionButtonClick(button)
	if MS.gameOn then
		MS.UpdateElo(
				(self.link == MS.gameItems[1] and MS.gameItems[1] or MS.gameItems[2]),   -- winner
				(self.link == MS.gameItems[2] and MS.gameItems[1] or MS.gameItems[2])    -- loser
		)
		MS.gameItems = nil
	else
		print("Archiving: "..self.link)
		MS_Archive[self.link] = MS_Data[self.link]
		MS_Archive[self.link].archived = time()

		MS_Data[self.link] = nil
	end
	MS.provisionalThreshold = MS.GetELOProvisionalThreshold()
	MS.UI_ShowList()
end
function MS.Set_mixin:OnEnter()
	if self.link then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:ClearLines()

		GameTooltip:AddLine(
				MS_Data[self.link].name or string.format("%s: %s", MS.L["Last Scan"], date("%X %x", MS_Data[self.link].lastScan)),
				1, 1, 1)
		GameTooltip:AddLine(" ")

		GameTooltip:AddLine(
				string.format(MS.L["%d (%dW - %dL - %dC)%s"],
					MS_Data[self.link].eloData.rating, MS_Data[self.link].eloData.wins,
					MS_Data[self.link].eloData.losses, MS_Data[self.link].eloData.comparisons, ""),
				0.6, 0.6, 0.6)
		if MS_Data[self.link].classList or MS_Data[self.link].playerList then
			GameTooltip:AddLine(" ")
		end
		if MS_Data[self.link].classList and MS_Data[self.link].classList[1] then
			GameTooltip:AddLine(
					string.format("%s: %s", MS.L["Class"],
					MS_Data[self.link].classList[1]))
		end
		if MS_Data[self.link].playerList then
			local players = {}
			for pName, ts in pairs( MS_Data[self.link].playerList ) do
				table.insert( players, {ts=ts, pName=pName} )
			end
			table.sort( players, function(a, b) return a.ts > b.ts end )
			for i, player in ipairs( players ) do
				if i > 20 then break end
				local name, realm = player.pName:match("^(.-)-(.-)-")
				if name and realm then
					GameTooltip:AddDoubleLine(
							name.."-"..realm, date("%x", player.ts))
				end
			end
		end

		GameTooltip:Show()
	end
end
function MS.Set_mixin:OnLeave()
	GameTooltip:Hide()
end
---------
function MS.SelectRow(row)
	MS.selectedLink = row.link
	MS.UI_ShowList()  -- force update
end
function MS.GameButtonOnClick()
	MS.gameOn = not MS.gameOn
	if MS.gameOn then
		MogShareDisplayFrame_MogListVSlider:SetValue(0)  -- short list (make sure scroll is at the top)
		MogShareDisplayFrame_SearchBox:Disable()
		MogShareDisplayFrame_SearchBox:ClearFocus()
		MogShareDisplayFrame_SearchBox:SetTextColor(0.5, 0.5, 0.5)
	else
		MS.gameItems = nil  -- clear the gameItems when the game ends
		MogShareDisplayFrame_SearchBox:Enable()
		MogShareDisplayFrame_SearchBox:SetTextColor(1, 1, 1)
	end
	MS.UI_ShowList()
end
function MS.CheckButton_OnShow( self, option, text )
	getglobal(self:GetName().."Text"):SetText(text);
	self:SetChecked(MS_Options[option]);
end
function MS.CheckButton_OnClick( self, option )
	MS_Options[option] = self:GetChecked()
end
--------

function MS.UIOnLoad( mogframe )
	DressUpFrame:HookScript("OnShow", function(self)
		-- print("Dressing room opened")
		MS.UIOpenFrame( mogframe )
	end)
	DressUpFrame:HookScript("OnHide", function(self)
		-- print("Dressing room closed")
		mogframe:Hide()
	end)
	DressUpFrame.CustomSetDetailsPanel:HookScript("OnShow", function(self)
		-- print("CustomSetDetailsPanel opened.")
		MS.UIMoveFrame( mogframe )
	end)
	DressUpFrame.CustomSetDetailsPanel:HookScript("OnHide", function(self)
		-- print("CustomSetDetailsPanel closed.")
		MS.UIMoveFrame( mogframe )
	end)

	mogframe:Hide()
end
function MS.UIOpenFrame( mogframe )
	-- print("MS.UIOpenFrame")
	mogframe:Show()
	MogShareDisplayFrame_SearchBox:Enable()
	MogShareDisplayFrame_SearchBox:SetTextColor(1, 1, 1)
end
function MS.UIMoveFrame( mogframe )
	mogframe:ClearAllPoints()

	if DressUpFrame.CustomSetDetailsPanel:IsShown() then
		mogframe:SetPoint("LEFT", DressUpFrame.CustomSetDetailsPanel, "RIGHT")
	else
		mogframe:SetPoint("LEFT", DressUpFrame, "RIGHT")
	end
end
function MS.UIMouseWheel( delta )
	-- print("MS.UIMouseWheel( "..delta.." )")
	MogShareDisplayFrame_MogListVSlider:SetValue(
		MogShareDisplayFrame_MogListVSlider:GetValue() - delta
	)
end

function MS.UIUpdate()
	MS.UI_ShowList()
end
function MS.UIOnShow()
	MS.UI_BuildDropDowns()
	MS.UI_BuildItemDisplay()
	MS.UI_ShowList()
end
function MS.UIOnHide()
	MS.gameOn = nil
	MS.gameItems = nil
end

----
function MS.UI_BuildDropDowns()
	MS.SortDropDownBuild( MogShareDisplayFrame_SortDropDownMenu )
end
function MS.SortDropDownBuild( self )
	UIDropDownMenu_Initialize( self, MS.SortDropDownPopulate )
	UIDropDownMenu_JustifyText( self, "LEFT" )
end
function MS.SortDropDownPopulate( self, level, menuList )
	local sortList = {}
	for sf in pairs( MS.sortFunctions ) do
		table.insert( sortList, sf )
	end
	table.sort( sortList )
	for _, sf in ipairs( sortList ) do
		info = UIDropDownMenu_CreateInfo()
		info.text = MS.sortFunctions[sf].text
		info.value = sf
		info.notCheckable = true
		info.func = MS.SetSortFunction
		UIDropDownMenu_AddButton( info, level )
	end
	UIDropDownMenu_SetText( self, MS.sortFunctions[MS_Options.sortBy].text )
end
function MS.SetSortFunction( info )
	-- takes the info table
	MS_Options.sortBy = info.value
	UIDropDownMenu_SetText( MogShareDisplayFrame_SortDropDownMenu, MS.sortFunctions[info.value].text )
	MS.UI_ShowList()
end

----------
function MS.UI_BuildItemDisplay()
	if not MS.UISet_Buttons then
		local _, height = MogShareDisplayFrame_MogList:GetSize()
		local rowCount = math.floor( height / 20 )

		MS.UISet_Buttons = {}
		for rowNum = 1, rowCount do
			local buttonFrame = CreateFrame("Button", "MS_MogList_Button"..rowNum, MogShareDisplayFrame_MogList, "MSSet_template")
			buttonFrame.Text:SetText("This is row #:"..rowNum)
			buttonFrame.Text:Show()
			if rowNum == 1 then
				buttonFrame:SetPoint( "TOP", MogShareDisplayFrame_MogList, "TOP" )
			else
				buttonFrame:SetPoint( "TOP", "MS_MogList_Button"..rowNum-1, "BOTTOM" )
			end
			buttonFrame:Show()
			MS.UISet_Buttons[rowNum] = buttonFrame
		end
	end
end
MS.numericFields = {
	["wins"]   = function(ms) return ms.eloData.wins end,
	["w"]      = function(ms) return ms.eloData.wins end,
	["losses"] = function(ms) return ms.eloData.losses end,
	["l"]      = function(ms) return ms.eloData.losses end,
	["rating"] = function(ms) return ms.eloData.rating end,
	["rank"]   = function(ms) return ms.eloData.rating end,
	["r"]      = function(ms) return ms.eloData.rating end,
}
MS.localizedFields = {
	[MS.L["wins"]]   = "wins",
	[MS.L["w"]]      = "w",
	[MS.L["losses"]] = "losses",
	[MS.L["l"]]      = "l",
	[MS.L["rating"]] = "rating",
	[MS.L["rank"]]   = "rank",
	[MS.L["r"]]      = "r",
}

function MS.ParseNumericFilter(textIn)
	local field, op, num = textIn:match("^(.+)%s*([<>=]+)%s*(%-?%d+)$")

	local localField = field and MS.localizedFields[field]

	if localField and MS.numericFields[localField] then
		return MS.numericFields[localField], op, tonumber(num)
	end
end
function MS.MatchesNumbericFilter(mogStruct, dataFun, op, num)
	local value = dataFun(mogStruct)
	if value then
		if     op == ">"  then return value >  num
		elseif op == "<"  then return value <  num
		elseif op == ">=" then return value >= num
		elseif op == "<=" then return value <= num
		elseif op == "="  then return value == num
		end
	end
end
function MS.MogMatched( mogStruct )
	if MS.searchFilter and MS.searchFilter ~= "" then

		local dataFun, op, num = MS.ParseNumericFilter(MS.searchFilter)
		if dataFun then
			return MS.MatchesNumbericFilter(mogStruct, dataFun, op, num)
		end
		if mogStruct.name and string.find( mogStruct.name:lower(), MS.searchFilter ) then
			return true
		end
		if mogStruct.classList and string.find( mogStruct.classList[1]:lower(), MS.searchFilter ) then
			return true
		end
		if string.find( date("%B%Y", mogStruct.lastScan):lower(), MS.searchFilter ) then
			return true
		end
		for k in pairs( mogStruct.playerList or {} ) do
			if string.find( k:lower(), MS.searchFilter ) then
				return true
			end
		end
		for i in pairs( mogStruct.itemNames or {} ) do
			if string.find( i:lower(), MS.searchFilter ) then
				return true
			end
		end
	else
		return true  -- match if searchFiler is nil (no search)
	end
end

function MS.UI_ShowList()
	MS.UI_BuildItemDisplay()
	local count = 1
	local sortedItems = {}
	if MS.gameOn then
		MS.gameItems = MS.gameItems or MS.PickNextPair()
		sortedItems = MS.gameItems
	else
		for k in pairs( MS_Data ) do
			if MS.MogMatched( MS_Data[k] ) then
				table.insert(sortedItems, k)
			end
		end
		table.sort( sortedItems, MS.sortFunctions[MS_Options.sortBy].sortFun)
	end
	local offset = floor(MogShareDisplayFrame_MogListVSlider:GetValue())
	MogShareDisplayFrame_MogListVSlider:SetMinMaxValues(0, max(0, #sortedItems - #MS.UISet_Buttons))

	while count <= #MS.UISet_Buttons do
		local buttonFrame = MS.UISet_Buttons[count]

		if count + offset <= #sortedItems then
			local link = sortedItems[count+offset]
			local lastScan = MS_Data[link].lastScan

			buttonFrame.link = link
			buttonFrame.Text:SetText(count+offset..". "..link.." "..MS.sortFunctions[MS_Options.sortBy].display(link))
			buttonFrame.Text:Show()

			if MS.gameOn then
				buttonFrame.ActionButton:SetText(MS.L["Winner"])
			else
				buttonFrame.ActionButton:SetText(MS.L["Archive"])
			end

			if link == MS.selectedLink then
				buttonFrame.SelectedTexture:Show()
			else
				buttonFrame.SelectedTexture:Hide()
			end
			buttonFrame:Show()
		else
			buttonFrame.Text:SetText("")
			buttonFrame:Hide()
		end
		count = count + 1
	end
end
function MS.UISearchTextChanged(self, userInput)
	-- userInput is boolean, if the user set the input.
	if self:GetText() == "" then
		self.Instructions:Show()
		MS.searchFilter = nil
	else
		self.Instructions:Hide()
	end

	MS.searchFilter = self:GetText():lower()
	MS.UIUpdate()  -- reuse your existing refresh, just have it check MS.searchFilter now
end

------
-- elo functions
------
function MS.PickNextPair()
	local items = {}
	for item in pairs(MS_Data) do table.insert(items, item) end

	-- bias toward under-compared items
	table.sort(items, function(a, b)
		return MS_Data[a].eloData.comparisons < MS_Data[b].eloData.comparisons
	end)

	local poolSize = math.min(10, #items)  -- take the 10 least-compared as the pool
	local first = items[math.random(poolSize)]

	-- from the rest, pick whichever is closest in rating to `first`
	local bestMatch, bestDiff = nil, math.huge
	for _, item in ipairs(items) do
		if item ~= first then
			local diff = math.abs(MS_Data[item].eloData.rating - MS_Data[first].eloData.rating)
			if diff < bestDiff then
				bestMatch, bestDiff = item, diff
			end
		end
	end

	return {first, bestMatch}
end

function MS.UpdateElo(winnerItem, loserItem)
	local K = 32
	local winner = MS_Data[winnerItem]
	local loser  = MS_Data[loserItem]

	-- expected score: probability winner "should" have won, based on current ratings
	local expectedWinner = 1 / (1 + 10 ^ ((loser.eloData.rating - winner.eloData.rating) / 400))
	local expectedLoser  = 1 - expectedWinner

	winner.eloData.rating = winner.eloData.rating + K * (1 - expectedWinner)
	loser.eloData.rating  = loser.eloData.rating  + K * (0 - expectedLoser)

	winner.eloData.comparisons = winner.eloData.comparisons + 1
	loser.eloData.comparisons  = loser.eloData.comparisons + 1
	winner.eloData.wins   = winner.eloData.wins + 1
	loser.eloData.losses  = loser.eloData.losses + 1
	winner.eloData.lastShown = time()
	loser.eloData.lastShown  = time()
end
function MS.GetELOProvisionalThreshold()
	local count = 0
	for _ in pairs(MS_Data) do count = count + 1 end
	if count <= 1 then return 1 end

	local threshold = math.ceil(2 * math.log(count, 2))

	return math.max(3, math.min(threshold, 15))  -- between 3, and 15
end
------

MS.sortFunctions = {
	lastScan = {
		sortFun = function( a, b ) -- a and b are links
			return MS_Data[a].lastScan > MS_Data[b].lastScan
		end,
		display = function( l ) -- l is the link
			-- since there is no OnUpdate, showing SecondsToTime does not make sense.
			local now = date("*t")
			local mogTime = date("*t", MS_Data[l].lastScan)
			local diff = time() - MS_Data[l].lastScan

			if now.year == mogTime.year
					and now.month == mogTime.month
					and now.day == mogTime.day then
				return date("%X", MS_Data[l].lastScan)
			elseif diff < 604800 then
				return date("%a, %X", MS_Data[l].lastScan)
			else
				return date("%x %X", MS_Data[l].lastScan)
			end
		end,
		text = MS.L["Last Scan"],
	},
	rank = {
		sortFun = function( a, b )
			if MS_Data[a].eloData.rating ~= MS_Data[b].eloData.rating then
				return MS_Data[a].eloData.rating > MS_Data[b].eloData.rating
			end
			return MS_Data[a].lastScan > MS_Data[b].lastScan
		end,
		display = function( l )
			return string.format(MS.L["%d (%dW - %dL - %dC)%s"],
					MS_Data[l].eloData.rating, MS_Data[l].eloData.wins,
					MS_Data[l].eloData.losses, MS_Data[l].eloData.comparisons,
					(MS_Data[l].eloData.comparisons < MS.provisionalThreshold and " |cffff8080†|r" or "")
			)
		end,
		text = MS.L["Rank"],
	},
	class = {
		sortFun = function( a, b )
			if not MS_Data[a].classList then return false end
			if not MS_Data[b].classList then return true end
			return MS_Data[a].classList[1] < MS_Data[b].classList[1]
		end,
		display = function( l )
			return string.format( "%s", table.concat( MS_Data[l].classList and MS_Data[l].classList or {}, ", " ) )
		end,
		text = MS.L["Class"],
	},
	name = {
		sortFun = function( a, b )
			if not MS_Data[a].name then return false end
			if not MS_Data[b].name then return true end
			return MS_Data[a].name < MS_Data[b].name
		end,
		display = function( l )
			return string.format( "%s", MS_Data[l].name or "" )
		end,
		text = MS.L["Name"],
	},
}
