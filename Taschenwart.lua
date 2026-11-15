-- Taschenwart 0.1.3
-- Greift NUR ein, wenn die Taschen voll sind und Loot nicht mehr hineinpasst.
-- Schlaegt dann das Item mit dem geringsten Wert zum Wegwerfen vor und fragt IMMER nach.
-- Weggeworfen wird ausschliesslich nach einem Klick des Spielers (Blizzard-Vorgabe).

local ADDON = ...
local PREFIX = "|cff33ff99Taschenwart|r: "

---------------------------------------------------------------------------
-- Einstellungen
---------------------------------------------------------------------------
local defaults = {
    enabled = true,
    protectAllTradeGoods = true, -- false = nur Materialien der eigenen Berufe schuetzen
    protectConsumables = true,
    protectReagents = true,      -- alle Zauber-Reagenzien behalten; false = nur die der gewaehlten Klassen
    protectNoValue = true,       -- Items ohne Haendlerwert nie vorschlagen
    questAlways = true,          -- fuer Questgegenstaende immer Platz anbieten
    useAuctionator = true,
    maxQuality = 1,              -- 0 = grau, 1 = weiss, 2 = gruen, 3 = blau
}
local charDefaults = { professions = {}, classes = {}, ignore = {} }

local DB, CharDB

local PROFESSIONS = {
    { key = "alchemy",        name = "Alchemie" },
    { key = "blacksmithing",  name = "Schmiedekunst" },
    { key = "enchanting",     name = "Verzauberkunst" },
    { key = "engineering",    name = "Ingenieurskunst" },
    { key = "leatherworking", name = "Lederverarbeitung" },
    { key = "tailoring",      name = "Schneiderei" },
    { key = "jewelcrafting",  name = "Juwelenschleifen" },
    { key = "inscription",    name = "Inschriftenkunde" },
    { key = "herbalism",      name = "Kräuterkunde" },
    { key = "mining",         name = "Bergbau" },
    { key = "skinning",       name = "Kürschnerei" },
    { key = "cooking",        name = "Kochkunst" },
    { key = "firstaid",       name = "Erste Hilfe" },
    { key = "fishing",        name = "Angeln" },
}

local CLASSES = {
    { key = "druid",   name = "Druide" },
    { key = "warlock", name = "Hexenmeister" },
    { key = "mage",    name = "Magier" },
    { key = "paladin", name = "Paladin" },
    { key = "priest",  name = "Priester" },
    { key = "shaman",  name = "Schamane" },
    { key = "rogue",   name = "Schurke" },
}

-- Zauber-Reagenzien -> Klassen (Item-IDs aus Classic).
local REAGENT_CLASS = {
    [17030] = { "shaman" },                      -- Ankh
    [17057] = { "shaman" }, [17058] = { "shaman" }, -- Fischoel, Glaenzende Fischschuppen
    [17020] = { "mage" },                        -- Arkanes Pulver
    [17031] = { "mage" }, [17032] = { "mage" },  -- Rune der Teleportation / der Portale
    [17056] = { "mage", "priest" },              -- Leichte Feder
    [17028] = { "priest" }, [17029] = { "priest" }, -- Heilige / Hochheilige Kerze
    [17033] = { "paladin" }, [21177] = { "paladin" }, -- Symbol der Offenbarung / der Koenige
    [17034] = { "druid" }, [17035] = { "druid" }, [17036] = { "druid" }, [17037] = { "druid" },
    [17038] = { "druid" },                       -- Samenkoerner (Wiedergeburt)
    [17021] = { "druid" }, [17026] = { "druid" }, -- Wilde Beeren, Wilder Dornwurz
    [6265]  = { "warlock" }, [5565] = { "warlock" }, [16583] = { "warlock" }, -- Seelensplitter, Hoellenstein, Daemonenstatuette
    [5140]  = { "rogue" }, [5530] = { "rogue" }, [5060] = { "rogue" }, -- Blitzstrahlpulver, Blendpulver, Diebeswerkzeug
    [2928]  = { "rogue" }, [2930] = { "rogue" }, [5173] = { "rogue" }, [8923] = { "rogue" },
    [8924]  = { "rogue" }, [3777] = { "rogue" }, [2931] = { "rogue" }, -- Giftzutaten
}

-- Unterkategorien der Item-Klasse "Handwerkswaren" (classID 7) -> Berufe.
-- Alles, was hier nicht steht (Elementar, Sonstiges ...), gilt als nuetzlich
-- fuer jeden Beruf und bleibt geschuetzt, sobald irgendein Beruf gewaehlt ist.
local SUBCLASS_PROF = {
    [1]  = { "engineering" },                                         -- Teile
    [2]  = { "engineering" },                                         -- Sprengstoff
    [3]  = { "engineering" },                                         -- Geraete
    [4]  = { "jewelcrafting" },                                       -- Juwelen
    [5]  = { "tailoring", "firstaid" },                               -- Stoff
    [6]  = { "leatherworking", "skinning" },                          -- Leder
    [7]  = { "blacksmithing", "engineering", "mining", "jewelcrafting" }, -- Metall & Stein
    [8]  = { "cooking", "fishing" },                                  -- Fleisch / Kochen
    [9]  = { "alchemy", "herbalism", "inscription" },                 -- Kraeuter
    [12] = { "enchanting" },                                          -- Verzauberkunst
    [16] = { "inscription" },                                         -- Inschriftenkunde
}

local CLASS_CONSUMABLE, CLASS_TRADEGOODS, CLASS_QUEST, CLASS_KEY = 0, 7, 12, 13
local HEARTHSTONE = 6948
local QUALITY_MAX_SELECTABLE = 3

-- Berufswerkzeuge: werden nie vorgeschlagen (zaehlen im Spiel als Waffe/Sonstiges,
-- nicht als Handwerksware).
local CLASS_WEAPON, SUBCLASS_FISHING_POLE = 2, 20
local CLASS_REAGENT, CLASS_MISC, SUBCLASS_MISC_REAGENT = 5, 15, 1
local PROFESSION_TOOLS = {
    [7005] = true,  -- Kuerschnermesser
    [2901] = true,  -- Spitzhacke
    [5956] = true,  -- Schmiedehammer
    [6219] = true,  -- Bogenlichtschraubenschluessel
    [10498] = true, -- Gyromatischer Mikroregler
    [6218] = true, [6339] = true, [11130] = true, [11145] = true, [16207] = true, -- Runenverzierte Ruten
    [9149] = true,  -- Stein der Weisen
    [4471] = true,  -- Feuerstein und Zunder
    [15846] = true, -- Salzstreuer
    [6256] = true, [6365] = true, [6366] = true, [6367] = true, [12225] = true, [19022] = true, [19970] = true, -- Angelruten
    [20815] = true, [20824] = true, -- Juwelierswerkzeug
    [39505] = true, -- Tintenset
}

---------------------------------------------------------------------------
-- API-Kompatibilitaet
---------------------------------------------------------------------------
local GetItemInfoFn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemInfoInstantFn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local CC = C_Container
local LOOT_TYPE_ITEM = (Enum and Enum.LootSlotType and Enum.LootSlotType.Item) or 1
local LAST_BAG = NUM_BAG_SLOTS or 4

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

local function Money(copper)
    copper = math.floor((copper or 0) + 0.5)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local k = copper % 100
    local out = {}
    if g > 0 then out[#out + 1] = g .. "|cffffd700g|r" end
    if s > 0 then out[#out + 1] = s .. "|cffc7c7cfs|r" end
    if k > 0 or #out == 0 then out[#out + 1] = k .. "|cffeda55fk|r" end
    return table.concat(out, " ")
end

local function QualityName(q)
    local name = _G["ITEM_QUALITY" .. q .. "_DESC"] or tostring(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c and c.hex then return c.hex .. name .. "|r" end
    return name
end

---------------------------------------------------------------------------
-- Bewertung
---------------------------------------------------------------------------
local function UnitValue(link, sellPrice)
    local v = sellPrice or 0
    if DB.useAuctionator and link and Auctionator and Auctionator.API and Auctionator.API.v1
        and Auctionator.API.v1.GetAuctionPriceByItemLink then
        local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemLink, ADDON, link)
        if ok and type(price) == "number" and price > v then v = price end
    end
    return v
end

local function AnyProfessionSelected()
    for _, on in pairs(CharDB.professions) do
        if on then return true end
    end
    return false
end

-- true = Handwerksware, die behalten werden soll
local function IsProtectedTradeGood(classID, subclassID, isReagent)
    if classID ~= CLASS_TRADEGOODS and not isReagent then return false end
    if DB.protectAllTradeGoods then return true end
    if not AnyProfessionSelected() then return true end -- nichts eingestellt: lieber alles behalten
    local profs = (classID == CLASS_TRADEGOODS) and SUBCLASS_PROF[subclassID] or nil
    if not profs then return true end -- allgemeines Material: fuer jeden Beruf nuetzlich
    for _, key in ipairs(profs) do
        if CharDB.professions[key] then return true end
    end
    return false
end

local function AnyClassSelected()
    for _, on in pairs(CharDB.classes) do
        if on then return true end
    end
    return false
end

-- true = Zauber-Reagenz, das behalten werden soll
local function IsProtectedReagent(itemID, classID, subclassID)
    local owners = REAGENT_CLASS[itemID]
    local isReagent = owners or classID == CLASS_REAGENT
        or (classID == CLASS_MISC and subclassID == SUBCLASS_MISC_REAGENT)
    if not isReagent then return false end
    if DB.protectReagents then return true end
    if not owners or not AnyClassSelected() then return true end -- unbekannt / nichts gewaehlt: behalten
    for _, key in ipairs(owners) do
        if CharDB.classes[key] then return true end
    end
    return false
end

local function FreeSlots()
    local free = 0
    for bag = 0, LAST_BAG do
        local n, family = CC.GetContainerNumFreeSlots(bag)
        if n and (not family or family == 0) then free = free + n end
    end
    return free
end

-- Passt der Loot noch auf vorhandene, nicht volle Stapel?
local function FitsInStacks(itemID, qty, maxStack)
    if not itemID or not maxStack or maxStack <= 1 then return false end
    local room = 0
    for bag = 0, LAST_BAG do
        for slot = 1, CC.GetContainerNumSlots(bag) or 0 do
            local info = CC.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID then
                room = room + (maxStack - (info.stackCount or 1))
                if room >= qty then return true end
            end
        end
    end
    return false
end

-- Sucht das Item (ganzer Stapel) mit dem geringsten Gesamtwert, das weggeworfen werden darf.
local function FindCheapest()
    local best
    for bag = 0, LAST_BAG do
        for slot = 1, CC.GetContainerNumSlots(bag) or 0 do
            local info = CC.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not info.isLocked
                and info.itemID ~= HEARTHSTONE and not CharDB.ignore[info.itemID] then
                local link = info.hyperlink
                local name, _, quality, _, _, _, _, _, _, icon, sell, classID, subclassID, bindType, _, _, isReagent =
                    GetItemInfoFn(link or info.itemID)
                if name then -- nicht geladene Items werden sicherheitshalber uebersprungen
                    quality = info.quality or quality or 99
                    sell = sell or 0
                    local ok = quality <= DB.maxQuality
                        and classID ~= CLASS_QUEST and classID ~= CLASS_KEY and bindType ~= 4
                        and not PROFESSION_TOOLS[info.itemID]
                        and not (classID == CLASS_WEAPON and subclassID == SUBCLASS_FISHING_POLE)
                        and not (DB.protectNoValue and (sell <= 0 or info.hasNoValue))
                        and not (DB.protectConsumables and classID == CLASS_CONSUMABLE)
                        and not IsProtectedReagent(info.itemID, classID, subclassID)
                        and not IsProtectedTradeGood(classID, subclassID, isReagent)
                    if ok then
                        local count = info.stackCount or 1
                        local value = UnitValue(link, sell) * count
                        if not best or value < best.value
                            or (value == best.value and quality < best.quality) then
                            best = {
                                bag = bag, slot = slot, itemID = info.itemID, link = link or name,
                                count = count, value = value, quality = quality,
                                icon = info.iconFileID or icon,
                            }
                        end
                    end
                end
            end
        end
    end
    return best
end

---------------------------------------------------------------------------
-- Wegwerfen (nur aus einem Klick heraus aufrufen!)
---------------------------------------------------------------------------
local function DeleteBagItem(c)
    ClearCursor()
    local info = CC.GetContainerItemInfo(c.bag, c.slot)
    if not info or info.itemID ~= c.itemID or info.isLocked or (info.stackCount or 1) ~= c.count then
        return false, "Das Item liegt nicht mehr an derselben Stelle."
    end
    CC.PickupContainerItem(c.bag, c.slot)
    local ctype, cid = GetCursorInfo()
    if ctype ~= "item" or cid ~= c.itemID then
        ClearCursor()
        return false, "Das Item konnte nicht aufgenommen werden."
    end
    if DeleteCursorItem then
        DeleteCursorItem()
    end
    if CursorHasItem and CursorHasItem() then
        ClearCursor() -- legt das Item zurueck
        return false, "Das Spiel hat das Wegwerfen blockiert."
    end
    return true
end

---------------------------------------------------------------------------
-- Fenster-Helfer
---------------------------------------------------------------------------
local function MakeWindow(name, w, h, title)
    local f = CreateFrame("Frame", name, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(w, h)
    f:SetPoint("CENTER", 0, 120)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOP", 0, -18)
    t:SetText(title)
    f.title = t
    f:Hide()
    return f
end

local function MakeButton(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 110, 24)
    b:SetText(text)
    return b
end

---------------------------------------------------------------------------
-- Rueckfrage-Fenster
---------------------------------------------------------------------------
local prompt, current
local lootOpen = false
local declined = {}   -- in diesem Beutefenster abgelehnte Drops
local awaitingLoot    -- Link, der nach dem Wegwerfen automatisch gelootet werden soll
local Schedule        -- forward

local function HidePrompt()
    current = nil
    if prompt then prompt:Hide() end
end

local function BuildPrompt()
    prompt = MakeWindow("TaschenwartPrompt", 400, 200, "Taschen voll!")

    prompt.lootText = prompt:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    prompt.lootText:SetPoint("TOPLEFT", 24, -52)
    prompt.lootText:SetWidth(352)
    prompt.lootText:SetJustifyH("LEFT")

    prompt.dropText = prompt:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    prompt.dropText:SetPoint("TOPLEFT", prompt.lootText, "BOTTOMLEFT", 0, -12)
    prompt.dropText:SetWidth(352)
    prompt.dropText:SetJustifyH("LEFT")

    local yes = MakeButton(prompt, "Wegwerfen", 110)
    yes:SetPoint("BOTTOMLEFT", 22, 20)
    yes:SetScript("OnClick", function()
        local c = current
        if not c then return end
        local ok, err = DeleteBagItem(c.cand)
        if ok then
            Print("Weggeworfen: " .. c.cand.link .. " x" .. c.cand.count)
            awaitingLoot = c.lootLink
        else
            Print(err or "Wegwerfen fehlgeschlagen.")
        end
        HidePrompt()
        Schedule(0.6)
    end)

    local no = MakeButton(prompt, "Behalten", 110)
    no:SetPoint("BOTTOM", 0, 20)
    no:SetScript("OnClick", function()
        if current then declined[current.lootLink] = true end
        HidePrompt()
        Schedule(0.1)
    end)

    local never = MakeButton(prompt, "Nie wegwerfen", 120)
    never:SetPoint("BOTTOMRIGHT", -22, 20)
    never:SetScript("OnClick", function()
        if current then
            CharDB.ignore[current.cand.itemID] = true
            Print(current.cand.link .. " wird nicht mehr vorgeschlagen.")
        end
        HidePrompt()
        Schedule(0.1)
    end)
end

local function ShowPrompt(lootLink, lootQty, lootValue, isQuest, cand)
    if not prompt then BuildPrompt() end
    current = { lootLink = lootLink, cand = cand }
    local valueText = isQuest and "Questgegenstand" or Money(lootValue)
    prompt.lootText:SetText("Neuer Loot:\n" .. lootLink .. " x" .. lootQty .. "  (" .. valueText .. ")")
    prompt.dropText:SetText("Dafür wegwerfen?\n" .. cand.link .. " x" .. cand.count
        .. "  (" .. Money(cand.value) .. ")")
    prompt:Show()
end

---------------------------------------------------------------------------
-- Kernlogik
---------------------------------------------------------------------------
local function Evaluate()
    if not DB or not DB.enabled or not lootOpen then return end
    if current then return end           -- es laeuft schon eine Rueckfrage
    if FreeSlots() > 0 then return end   -- nur bei vollen Taschen eingreifen

    local cand, candSearched
    for i = 1, GetNumLootItems() do
        if GetLootSlotType(i) == LOOT_TYPE_ITEM then
            local link = GetLootSlotLink(i)
            if link and not declined[link] then
                local _, _, qty, _, _, locked, isQuestItem = GetLootSlotInfo(i)
                qty = (qty and qty > 0) and qty or 1
                local itemID = GetItemInfoInstantFn(link)
                local name, _, _, _, _, _, _, maxStack, _, _, sell, classID = GetItemInfoFn(link)
                if not name then
                    Schedule(0.5) -- Itemdaten noch nicht geladen, gleich nochmal
                elseif not locked and not FitsInStacks(itemID, qty, maxStack) then
                    local isQuest = (isQuestItem or classID == CLASS_QUEST) and true or false
                    local lootValue = UnitValue(link, sell) * qty
                    if not candSearched then
                        cand, candSearched = FindCheapest(), true
                    end
                    if not cand then return end
                    if (isQuest and DB.questAlways) or lootValue > cand.value then
                        ShowPrompt(link, qty, lootValue, isQuest, cand)
                        return
                    end
                end
            end
        end
    end
end

local scheduled = false
Schedule = function(delay)
    if scheduled then return end
    scheduled = true
    C_Timer.After(delay or 0.3, function()
        scheduled = false
        Evaluate()
    end)
end

local function LootAwaited()
    if not awaitingLoot or not lootOpen then
        awaitingLoot = nil
        return
    end
    local link = awaitingLoot
    awaitingLoot = nil
    if FreeSlots() <= 0 then return end
    for i = 1, GetNumLootItems() do
        if GetLootSlotLink(i) == link then
            LootSlot(i)
            return
        end
    end
end

---------------------------------------------------------------------------
-- Optionen
---------------------------------------------------------------------------
local options

local function MakeCheck(parent, label, x, y, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetText(label)
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    cb.Refresh = function() cb:SetChecked(get() and true or false) end
    parent.checks[#parent.checks + 1] = cb
    return cb
end

local function IgnoreCount()
    local n = 0
    for _ in pairs(CharDB.ignore) do n = n + 1 end
    return n
end

local function BuildOptions()
    options = MakeWindow("TaschenwartOptions", 440, 690, "Taschenwart")
    options.checks = {}
    if UISpecialFrames then tinsert(UISpecialFrames, "TaschenwartOptions") end

    local close = CreateFrame("Button", nil, options, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    local y = -46
    local function Opt(label, key)
        MakeCheck(options, label, 22, y, function() return DB[key] end, function(v) DB[key] = v end)
        y = y - 26
    end
    Opt("Addon aktiv (greift nur bei vollen Taschen ein)", "enabled")
    Opt("Alle Handwerkswaren behalten (aus = nur die meiner Berufe)", "protectAllTradeGoods")
    Opt("Verbrauchsgüter (Essen, Tränke ...) behalten", "protectConsumables")
    Opt("Alle Reagenzien behalten (aus = nur die meiner Klassen)", "protectReagents")
    Opt("Items ohne Händlerwert behalten", "protectNoValue")
    Opt("Für Questgegenstände immer Platz anbieten", "questAlways")
    Opt("Auktionshauspreise nutzen (benötigt Auctionator)", "useAuctionator")

    local qLabel = options:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    qLabel:SetPoint("TOPLEFT", 26, y - 8)
    qLabel:SetText("Wegwerfen höchstens bis Qualität:")
    local qBtn = MakeButton(options, "", 130)
    qBtn:SetPoint("LEFT", qLabel, "RIGHT", 8, 0)
    qBtn:SetScript("OnClick", function()
        DB.maxQuality = (DB.maxQuality + 1) % (QUALITY_MAX_SELECTABLE + 1)
        options.Refresh()
    end)
    y = y - 40

    local pHead = options:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pHead:SetPoint("TOPLEFT", 24, y)
    pHead:SetText("Meine Berufe (dieser Charakter)")
    y = y - 20

    local rows = math.ceil(#PROFESSIONS / 2)
    for i, p in ipairs(PROFESSIONS) do
        local col = (i > rows) and 1 or 0
        local row = (i - 1) % rows
        MakeCheck(options, p.name, 22 + col * 200, y - row * 24,
            function() return CharDB.professions[p.key] end,
            function(v) CharDB.professions[p.key] = v or nil end)
    end
    y = y - rows * 24 - 12

    local cHead = options:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cHead:SetPoint("TOPLEFT", 24, y)
    cHead:SetText("Reagenzien behalten für Klasse (dieser Charakter)")
    y = y - 20
    local cRows = math.ceil(#CLASSES / 2)
    for i, c in ipairs(CLASSES) do
        local col = (i > cRows) and 1 or 0
        local row = (i - 1) % cRows
        MakeCheck(options, c.name, 22 + col * 200, y - row * 24,
            function() return CharDB.classes[c.key] end,
            function(v) CharDB.classes[c.key] = v or nil end)
    end
    y = y - cRows * 24 - 12

    local iBtn = MakeButton(options, "", 300)
    iBtn:SetPoint("TOPLEFT", 24, y)
    iBtn:SetScript("OnClick", function()
        wipe(CharDB.ignore)
        options.Refresh()
    end)

    local hint = options:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 24, 20)
    hint:SetText("/taschenwart test  zeigt, was aktuell vorgeschlagen würde.")

    options.Refresh = function()
        for _, cb in ipairs(options.checks) do cb.Refresh() end
        qBtn:SetText(QualityName(DB.maxQuality))
        iBtn:SetText("\"Nie wegwerfen\"-Liste leeren (" .. IgnoreCount() .. ")")
    end
    options:SetScript("OnShow", options.Refresh)
end

local function ToggleOptions()
    if not options then BuildOptions() end
    if options:IsShown() then options:Hide() else options:Show() end
end

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------
local function ApplyDefaults(target, src)
    for k, v in pairs(src) do
        if target[k] == nil then
            if type(v) == "table" then
                target[k] = {}
            else
                target[k] = v
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("LOOT_OPENED")
frame:RegisterEvent("LOOT_CLOSED")
frame:RegisterEvent("LOOT_SLOT_CLEARED")
frame:RegisterEvent("UI_ERROR_MESSAGE")
frame:RegisterEvent("BAG_UPDATE_DELAYED")

frame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        TaschenwartDB = TaschenwartDB or {}
        TaschenwartCharDB = TaschenwartCharDB or {}
        DB, CharDB = TaschenwartDB, TaschenwartCharDB
        ApplyDefaults(DB, defaults)
        ApplyDefaults(CharDB, charDefaults)
        frame:UnregisterEvent("ADDON_LOADED")
    elseif not DB then
        return
    elseif event == "LOOT_OPENED" then
        lootOpen = true
        Schedule(0.4) -- dem Auto-Loot kurz Zeit lassen
    elseif event == "LOOT_CLOSED" then
        lootOpen = false
        awaitingLoot = nil
        wipe(declined)
        HidePrompt()
    elseif event == "LOOT_SLOT_CLEARED" then
        if current then
            -- wurde der angefragte Drop inzwischen anders aufgenommen?
            local still = false
            for i = 1, GetNumLootItems() do
                if GetLootSlotLink(i) == current.lootLink then still = true break end
            end
            if not still then HidePrompt() end
        end
        Schedule(0.3)
    elseif event == "UI_ERROR_MESSAGE" then
        if lootOpen and (arg2 == ERR_INV_FULL or arg1 == ERR_INV_FULL) then
            Schedule(0.2)
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        if awaitingLoot then LootAwaited() end
    end
end)

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------
SLASH_TASCHENWART1 = "/taschenwart"
SLASH_TASCHENWART2 = "/twart"
SlashCmdList["TASCHENWART"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if not DB then return end
    if msg == "test" then
        local c = FindCheapest()
        Print("Freie Taschenplätze: " .. FreeSlots())
        if c then
            Print("Billigstes wegwerfbares Item: " .. c.link .. " x" .. c.count .. " (" .. Money(c.value) .. ")")
        else
            Print("Kein Item gefunden, das weggeworfen werden dürfte.")
        end
    elseif msg == "an" or msg == "on" then
        DB.enabled = true
        Print("aktiviert.")
    elseif msg == "aus" or msg == "off" then
        DB.enabled = false
        Print("deaktiviert.")
    else
        ToggleOptions()
    end
end
