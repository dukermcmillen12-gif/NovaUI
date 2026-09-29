local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local Library = {
    Version = "1.0.0",
    Flags = {},
    Windows = {},
    Theme = {
        background = Color3.fromRGB(14, 15, 17),
        surface = Color3.fromRGB(19, 20, 22),
        elevated = Color3.fromRGB(24, 25, 28),
        subtle = Color3.fromRGB(30, 31, 35),
        stroke = Color3.fromRGB(45, 47, 52),
        text = Color3.fromRGB(184, 187, 193),
        muted = Color3.fromRGB(105, 109, 118),
        accent = Color3.fromRGB(156, 160, 168),
        accentSoft = Color3.fromRGB(35, 37, 41),
        good = Color3.fromRGB(103, 162, 126),
        warn = Color3.fromRGB(167, 145, 95),
        bad = Color3.fromRGB(174, 87, 98),
        hover = Color3.fromRGB(28, 29, 33),
        card = Color3.fromRGB(17, 18, 20),
        cardRaised = Color3.fromRGB(26, 27, 30),
        accentLine = Color3.fromRGB(142, 146, 154),
        nav = Color3.fromRGB(16, 17, 19),
        navRaised = Color3.fromRGB(24, 25, 28),
        navActive = Color3.fromRGB(32, 34, 38),
    }
}

local Window = {}
local Tab = {}
local Section = {}

Window.__index = Window
Tab.__index = Tab
Section.__index = Section

local function create(className, properties, parent)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        object[property] = value
    end
    if parent then
        object.Parent = parent
    end
    return object
end

local function corner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius or 4),
    }, parent)
end

local function stroke(parent, color, transparency, thickness)
    return create("UIStroke", {
        Color = color,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function padding(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
    }, parent)
end

local function tween(object, duration, properties, style, direction)
    if not object or not object.Parent then
        return nil
    end
    local animation = TweenService:Create(
        object,
        TweenInfo.new(duration or 0.15, style or Enum.EasingStyle.Quart, direction or Enum.EasingDirection.Out),
        properties
    )
    animation:Play()
    return animation
end

local function call(callback, ...)
    if type(callback) ~= "function" then
        return
    end
    local args = table.pack(...)
    task.spawn(function()
        pcall(callback, table.unpack(args, 1, args.n))
    end)
end

local function clamp(number, minimum, maximum)
    return math.max(minimum, math.min(maximum, number))
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function keyCodeFrom(value)
    if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
        return value
    end
    local name = tostring(value or "RightShift")
    return Enum.KeyCode[name] or Enum.KeyCode.RightShift
end

local function normalizeOptions(options)
    local result = {}
    for _, option in ipairs(type(options) == "table" and options or {}) do
        table.insert(result, tostring(option))
    end
    if #result == 0 then
        table.insert(result, "None")
    end
    return result
end

local function copyArray(values)
    local result = {}
    for index, value in ipairs(values or {}) do
        result[index] = value
    end
    return result
end

local function contains(values, wanted)
    for _, value in ipairs(values or {}) do
        if tostring(value) == tostring(wanted) then
            return true
        end
    end
    return false
end

local function findParent()
    local choices = {}
    pcall(function()
        if gethui then
            local hidden = gethui()
            if hidden then
                table.insert(choices, hidden)
            end
        end
    end)
    table.insert(choices, CoreGui)
    if LocalPlayer then
        table.insert(choices, LocalPlayer:WaitForChild("PlayerGui"))
    end
    return choices
end

local function parentGui(gui)
    for _, parent in ipairs(findParent()) do
        local ok = pcall(function()
            gui.Parent = parent
        end)
        if ok and gui.Parent == parent then
            return parent
        end
    end
    return nil
end

local function destroyOld(name)
    for _, parent in ipairs(findParent()) do
        pcall(function()
            local existing = parent:FindFirstChild(name)
            if existing then
                existing:Destroy()
            end
        end)
    end
end

local function pointInside(guiObject, point)
    if not guiObject or not guiObject.Parent or not guiObject.Visible then
        return false
    end
    local position = guiObject.AbsolutePosition
    local size = guiObject.AbsoluteSize
    return point.X >= position.X and point.X <= position.X + size.X and point.Y >= position.Y and point.Y <= position.Y + size.Y
end

local function titleCase(value)
    local text = tostring(value or "")
    if text == "" then
        return "Tab"
    end
    return text
end

local function flagName(name, supplied)
    if supplied and tostring(supplied) ~= "" then
        return tostring(supplied)
    end
    return tostring(name or "Control"):gsub("[^%w_]", "")
end

function Window:_connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self.Connections, connection)
    return connection
end

function Window:_registerControl(control, row, searchText, section, tab)
    control.Row = row
    control.Window = self
    control.Section = section
    control.Tab = tab
    row:SetAttribute("NovaBaseVisible", row.Visible)
    table.insert(self.SearchEntries, {
        Row = row,
        Text = tostring(searchText or ""):lower(),
        Section = section,
        Tab = tab,
    })
    if section then
        table.insert(section.SearchRows, row)
    end
    return control
end

function Window:_rememberFlag(flag, control, value)
    if not flag or flag == "" then
        return
    end
    self.FlagControls[flag] = control
    Library.Flags[flag] = value
    self:_scheduleSave()
end

function Window:_scheduleSave()
    if not self.ConfigSaving.Enabled or not writefile then
        return
    end
    self.SaveToken += 1
    local token = self.SaveToken
    task.delay(0.35, function()
        if self.Destroyed or token ~= self.SaveToken then
            return
        end
        self:SaveConfiguration()
    end)
end

function Window:_configPath()
    local folder = trim(self.ConfigSaving.FolderName)
    if folder == "" then
        folder = "NovaUI"
    end
    local fileName = trim(self.ConfigSaving.FileName)
    if fileName == "" then
        fileName = "Config"
    end
    return folder, folder .. "/" .. fileName .. ".json"
end

function Window:SaveConfiguration()
    if not self.ConfigSaving.Enabled or not writefile then
        return false
    end
    local folder, path = self:_configPath()
    if makefolder then
        pcall(function()
            makefolder(folder)
        end)
    end
    local data = {}
    for flag in pairs(self.FlagControls) do
        data[flag] = Library.Flags[flag]
    end
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if not ok then
        return false
    end
    return pcall(writefile, path, encoded)
end

function Window:LoadConfiguration()
    if not self.ConfigSaving.Enabled or not readfile or not isfile then
        return false
    end
    local _, path = self:_configPath()
    local exists = false
    pcall(function()
        exists = isfile(path)
    end)
    if not exists then
        return false
    end
    local ok, raw = pcall(readfile, path)
    if not ok then
        return false
    end
    local decodedOk, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not decodedOk or type(data) ~= "table" then
        return false
    end
    for flag, value in pairs(data) do
        local control = self.FlagControls[flag]
        if control and control.Set then
            pcall(control.Set, control, value)
        end
    end
    return true
end

function Window:_setSectionCollapsed(section, collapsed, animate)
    section.Collapsed = collapsed == true
    section.Content.Visible = not section.Collapsed
    section.Arrow.Text = section.Collapsed and "›" or "⌄"
    section.Arrow.TextColor3 = section.Collapsed and self.Theme.muted or self.Theme.text
    if animate then
        section.Arrow.Rotation = section.Collapsed and -90 or 0
        tween(section.Arrow, 0.13, {Rotation = 0})
    end
end

function Window:_closeDropdowns(except)
    for row, closer in pairs(self.DropdownClosers) do
        if row ~= except then
            pcall(closer)
        end
    end
end

function Window:_applySearch(raw)
    local query = trim(raw):lower()
    local matchesByTab = {}

    for _, section in ipairs(self.Sections) do
        section.SearchMatchCount = 0
    end

    for _, entry in ipairs(self.SearchEntries) do
        local baseVisible = entry.Row:GetAttribute("NovaBaseVisible") ~= false
        local matched = query == "" or string.find(entry.Text, query, 1, true) ~= nil
        entry.Row.Visible = baseVisible and matched
        if matched then
            matchesByTab[entry.Tab] = (matchesByTab[entry.Tab] or 0) + 1
            if entry.Section then
                entry.Section.SearchMatchCount += 1
            end
        end
    end

    for _, section in ipairs(self.Sections) do
        local titleMatch = query ~= "" and string.find(section.SearchText, query, 1, true) ~= nil
        local show = query == "" or titleMatch or section.SearchMatchCount > 0
        section.Card.Visible = show
        if query ~= "" and show then
            if section.SearchOriginalCollapsed == nil then
                section.SearchOriginalCollapsed = section.Collapsed
            end
            self:_setSectionCollapsed(section, false, false)
        elseif query == "" and section.SearchOriginalCollapsed ~= nil then
            self:_setSectionCollapsed(section, section.SearchOriginalCollapsed, false)
            section.SearchOriginalCollapsed = nil
        end
    end

    if query ~= "" and self.ActiveTab and not matchesByTab[self.ActiveTab] then
        for _, tab in ipairs(self.Tabs) do
            if matchesByTab[tab] then
                self:SelectTab(tab)
                break
            end
        end
    end
end

function Window:_bindHover(frame, normalColor, hoverColor, normalTransparency, hoverTransparency)
    self:_connect(frame.MouseEnter, function()
        tween(frame, 0.12, {
            BackgroundColor3 = hoverColor,
            BackgroundTransparency = hoverTransparency or 0,
        })
    end)
    self:_connect(frame.MouseLeave, function()
        tween(frame, 0.12, {
            BackgroundColor3 = normalColor,
            BackgroundTransparency = normalTransparency or 0,
        })
    end)
end

function Window:_viewport()
    local camera = Workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

function Window:_clampPosition()
    if not self.Root or not self.Root.Parent then
        return
    end
    local viewport = self:_viewport()
    local size = self.Root.AbsoluteSize
    local x = clamp(self.Root.Position.X.Offset, 0, math.max(0, viewport.X - size.X))
    local y = clamp(self.Root.Position.Y.Offset, 0, math.max(0, viewport.Y - size.Y))
    self.Root.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
    self.Shadow.Position = self.Root.Position + UDim2.fromOffset(10, 12)
end

function Window:_updateScale()
    if not self.Root or not self.Root.Parent then
        return
    end
    local viewport = self:_viewport()
    local width = math.max(1, self.Root.Size.X.Offset)
    local height = math.max(1, self.Root.Size.Y.Offset)
    local fitX = (viewport.X - 10) / width
    local fitY = (viewport.Y - 10) / height
    self.Scale.Scale = clamp(math.min(fitX, fitY, 1), 0.56, 1)
    task.defer(function()
        if self.Root and self.Root.Parent then
            self:_clampPosition()
        end
    end)
end

function Window:_makeDraggable(handle)
    local dragging = false
    local trackedInput
    local startPointer
    local startPosition

    self:_connect(handle.InputBegan, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        dragging = true
        trackedInput = input
        startPointer = Vector2.new(input.Position.X, input.Position.Y)
        startPosition = Vector2.new(self.Root.Position.X.Offset, self.Root.Position.Y.Offset)
    end)

    self:_connect(UserInputService.InputChanged, function(input)
        if not dragging or not trackedInput then
            return
        end
        local touch = trackedInput.UserInputType == Enum.UserInputType.Touch and input == trackedInput
        local mouse = trackedInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
        if not touch and not mouse then
            return
        end
        local pointer = Vector2.new(input.Position.X, input.Position.Y)
        local desired = startPosition + pointer - startPointer
        local viewport = self:_viewport()
        local size = self.Root.AbsoluteSize
        local x = clamp(desired.X, 0, math.max(0, viewport.X - size.X))
        local y = clamp(desired.Y, 0, math.max(0, viewport.Y - size.Y))
        self.Root.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
        self.Shadow.Position = self.Root.Position + UDim2.fromOffset(10, 12)
    end)

    self:_connect(UserInputService.InputEnded, function(input)
        if not dragging or not trackedInput then
            return
        end
        local touch = trackedInput.UserInputType == Enum.UserInputType.Touch and input == trackedInput
        local mouse = trackedInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1
        if touch or mouse then
            dragging = false
            trackedInput = nil
            self:_clampPosition()
        end
    end)
end

function Window:_makeResizable(handle)
    local dragging = false
    local trackedInput
    local startPointer
    local startSize

    self:_connect(handle.InputBegan, function(input)
        if self.Minimized then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        dragging = true
        trackedInput = input
        startPointer = input.Position
        startSize = self.Root.Size
    end)

    self:_connect(UserInputService.InputChanged, function(input)
        if not dragging or not trackedInput or self.Minimized then
            return
        end
        local touch = trackedInput.UserInputType == Enum.UserInputType.Touch and input == trackedInput
        local mouse = trackedInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
        if not touch and not mouse then
            return
        end
        local delta = input.Position - startPointer
        local viewport = self:_viewport()
        local minimumWidth = UserInputService.TouchEnabled and 380 or 620
        local minimumHeight = UserInputService.TouchEnabled and 390 or 410
        local width = clamp(startSize.X.Offset + delta.X, minimumWidth, math.max(minimumWidth, math.min(920, viewport.X - 18)))
        local height = clamp(startSize.Y.Offset + delta.Y, minimumHeight, math.max(minimumHeight, math.min(560, viewport.Y - 18)))
        self.Root.Size = UDim2.fromOffset(width, height)
        self.LastExpandedSize = self.Root.Size
        self.Shadow.Size = self.Root.Size
        self:_updateScale()
    end)

    self:_connect(UserInputService.InputEnded, function(input)
        if not dragging or not trackedInput then
            return
        end
        local touch = trackedInput.UserInputType == Enum.UserInputType.Touch and input == trackedInput
        local mouse = trackedInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1
        if touch or mouse then
            dragging = false
            trackedInput = nil
            self:_clampPosition()
        end
    end)
end

function Window:Minimize(value)
    if value == nil then
        value = not self.Minimized
    end
    value = value == true
    if self.Minimized == value then
        return
    end
    self.Minimized = value
    local targetSize = value and UDim2.fromOffset(self.LastExpandedSize.X.Offset, 46) or self.LastExpandedSize
    self.ResizeHandle.Visible = not value
    self.MinimizeButton.Text = value and "+" or "–"
    if not value then
        self.Body.Visible = true
        self.Body.GroupTransparency = 1
        tween(self.Body, 0.18, {GroupTransparency = 0})
    else
        tween(self.Body, 0.1, {GroupTransparency = 1})
    end
    local animation = tween(self.Root, 0.18, {Size = targetSize})
    if animation then
        task.spawn(function()
            pcall(function()
                animation.Completed:Wait()
            end)
            if self.Destroyed then
                return
            end
            if self.Minimized then
                self.Body.Visible = false
            else
                self.Body.GroupTransparency = 0
            end
        end)
    end
end

function Window:SetVisible(value)
    self.Visible = value == true
    self.Root.Visible = self.Visible
    self.Shadow.Visible = self.Visible
end

function Window:Toggle()
    self:SetVisible(not self.Visible)
end

function Window:SetTitle(value)
    self.Name = tostring(value or self.Name)
    self.TitleLabel.Text = self.Name
    self.BrandLetter.Text = self.Name:sub(1, 1):upper()
end

function Window:SetBadge(value)
    self.BadgeLabel.Text = tostring(value or "")
    self.BadgeLabel.Visible = self.BadgeLabel.Text ~= ""
end

function Window:SelectTab(tab)
    if type(tab) == "string" then
        for _, candidate in ipairs(self.Tabs) do
            if candidate.Name == tab then
                tab = candidate
                break
            end
        end
    end
    if type(tab) ~= "table" or not tab.Page then
        return
    end
    self.ActiveTab = tab
    self:_closeDropdowns()
    for _, other in ipairs(self.Tabs) do
        local selected = other == tab
        other.Page.Visible = selected
        if selected then
            other.Page.Position = UDim2.fromOffset(8, 0)
            tween(other.Page, 0.16, {Position = UDim2.fromOffset(0, 0)})
        end
        tween(other.Button, 0.12, {
            BackgroundTransparency = selected and 0 or 1,
            BackgroundColor3 = selected and self.Theme.navActive or self.Theme.nav,
        })
        tween(other.Stroke, 0.12, {
            Transparency = selected and 0.45 or 1,
            Color = self.Theme.stroke,
        })
        other.Indicator.Visible = selected
        if other.IconLabel then
            tween(other.IconLabel, 0.12, {TextColor3 = selected and self.Theme.text or self.Theme.muted})
        end
        if other.IconImage then
            tween(other.IconImage, 0.12, {ImageColor3 = selected and self.Theme.text or self.Theme.muted})
        end
        tween(other.TextLabel, 0.12, {TextColor3 = selected and self.Theme.text or self.Theme.muted})
    end
end

function Window:_buildUserPanel()
    if not self.Settings.ShowUserPanel then
        self.TabStrip.Size = UDim2.new(1, -18, 1, -22)
        return
    end

    local panel = create("Frame", {
        BackgroundColor3 = self.Theme.surface,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 7, 1, -58),
        Size = UDim2.new(1, -14, 0, 49),
    }, self.NavRail)
    corner(panel, 4)
    stroke(panel, self.Theme.stroke, 0.5, 1)

    local avatar = create("ImageLabel", {
        BackgroundColor3 = self.Theme.subtle,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(6, 8),
        Size = UDim2.fromOffset(30, 30),
        Image = "",
    }, panel)
    corner(avatar, 4)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = LocalPlayer and ("@" .. LocalPlayer.Name) or "@player",
        TextColor3 = self.Theme.text,
        TextSize = 9,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(42, 6),
        Size = UDim2.new(1, -47, 0, 14),
    }, panel)

    local info = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = "Ready  •  0ms",
        TextColor3 = self.Theme.muted,
        TextSize = 8,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(42, 21),
        Size = UDim2.new(1, -47, 0, 20),
    }, panel)

    if LocalPlayer then
        task.spawn(function()
            local ok, image = pcall(function()
                return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            if ok and avatar.Parent then
                avatar.Image = image
            end
        end)
    end

    task.spawn(function()
        while not self.Destroyed and info.Parent do
            local ping = 0
            if LocalPlayer then
                pcall(function()
                    ping = math.floor(LocalPlayer:GetNetworkPing() * 1000 + 0.5)
                end)
            end
            info.Text = string.format("Ready  •  %dms", ping)
            task.wait(1)
        end
    end)
end

function Window:CreateTab(name, icon, description)
    if type(name) == "table" then
        local settings = name
        name = settings.Name or settings.Title or "Tab"
        icon = settings.Icon
        description = settings.Description
    end

    name = titleCase(name)
    description = tostring(description or "Controls and settings")

    local page = create("ScrollingFrame", {
        Name = "Page" .. name:gsub("[^%w]", ""),
        Active = true,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarImageColor3 = self.Theme.stroke,
        ScrollBarThickness = 2,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
    }, self.PageHost)
    padding(page, 2, 6, 2, 12)

    local layout = create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)

    local header = create("Frame", {
        BackgroundColor3 = self.Theme.surface,
        BorderSizePixel = 0,
        LayoutOrder = -100,
        Size = UDim2.new(1, 0, 0, 42),
    }, page)
    corner(header, 5)
    stroke(header, self.Theme.stroke, 0.68, 1)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        Text = name:upper(),
        TextColor3 = self.Theme.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(12, 4),
        Size = UDim2.new(1, -24, 0, 19),
    }, header)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = description,
        TextColor3 = self.Theme.muted,
        TextSize = 9,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(12, 22),
        Size = UDim2.new(1, -24, 0, 14),
    }, header)

    local button = create("TextButton", {
        Name = "Tab" .. name:gsub("[^%w]", ""),
        AutoButtonColor = false,
        BackgroundColor3 = self.Theme.nav,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        Size = UDim2.new(1, -8, 0, 36),
    }, self.TabStrip)
    corner(button, 4)

    local buttonStroke = stroke(button, self.Theme.stroke, 1, 1)

    local indicator = create("Frame", {
        BackgroundColor3 = self.Theme.accentLine,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 7),
        Size = UDim2.fromOffset(2, 22),
        Visible = false,
    }, button)
    corner(indicator, 1)

    local iconLabel
    local iconImage
    if type(icon) == "number" or tostring(icon or ""):match("^%d+$") then
        iconImage = create("ImageLabel", {
            BackgroundTransparency = 1,
            Image = "rbxassetid://" .. tostring(icon),
            ImageColor3 = self.Theme.muted,
            Position = UDim2.fromOffset(11, 8),
            Size = UDim2.fromOffset(18, 18),
        }, button)
    else
        iconLabel = create("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            Text = tostring(icon or name:sub(1, 1)),
            TextColor3 = self.Theme.muted,
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Center,
            Position = UDim2.fromOffset(8, 0),
            Size = UDim2.fromOffset(22, 36),
        }, button)
    end

    local textLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = name,
        TextColor3 = self.Theme.muted,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(34, 0),
        Size = UDim2.new(1, -38, 1, 0),
    }, button)

    local tab = setmetatable({
        Window = self,
        Name = name,
        Page = page,
        Layout = layout,
        Button = button,
        Stroke = buttonStroke,
        Indicator = indicator,
        IconLabel = iconLabel,
        IconImage = iconImage,
        TextLabel = textLabel,
        CurrentSection = nil,
    }, Tab)

    table.insert(self.Tabs, tab)

    self:_connect(button.MouseButton1Click, function()
        if self.SearchBox.Text ~= "" then
            self.SearchBox.Text = ""
        end
        self:SelectTab(tab)
    end)

    self:_connect(button.MouseEnter, function()
        if self.ActiveTab ~= tab then
            tween(button, 0.1, {
                BackgroundColor3 = self.Theme.navRaised,
                BackgroundTransparency = 0,
            })
        end
    end)

    self:_connect(button.MouseLeave, function()
        if self.ActiveTab ~= tab then
            tween(button, 0.1, {
                BackgroundColor3 = self.Theme.nav,
                BackgroundTransparency = 1,
            })
        end
    end)

    if #self.Tabs == 1 then
        self:SelectTab(tab)
    end

    return tab
end

Window.Tab = Window.CreateTab

function Tab:_parent()
    if self.CurrentSection and self.CurrentSection.Content and self.CurrentSection.Content.Parent then
        return self.CurrentSection.Content, self.CurrentSection
    end
    return self.Page, nil
end

function Tab:CreateSection(name, description, collapsed)
    if type(name) == "table" then
        local settings = name
        name = settings.Name or settings.Title or "Section"
        description = settings.Description
        collapsed = settings.Collapsed
    end

    local outer = create("Frame", {
        Name = "Section" .. tostring(name):gsub("[^%w]", ""),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = self.Window.Theme.card,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
    }, self.Page)
    corner(outer, 5)
    stroke(outer, self.Window.Theme.stroke, 0.62, 1)
    padding(outer, 9, 9, 7, 8)

    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, outer)

    local header = create("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 0,
        Text = "",
        Size = UDim2.new(1, 0, 0, 27),
    }, outer)

    local title = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = tostring(name or "SECTION"),
        TextColor3 = self.Window.Theme.text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(2, 2),
        Size = UDim2.new(1, -34, 0, 18),
    }, header)

    local arrow = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = "⌄",
        TextColor3 = self.Window.Theme.text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Center,
        Position = UDim2.new(1, -22, 0, 2),
        Size = UDim2.fromOffset(20, 20),
    }, header)

    create("Frame", {
        BackgroundColor3 = self.Window.Theme.stroke,
        BackgroundTransparency = 0.38,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 1),
    }, outer)

    local content = create("Frame", {
        Name = "Content",
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 0),
    }, outer)
    padding(content, 0, 0, 7, 2)

    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, content)

    local section = setmetatable({
        Window = self.Window,
        Tab = self,
        Name = tostring(name or "Section"),
        Description = tostring(description or ""),
        Card = outer,
        Header = header,
        TitleLabel = title,
        Arrow = arrow,
        Content = content,
        Collapsed = collapsed == true,
        SearchRows = {},
        SearchMatchCount = 0,
        SearchText = (tostring(name or "") .. " " .. tostring(description or "")):lower(),
    }, Section)

    table.insert(self.Window.Sections, section)
    self.CurrentSection = section
    self.Window:_setSectionCollapsed(section, section.Collapsed, false)

    self.Window:_connect(header.MouseButton1Click, function()
        self.Window:_setSectionCollapsed(section, not section.Collapsed, true)
    end)

    return section
end

Tab.Section = Tab.CreateSection

function Section:Set(value)
    self.Name = tostring(value or self.Name)
    self.TitleLabel.Text = self.Name
    self.SearchText = (self.Name .. " " .. self.Description):lower()
end

function Section:SetCollapsed(value)
    self.Window:_setSectionCollapsed(self, value == true, true)
end

function Section:_parent()
    return self.Content, self
end

local function controlHost(owner)
    if getmetatable(owner) == Section then
        return owner.Content, owner, owner.Tab
    end
    local parent, section = owner:_parent()
    return parent, section, owner
end

local function registerFlag(window, control, settings, initialValue)
    local flag = flagName(settings.Name, settings.Flag)
    control.Flag = flag
    if flag ~= "" then
        window:_rememberFlag(flag, control, initialValue)
    end
end

local function addButton(owner, settings)
    settings = type(settings) == "table" and settings or {Name = tostring(settings or "Button")}
    local parent, section, tab = controlHost(owner)
    local window = owner.Window
    local theme = window.Theme
    local baseColor = settings.Color or theme.cardRaised

    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = baseColor,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamMedium,
        Text = tostring(settings.Name or "Button"),
        TextColor3 = theme.text,
        TextSize = 12,
        Size = UDim2.new(1, 0, 0, settings.Height or 31),
    }, parent)
    corner(button, 4)
    stroke(button, theme.stroke, 0.58, 1)

    local scale = create("UIScale", {Scale = 1}, button)

    window:_connect(button.MouseEnter, function()
        tween(button, 0.14, {
            BackgroundColor3 = settings.HoverColor or theme.hover,
            BackgroundTransparency = 0.02,
        })
        tween(scale, 0.14, {Scale = 1.012})
    end)

    window:_connect(button.MouseLeave, function()
        tween(button, 0.14, {
            BackgroundColor3 = baseColor,
            BackgroundTransparency = 0,
        })
        tween(scale, 0.14, {Scale = 1})
    end)

    window:_connect(button.MouseButton1Down, function()
        tween(scale, 0.08, {Scale = 0.985})
    end)

    window:_connect(button.MouseButton1Up, function()
        tween(scale, 0.16, {Scale = 1.012}, Enum.EasingStyle.Back)
    end)

    window:_connect(button.MouseButton1Click, function()
        call(settings.Callback)
    end)

    local control = {
        Button = button,
    }

    function control:Set(value)
        button.Text = tostring(value or "")
    end

    function control:SetVisible(value)
        button.Visible = value == true
        button:SetAttribute("NovaBaseVisible", button.Visible)
    end

    function control:Destroy()
        button:Destroy()
    end

    return window:_registerControl(control, button, settings.Name, section, tab)
end

local function addToggle(owner, settings)
    settings = type(settings) == "table" and settings or {Name = tostring(settings or "Toggle")}
    local parent, section, tab = controlHost(owner)
    local window = owner.Window
    local theme = window.Theme

    local row = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = theme.surface,
        BorderSizePixel = 0,
        Text = "",
        Size = UDim2.new(1, 0, 0, 34),
    }, parent)
    corner(row, 4)
    stroke(row, theme.stroke, 0.56, 1)
    window:_bindHover(row, theme.surface, theme.elevated, 0, 0)

    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Text = tostring(settings.Name or "Toggle"),
        Font = Enum.Font.GothamMedium,
        TextColor3 = theme.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -66, 1, 0),
    }, row)

    local track = create("Frame", {
        BackgroundColor3 = theme.subtle,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -44, 0.5, -9),
        Size = UDim2.fromOffset(34, 18),
    }, row)
    corner(track, 4)

    local dot = create("Frame", {
        BackgroundColor3 = theme.muted,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(3, 3),
        Size = UDim2.fromOffset(12, 12),
    }, track)
    corner(dot, 3)

    local control = {
        CurrentValue = settings.CurrentValue == true,
    }

    local function redraw(runCallback)
        tween(track, 0.18, {
            BackgroundColor3 = control.CurrentValue and theme.accent or theme.subtle,
        })
        tween(dot, 0.2, {
            BackgroundColor3 = control.CurrentValue and theme.background or theme.muted,
            Position = control.CurrentValue and UDim2.fromOffset(19, 3) or UDim2.fromOffset(3, 3),
        }, Enum.EasingStyle.Back)
        if control.Flag and control.Flag ~= "" then
            Library.Flags[control.Flag] = control.CurrentValue
            window:_scheduleSave()
        end
        if runCallback then
            call(settings.Callback, control.CurrentValue)
        end
    end

    function control:Set(value)
        control.CurrentValue = value == true
        redraw(true)
    end

    function control:Get()
        return control.CurrentValue
    end

    function control:SetVisible(value)
        row.Visible = value == true
        row:SetAttribute("NovaBaseVisible", row.Visible)
    end

    window:_connect(row.MouseButton1Click, function()
        control.CurrentValue = not control.CurrentValue
        redraw(true)
    end)

    registerFlag(window, control, settings, control.CurrentValue)
    redraw(false)
    window:_registerControl(control, row, settings.Name, section, tab)
    control.Label = label
    return control
end

local function addSlider(owner, settings)
    settings = type(settings) == "table" and settings or {Name = tostring(settings or "Slider")}
    local parent, section, tab = controlHost(owner)
    local window = owner.Window
    local theme = window.Theme
    local range = type(settings.Range) == "table" and settings.Range or {0, 100}
    local minimum = tonumber(range[1]) or 0
    local maximum = tonumber(range[2]) or 100
    if maximum <= minimum then
        maximum = minimum + 1
    end
    local increment = tonumber(settings.Increment) or 1
    if increment <= 0 then
        increment = 1
    end

    local row = create("Frame", {
        BackgroundColor3 = theme.surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 52),
    }, parent)
    corner(row, 4)
    stroke(row, theme.stroke, 0.56, 1)
    window:_bindHover(row, theme.surface, theme.elevated, 0, 0)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Text = tostring(settings.Name or "Slider"),
        Font = Enum.Font.GothamMedium,
        TextColor3 = theme.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(12, 4),
        Size = UDim2.new(1, -90, 0, 19),
    }, row)

    local valueLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextColor3 = theme.muted,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(1, -92, 0, 4),
        Size = UDim2.fromOffset(80, 19),
    }, row)

    local bar = create("Frame", {
        BackgroundColor3 = theme.subtle,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        Position = UDim2.fromOffset(12, 32),
        Size = UDim2.new(1, -24, 0, 6),
    }, row)
    corner(bar, 2)

    local fill = create("Frame", {
        BackgroundColor3 = settings.Color or theme.accent,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1),
    }, bar)
    corner(fill, 2)

    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = settings.Color or theme.text,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        ZIndex = 4,
    }, bar)
    corner(knob, 4)

    local hitbox = create("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        Position = UDim2.fromOffset(5, 23),
        Size = UDim2.new(1, -10, 0, 25),
        ZIndex = 5,
    }, row)

    local control = {
        CurrentValue = clamp(tonumber(settings.CurrentValue) or minimum, minimum, maximum),
    }

    local dragging = false

    local function rounded(value)
        local steps = math.floor(((value - minimum) / increment) + 0.5)
        return clamp(minimum + steps * increment, minimum, maximum)
    end

    local function redraw(runCallback)
        control.CurrentValue = rounded(control.CurrentValue)
        local ratio = (control.CurrentValue - minimum) / (maximum - minimum)
        tween(fill, 0.08, {Size = UDim2.fromScale(ratio, 1)})
        tween(knob, 0.08, {Position = UDim2.new(ratio, 0, 0.5, 0)})
        valueLabel.Text = tostring(control.CurrentValue) .. tostring(settings.Suffix or "")
        if control.Flag and control.Flag ~= "" then
            Library.Flags[control.Flag] = control.CurrentValue
            window:_scheduleSave()
        end
        if runCallback then
            call(settings.Callback, control.CurrentValue)
        end
    end

    local function setFromPoint(point)
        local x = clamp(point.X - bar.AbsolutePosition.X, 0, bar.AbsoluteSize.X)
        local ratio = bar.AbsoluteSize.X > 0 and x / bar.AbsoluteSize.X or 0
        control.CurrentValue = rounded(minimum + (maximum - minimum) * ratio)
        redraw(true)
    end

    function control:Set(value)
        control.CurrentValue = clamp(tonumber(value) or minimum, minimum, maximum)
        redraw(true)
    end

    function control:Get()
        return control.CurrentValue
    end

    function control:SetVisible(value)
        row.Visible = value == true
        row:SetAttribute("NovaBaseVisible", row.Visible)
    end

    window:_connect(hitbox.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromPoint(input.Position)
        end
    end)

    window:_connect(UserInputService.InputChanged, function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            setFromPoint(input.Position)
        end
    end)

    window:_connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    registerFlag(window, control, settings, control.CurrentValue)
    redraw(false)
    return window:_registerControl(control, row, settings.Name, section, tab)
end

local function addDropdown(owner, settings)
    settings = type(settings) == "table" and settings or {Name = tostring(settings or "Dropdown")}
    local parent, section, tab = controlHost(owner)
    local window = owner.Window
    local theme = window.Theme
    local options = normalizeOptions(settings.Options)
    local multiple = settings.MultipleOptions == true
    local baseHeight = 38

    local row = create("Frame", {
        BackgroundColor3 = theme.surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, baseHeight),
    }, parent)
    corner(row, 4)
    stroke(row, theme.stroke, 0.56, 1)
    window:_bindHover(row, theme.surface, theme.elevated, 0, 0)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Text = tostring(settings.Name or "Dropdown"),
        Font = Enum.Font.GothamMedium,
        TextColor3 = theme.text,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(0.43, -12, 1, 0),
    }, row)

    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = theme.subtle,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamMedium,
        Text = "",
        TextColor3 = theme.text,
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0.43, 0, 0, 4),
        Size = UDim2.new(0.57, -8, 0, 30),
    }, row)
    corner(button, 4)
    stroke(button, theme.stroke, 0.6, 1)
    padding(button, 7, 22, 0, 0)

    local arrow = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = "⌄",
        TextColor3 = theme.muted,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center,
        Position = UDim2.new(1, -19, 0, 0),
        Size = UDim2.fromOffset(17, 30),
        ZIndex = 24,
    }, button)

    local list = create("ScrollingFrame", {
        Active = true,
        BackgroundColor3 = theme.surface,
        BorderSizePixel = 0,
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarImageColor3 = theme.accent,
        ScrollBarThickness = 2,
        Position = UDim2.fromOffset(8, baseHeight + 1),
        Size = UDim2.new(1, -16, 0, 0),
        Visible = false,
        ZIndex = 30,
    }, row)
    corner(list, 5)
    stroke(list, theme.stroke, 0.45, 1)
    padding(list, 4, 4, 4, 4)

    create("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, list)

    local selected = {}
    local current = settings.CurrentOption
    if type(current) == "table" then
        for _, value in ipairs(current) do
            if contains(options, value) then
                table.insert(selected, tostring(value))
            end
        end
    elseif current ~= nil and contains(options, current) then
        table.insert(selected, tostring(current))
    end
    if #selected == 0 then
        table.insert(selected, options[1])
    end
    if not multiple and #selected > 1 then
        selected = {selected[1]}
    end

    local open = false
    local optionButtons = {}
    local visibleHeight = 34

    local control = {
        CurrentOption = copyArray(selected),
    }

    local function displayText()
        if #selected == 0 then
            return "None"
        end
        return table.concat(selected, ", ")
    end

    local function updateButtons()
        for value, optionButton in pairs(optionButtons) do
            local active = contains(selected, value)
            tween(optionButton, 0.1, {
                BackgroundColor3 = active and theme.navActive or theme.elevated,
                TextColor3 = active and theme.text or theme.muted,
            })
        end
    end

    local function redraw(runCallback)
        control.CurrentOption = copyArray(selected)
        button.Text = displayText()
        if control.Flag and control.Flag ~= "" then
            Library.Flags[control.Flag] = copyArray(selected)
            window:_scheduleSave()
        end
        updateButtons()
        if runCallback then
            call(settings.Callback, copyArray(selected))
        end
    end

    local function setOpen(value)
        value = value == true
        if value then
            window:_closeDropdowns(row)
        end
        open = value
        if open then
            list.Visible = true
        end
        tween(arrow, 0.16, {Rotation = open and 180 or 0})
        tween(list, 0.18, {Size = UDim2.new(1, -16, 0, open and visibleHeight or 0)})
        tween(row, 0.18, {Size = UDim2.new(1, 0, 0, open and (baseHeight + visibleHeight + 5) or baseHeight)})
        if not open then
            task.delay(0.16, function()
                if list.Parent and not open then
                    list.Visible = false
                end
            end)
        end
    end

    local function rebuild()
        for _, optionButton in pairs(optionButtons) do
            optionButton:Destroy()
        end
        table.clear(optionButtons)

        for _, value in ipairs(options) do
            local optionButton = create("TextButton", {
                AutoButtonColor = false,
                BackgroundColor3 = theme.elevated,
                BackgroundTransparency = 0.12,
                BorderSizePixel = 0,
                Font = Enum.Font.Gotham,
                Text = value,
                TextColor3 = theme.muted,
                TextSize = 13,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                Size = UDim2.new(1, -2, 0, 28),
                ZIndex = 31,
            }, list)
            corner(optionButton, 4)
            padding(optionButton, 7, 7, 0, 0)
            window:_bindHover(optionButton, theme.elevated, theme.cardRaised, 0.12, 0.04)
            optionButtons[value] = optionButton

            window:_connect(optionButton.MouseButton1Click, function()
                if multiple then
                    if contains(selected, value) then
                        for index = #selected, 1, -1 do
                            if selected[index] == value then
                                table.remove(selected, index)
                            end
                        end
                    else
                        table.insert(selected, value)
                    end
                    redraw(true)
                else
                    selected = {value}
                    redraw(true)
                    setOpen(false)
                end
            end)
        end

        local totalHeight = (#options * 28) + math.max(0, #options - 1) * 2 + 8
        visibleHeight = math.min(math.max(totalHeight, 34), 160)
        list.CanvasSize = UDim2.fromOffset(0, totalHeight)
        list.ScrollBarThickness = totalHeight > visibleHeight and 2 or 0
        redraw(false)
    end

    function control:Set(value)
        local nextSelection = {}
        if type(value) == "table" then
            for _, entry in ipairs(value) do
                if contains(options, entry) then
                    table.insert(nextSelection, tostring(entry))
                end
            end
        elseif contains(options, value) then
            table.insert(nextSelection, tostring(value))
        end
        if #nextSelection == 0 then
            nextSelection = {options[1]}
        end
        if not multiple then
            nextSelection = {nextSelection[1]}
        end
        selected = nextSelection
        redraw(true)
    end

    function control:Get()
        return copyArray(selected)
    end

    function control:Refresh(newOptions, preferred)
        options = normalizeOptions(newOptions)
        if preferred ~= nil then
            if type(preferred) == "table" then
                selected = copyArray(preferred)
            else
                selected = {tostring(preferred)}
            end
        else
            local filtered = {}
            for _, value in ipairs(selected) do
                if contains(options, value) then
                    table.insert(filtered, value)
                end
            end
            selected = #filtered > 0 and filtered or {options[1]}
        end
        if not multiple and #selected > 1 then
            selected = {selected[1]}
        end
        rebuild()
    end

    function control:SetVisible(value)
        row.Visible = value == true
        row:SetAttribute("NovaBaseVisible", row.Visible)
    end

    window:_connect(button.MouseButton1Click, function()
        setOpen(not open)
    end)

    window:_connect(UserInputService.InputBegan, function(input)
        if not open then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local point = Vector2.new(input.Position.X, input.Position.Y)
        if not pointInside(button, point) and not pointInside(list, point) then
            setOpen(false)
        end
    end)

    window.DropdownClosers[row] = function()
        setOpen(false)
    end

    registerFlag(window, control, settings, copyArray(selected))
    rebuild()
    return window:_registerControl(control, row, settings.Name .. " " .. table.concat(options, " "), section, tab)
end

local function addInput(owner, settings)
    settings = type(settings) == "table" and settings or {Name = tostring(settings or "Input")}
    local parent, section, tab = controlHost(owner)
    local window = owner.Window
    local theme = window.Theme

    local row = create("Frame", {
        BackgroundColor3 = theme.surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 38),
    }, parent)
    corner(row, 4)
    stroke(row, theme.stroke, 0.56, 1)
    window:_bindHover(row, theme.surface, theme.elevated, 0, 0)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Text = tostring(settings.Name or "Input"),
        Font = Enum.Font.GothamMedium,
        TextColor3 = theme.text,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(0.43, -12, 1, 0),
    }, row)

    local box = create("TextBox", {
        BackgroundColor3 = theme.subtle,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.Gotham,
        PlaceholderColor3 = theme.muted,
        PlaceholderText = tostring(settings.PlaceholderText or "Enter value"),
        Text = tostring(settings.CurrentValue or ""),
        TextColor3 = theme.text,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0.43, 0, 0, 4),
        Size = UDim2.new(0.57, -8, 0, 30),
    }, row)
    corner(box, 4)
    local boxStroke = stroke(box, theme.stroke, 0.6, 1)
    padding(box, 8, 8, 0, 0)

    local control = {
        CurrentValue = tostring(settings.CurrentValue or ""),
    }

    local function commit(runCallback)
        control.CurrentValue = box.Text
        if control.Flag and control.Flag ~= "" then
            Library.Flags[control.Flag] = control.CurrentValue
            window:_scheduleSave()
        end
        if runCallback then
            call(settings.Callback, control.CurrentValue)
        end
        if settings.RemoveTextAfterFocusLost then
            box.Text = ""
        end
    end

    function control:Set(value)
        box.Text = tostring(value or "")
        control.CurrentValue = box.Text
        commit(true)
    end

    function control:Get()
        return control.CurrentValue
    end

    function control:SetVisible(value)
        row.Visible = value == true
        row:SetAttribute("NovaBaseVisible", row.Visible)
    end

    window:_connect(box.Focused, function()
        tween(boxStroke, 0.12, {Color = theme.accent, Transparency = 0.05, Thickness = 1.35})
    end)

    window:_connect(box.FocusLost, function(enterPressed)
        tween(boxStroke, 0.12, {Color = theme.stroke, Transparency = 0.6, Thickness = 1})
        if enterPressed or settings.FireOnFocusLost ~= false then
            commit(true)
        end
    end)

    registerFlag(window, control, settings, control.CurrentValue)
    return window:_registerControl(control, row, settings.Name, section, tab)
end

local function addKeybind(owner, settings)
    settings = type(settings) == "table" and settings or {Name = tostring(settings or "Keybind")}
    local parent, section, tab = controlHost(owner)
    local window = owner.Window
    local theme = window.Theme

    local row = create("Frame", {
        BackgroundColor3 = theme.surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 38),
    }, parent)
    corner(row, 4)
    stroke(row, theme.stroke, 0.56, 1)
    window:_bindHover(row, theme.surface, theme.elevated, 0, 0)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Text = tostring(settings.Name or "Keybind"),
        Font = Enum.Font.GothamMedium,
        TextColor3 = theme.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -110, 1, 0),
    }, row)

    local keyButton = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = theme.subtle,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Font = Enum.Font.Code,
        Text = keyCodeFrom(settings.CurrentKeybind).Name,
        TextColor3 = theme.text,
        TextSize = 11,
        Position = UDim2.new(1, -98, 0, 4),
        Size = UDim2.fromOffset(90, 30),
    }, row)
    corner(keyButton, 4)
    stroke(keyButton, theme.stroke, 0.6, 1)

    local control = {
        CurrentKeybind = keyCodeFrom(settings.CurrentKeybind),
        Listening = false,
    }

    local function redraw()
        keyButton.Text = control.Listening and "..." or control.CurrentKeybind.Name
        if control.Flag and control.Flag ~= "" then
            Library.Flags[control.Flag] = control.CurrentKeybind.Name
            window:_scheduleSave()
        end
    end

    function control:Set(value)
        control.CurrentKeybind = keyCodeFrom(value)
        redraw()
    end

    function control:Get()
        return control.CurrentKeybind
    end

    function control:SetVisible(value)
        row.Visible = value == true
        row:SetAttribute("NovaBaseVisible", row.Visible)
    end

    window:_connect(keyButton.MouseButton1Click, function()
        control.Listening = true
        redraw()
    end)

    window:_connect(UserInputService.InputBegan, function(input, processed)
        if control.Listening then
            if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
                control.CurrentKeybind = input.KeyCode
                control.Listening = false
                redraw()
            end
            return
        end
        if processed or input.KeyCode ~= control.CurrentKeybind then
            return
        end
        if settings.HoldToInteract then
            call(settings.Callback, true)
        else
            call(settings.Callback)
        end
    end)

    if settings.HoldToInteract then
        window:_connect(UserInputService.InputEnded, function(input)
            if input.KeyCode == control.CurrentKeybind then
                call(settings.Callback, false)
            end
        end)
    end

    registerFlag(window, control, settings, control.CurrentKeybind.Name)
    redraw()
    return window:_registerControl(control, row, settings.Name, section, tab)
end

local function addParagraph(owner, settings)
    settings = type(settings) == "table" and settings or {Title = tostring(settings or "Information"), Content = ""}
    local parent, section, tab = controlHost(owner)
    local window = owner.Window
    local theme = window.Theme

    local row = create("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = theme.surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
    }, parent)
    corner(row, 4)
    stroke(row, theme.stroke, 0.56, 1)
    padding(row, 11, 11, 9, 10)

    local layout = create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)

    local title = create("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = tostring(settings.Title or settings.Name or "Information"),
        TextColor3 = theme.text,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 0),
    }, row)

    local content = create("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = tostring(settings.Content or ""),
        TextColor3 = theme.muted,
        TextSize = 10,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Size = UDim2.new(1, 0, 0, 0),
    }, row)

    local control = {}

    function control:Set(values)
        if type(values) == "table" then
            if values.Title ~= nil then
                title.Text = tostring(values.Title)
            end
            if values.Content ~= nil then
                content.Text = tostring(values.Content)
            end
        else
            content.Text = tostring(values or "")
        end
    end

    function control:SetVisible(value)
        row.Visible = value == true
        row:SetAttribute("NovaBaseVisible", row.Visible)
    end

    local searchText = tostring(settings.Title or settings.Name or "") .. " " .. tostring(settings.Content or "")
    return window:_registerControl(control, row, searchText, section, tab)
end

local function addLabel(owner, text)
    local parent, section, tab = controlHost(owner)
    local window = owner.Window
    local theme = window.Theme

    local label = create("TextLabel", {
        BackgroundColor3 = theme.surface,
        BorderSizePixel = 0,
        Font = Enum.Font.Gotham,
        Text = tostring(type(text) == "table" and (text.Text or text.Name) or text or "Label"),
        TextColor3 = theme.muted,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 30),
    }, parent)
    corner(label, 4)
    stroke(label, theme.stroke, 0.65, 1)
    padding(label, 10, 10, 0, 0)

    local control = {}

    function control:Set(value)
        label.Text = tostring(value or "")
    end

    function control:SetVisible(value)
        label.Visible = value == true
        label:SetAttribute("NovaBaseVisible", label.Visible)
    end

    return window:_registerControl(control, label, label.Text, section, tab)
end

function Tab:CreateButton(settings)
    return addButton(self, settings)
end

function Tab:CreateToggle(settings)
    return addToggle(self, settings)
end

function Tab:CreateSlider(settings)
    return addSlider(self, settings)
end

function Tab:CreateDropdown(settings)
    return addDropdown(self, settings)
end

function Tab:CreateInput(settings)
    return addInput(self, settings)
end

function Tab:CreateKeybind(settings)
    return addKeybind(self, settings)
end

function Tab:CreateParagraph(settings)
    return addParagraph(self, settings)
end

function Tab:CreateLabel(text)
    return addLabel(self, text)
end

function Section:CreateButton(settings)
    return addButton(self, settings)
end

function Section:CreateToggle(settings)
    return addToggle(self, settings)
end

function Section:CreateSlider(settings)
    return addSlider(self, settings)
end

function Section:CreateDropdown(settings)
    return addDropdown(self, settings)
end

function Section:CreateInput(settings)
    return addInput(self, settings)
end

function Section:CreateKeybind(settings)
    return addKeybind(self, settings)
end

function Section:CreateParagraph(settings)
    return addParagraph(self, settings)
end

function Section:CreateLabel(text)
    return addLabel(self, text)
end

Tab.Button = Tab.CreateButton
Tab.Toggle = Tab.CreateToggle
Tab.Slider = Tab.CreateSlider
Tab.Dropdown = Tab.CreateDropdown
Tab.Input = Tab.CreateInput
Tab.Keybind = Tab.CreateKeybind
Tab.Paragraph = Tab.CreateParagraph
Tab.Label = Tab.CreateLabel

Section.Button = Section.CreateButton
Section.Toggle = Section.CreateToggle
Section.Slider = Section.CreateSlider
Section.Dropdown = Section.CreateDropdown
Section.Input = Section.CreateInput
Section.Keybind = Section.CreateKeybind
Section.Paragraph = Section.CreateParagraph
Section.Label = Section.CreateLabel

function Window:Notify(settings)
    return Library:Notify(settings, self)
end

function Window:Destroy()
    if self.Destroyed then
        return
    end
    self.Destroyed = true
    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(self.Connections)
    if self.Gui then
        self.Gui:Destroy()
    end
    for index = #Library.Windows, 1, -1 do
        if Library.Windows[index] == self then
            table.remove(Library.Windows, index)
        end
    end
    if Library.CurrentWindow == self then
        Library.CurrentWindow = Library.Windows[#Library.Windows]
    end
end

function Library:CreateWindow(settings)
    settings = type(settings) == "table" and settings or {Name = tostring(settings or "Nova.Labs")}

    local name = tostring(settings.Name or "Nova.Labs")
    local guiName = tostring(settings.GuiName or (name:gsub("[^%w]", "") .. "UI"))
    local badge = settings.Badge
    if badge == nil then
        badge = "UI"
    end

    destroyOld(guiName)

    local window = setmetatable({
        Name = name,
        Theme = self.Theme,
        Settings = {
            ShowUserPanel = settings.ShowUserPanel ~= false,
            Search = settings.Search ~= false,
        },
        ConfigSaving = type(settings.ConfigurationSaving) == "table" and {
            Enabled = settings.ConfigurationSaving.Enabled == true,
            FolderName = settings.ConfigurationSaving.FolderName or "NovaUI",
            FileName = settings.ConfigurationSaving.FileName or name:gsub("[^%w_]", ""),
        } or {
            Enabled = false,
            FolderName = "NovaUI",
            FileName = name:gsub("[^%w_]", ""),
        },
        Tabs = {},
        Sections = {},
        SearchEntries = {},
        DropdownClosers = {},
        FlagControls = {},
        Connections = {},
        SaveToken = 0,
        Destroyed = false,
        Minimized = false,
        Visible = true,
    }, Window)

    local gui = create("ScreenGui", {
        Name = guiName,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    parentGui(gui)
    window.Gui = gui

    local viewport = window:_viewport()
    local requestedSize = settings.Size
    local width = 720
    local height = 500
    if typeof(requestedSize) == "Vector2" then
        width = math.floor(requestedSize.X)
        height = math.floor(requestedSize.Y)
    elseif type(requestedSize) == "table" then
        width = tonumber(requestedSize[1] or requestedSize.X) or width
        height = tonumber(requestedSize[2] or requestedSize.Y) or height
    end

    local positionX = math.max(0, math.floor((viewport.X - width) * 0.5))
    local positionY = math.max(0, math.floor((viewport.Y - height) * 0.5))

    local shadow = create("Frame", {
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.62,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(positionX + 10, positionY + 12),
        Size = UDim2.fromOffset(width, height),
        ZIndex = 0,
    }, gui)
    corner(shadow, 9)
    window.Shadow = shadow

    local root = create("Frame", {
        BackgroundColor3 = window.Theme.background,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Position = UDim2.fromOffset(positionX, positionY),
        Size = UDim2.fromOffset(width, height),
        ZIndex = 2,
    }, gui)
    corner(root, 8)
    stroke(root, window.Theme.stroke, 0.18, 1)
    window.Root = root
    window.LastExpandedSize = root.Size

    local scale = create("UIScale", {Scale = 1}, root)
    window.Scale = scale

    local titleBar = create("Frame", {
        Active = true,
        BackgroundColor3 = window.Theme.surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 46),
    }, root)
    window.TitleBar = titleBar

    local brandMark = create("Frame", {
        BackgroundColor3 = window.Theme.subtle,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(12, 10),
        Size = UDim2.fromOffset(26, 26),
    }, titleBar)
    corner(brandMark, 3)
    stroke(brandMark, window.Theme.stroke, 0.38, 1)

    local brandLetter = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        Text = name:sub(1, 1):upper(),
        TextColor3 = window.Theme.text,
        TextSize = 16,
        Size = UDim2.fromScale(1, 1),
    }, brandMark)
    window.BrandLetter = brandLetter

    local titleLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        Text = name,
        TextColor3 = window.Theme.text,
        TextSize = 15,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(46, 0),
        Size = UDim2.fromOffset(98, 46),
    }, titleBar)
    window.TitleLabel = titleLabel

    local badgeLabel = create("TextLabel", {
        BackgroundColor3 = window.Theme.subtle,
        BorderSizePixel = 0,
        Font = Enum.Font.Code,
        Text = tostring(badge),
        TextColor3 = settings.BadgeColor or Color3.fromRGB(232, 232, 235),
        TextSize = 9,
        Position = UDim2.fromOffset(143, 14),
        Size = UDim2.fromOffset(38, 18),
        Visible = tostring(badge) ~= "",
    }, titleBar)
    corner(badgeLabel, 3)
    stroke(badgeLabel, window.Theme.stroke, 0.56, 1)
    window.BadgeLabel = badgeLabel

    local searchBox = create("TextBox", {
        BackgroundColor3 = window.Theme.background,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.Gotham,
        PlaceholderText = tostring(settings.SearchPlaceholder or "Search"),
        PlaceholderColor3 = window.Theme.muted,
        Text = "",
        TextColor3 = window.Theme.text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(1, -302, 0, 8),
        Size = UDim2.fromOffset(220, 30),
        Visible = window.Settings.Search,
        ZIndex = 25,
    }, titleBar)
    corner(searchBox, 4)
    local searchStroke = stroke(searchBox, window.Theme.stroke, 0.58, 1)
    padding(searchBox, 10, 10, 0, 0)
    window.SearchBox = searchBox

    local minimizeButton = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = window.Theme.subtle,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "–",
        TextColor3 = window.Theme.text,
        TextSize = 13,
        Position = UDim2.new(1, -68, 0, 10),
        Size = UDim2.fromOffset(26, 26),
    }, titleBar)
    corner(minimizeButton, 4)
    window.MinimizeButton = minimizeButton

    local closeButton = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = Color3.fromRGB(39, 18, 24),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "×",
        TextColor3 = window.Theme.bad,
        TextSize = 13,
        Position = UDim2.new(1, -36, 0, 10),
        Size = UDim2.fromOffset(26, 26),
    }, titleBar)
    corner(closeButton, 4)
    window.CloseButton = closeButton

    create("Frame", {
        BackgroundColor3 = window.Theme.stroke,
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
    }, titleBar)

    local body = create("CanvasGroup", {
        BackgroundTransparency = 1,
        GroupTransparency = 0,
        Position = UDim2.fromOffset(0, 46),
        Size = UDim2.new(1, 0, 1, -46),
    }, root)
    window.Body = body

    local navRail = create("Frame", {
        BackgroundColor3 = window.Theme.nav,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 148, 1, 0),
    }, body)
    window.NavRail = navRail

    create("Frame", {
        BackgroundColor3 = window.Theme.stroke,
        BackgroundTransparency = 0.28,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -1, 0, 10),
        Size = UDim2.new(0, 1, 1, -20),
    }, navRail)

    local tabStrip = create("ScrollingFrame", {
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 0,
        Position = UDim2.fromOffset(9, 12),
        Size = UDim2.new(1, -18, 1, -84),
    }, navRail)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, tabStrip)
    window.TabStrip = tabStrip

    local pageHost = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(160, 10),
        Size = UDim2.new(1, -170, 1, -20),
    }, body)
    window.PageHost = pageHost

    local resizeHandle = create("TextButton", {
        AnchorPoint = Vector2.new(1, 1),
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "⋰",
        TextColor3 = window.Theme.muted,
        TextSize = 15,
        Position = UDim2.new(1, -2, 1, -1),
        Size = UDim2.fromOffset(18, 18),
    }, root)
    window.ResizeHandle = resizeHandle

    local toastContainer = create("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -12, 1, -12),
        Size = UDim2.fromOffset(300, 430),
        ZIndex = 100,
    }, gui)
    create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
    }, toastContainer)
    window.ToastContainer = toastContainer

    window:_buildUserPanel()
    window:_makeDraggable(titleBar)
    window:_makeResizable(resizeHandle)
    window:_updateScale()

    window:_connect(root:GetPropertyChangedSignal("Position"), function()
        shadow.Position = root.Position + UDim2.fromOffset(10, 12)
    end)

    window:_connect(root:GetPropertyChangedSignal("Size"), function()
        shadow.Size = root.Size
    end)

    window:_connect(searchBox.Focused, function()
        tween(searchStroke, 0.12, {Color = window.Theme.accent, Transparency = 0.05, Thickness = 1.35})
    end)

    window:_connect(searchBox.FocusLost, function()
        tween(searchStroke, 0.12, {Color = window.Theme.stroke, Transparency = 0.58, Thickness = 1})
    end)

    window:_connect(searchBox:GetPropertyChangedSignal("Text"), function()
        window:_applySearch(searchBox.Text)
    end)

    window:_connect(minimizeButton.MouseButton1Click, function()
        window:Minimize()
    end)

    window:_connect(closeButton.MouseButton1Click, function()
        window:Destroy()
    end)

    local toggleKey = keyCodeFrom(settings.ToggleKey or "RightShift")
    window:_connect(UserInputService.InputBegan, function(input, processed)
        if not processed and input.KeyCode == toggleKey then
            window:Toggle()
        end
    end)

    window:_connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
        task.wait()
        window:_updateScale()
    end)

    task.spawn(function()
        while not window.Destroyed do
            local camera = Workspace.CurrentCamera
            if camera then
                local last = camera.ViewportSize
                repeat
                    task.wait(0.25)
                    if window.Destroyed or Workspace.CurrentCamera ~= camera then
                        break
                    end
                    if camera.ViewportSize ~= last then
                        last = camera.ViewportSize
                        window:_updateScale()
                    end
                until window.Destroyed or Workspace.CurrentCamera ~= camera
            else
                task.wait(0.25)
            end
        end
    end)

    root.Visible = true
    shadow.Visible = true
    root.BackgroundTransparency = 1
    shadow.BackgroundTransparency = 1
    root.Position = root.Position + UDim2.fromOffset(0, 8)
    tween(root, 0.24, {
        BackgroundTransparency = 0.04,
        Position = UDim2.fromOffset(positionX, positionY),
    }, Enum.EasingStyle.Quart)
    tween(shadow, 0.24, {BackgroundTransparency = 0.62})

    table.insert(self.Windows, window)
    self.CurrentWindow = window

    if settings.AutoLoadConfiguration == true then
        task.defer(function()
            window:LoadConfiguration()
        end)
    end

    return window
end

function Library:Notify(settings, window)
    settings = type(settings) == "table" and settings or {Title = "Nova", Content = tostring(settings or "")}
    window = window or self.CurrentWindow
    if not window or not window.ToastContainer or not window.ToastContainer.Parent then
        return
    end

    local titleText = tostring(settings.Title or "Notification")
    local contentText = tostring(settings.Content or settings.Text or "")
    local duration = tonumber(settings.Duration) or 4
    local status = tostring(settings.Status or "Default")
    local theme = window.Theme
    local statusColor = status == "Success" and theme.good or status == "Warning" and theme.warn or status == "Error" and theme.bad or theme.accent

    local toast = create("Frame", {
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Size = UDim2.new(1, 0, 0, 72),
        ZIndex = 110,
    }, window.ToastContainer)
    corner(toast, 6)
    stroke(toast, theme.stroke, 0.38, 1)

    create("Frame", {
        BackgroundColor3 = statusColor,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(2, 72),
        ZIndex = 111,
    }, toast)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = titleText,
        TextColor3 = theme.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(12, 9),
        Size = UDim2.new(1, -24, 0, 18),
        ZIndex = 111,
    }, toast)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = contentText,
        TextColor3 = theme.muted,
        TextSize = 10,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.fromOffset(12, 29),
        Size = UDim2.new(1, -24, 0, 32),
        ZIndex = 111,
    }, toast)

    local scale = create("UIScale", {Scale = 0.96}, toast)
    toast.BackgroundTransparency = 1
    tween(scale, 0.18, {Scale = 1}, Enum.EasingStyle.Back)
    tween(toast, 0.18, {BackgroundTransparency = 0.04})

    task.delay(duration, function()
        if not toast.Parent then
            return
        end
        tween(scale, 0.16, {Scale = 0.96})
        tween(toast, 0.16, {BackgroundTransparency = 1})
        task.wait(0.17)
        if toast.Parent then
            toast:Destroy()
        end
    end)
end

function Library:SaveConfiguration()
    if self.CurrentWindow then
        return self.CurrentWindow:SaveConfiguration()
    end
    return false
end

function Library:LoadConfiguration()
    if self.CurrentWindow then
        return self.CurrentWindow:LoadConfiguration()
    end
    return false
end

function Library:Destroy()
    local windows = copyArray(self.Windows)
    for _, window in ipairs(windows) do
        window:Destroy()
    end
    table.clear(self.Flags)
end

return Library