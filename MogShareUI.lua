MS_SLUG, MS = ...

-- mixin
MS.Set_mixin = {}

function MS.Set_mixin:OnRowClick(button)
	if button == "RightButton" then
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
function MS.SelectRow(row)
	MS.selectedLink = row.link
	MS.UI_ShowList()  -- force update
end
function MS.GameButtonOnClick()
	MS.gameOn = not MS.gameOn
	if MS.gameOn then
		MogShareDisplayFrame_MogListVSlider:SetValue(0)  -- short list (make sure scroll is at the top)
	else
		MS.gameItems = nil  -- clear the gameItems when the game ends
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

function MS.UI_ShowList()
	MS.UI_BuildItemDisplay()
	local count = 1
	local sortedItems = {}
	if MS.gameOn then
		MS.gameItems = MS.gameItems or MS.PickNextPair()
		sortedItems = MS.gameItems
	else
		for k in pairs( MS_Data ) do table.insert(sortedItems, k) end
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
			buttonFrame.Text:SetText(link.." "..MS.sortFunctions[MS_Options.sortBy].display(link))
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
			return date("%c", MS_Data[l].lastScan)
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
}
