local Nova = loadstring(game:HttpGet("https://raw.githubusercontent.com/dukermcmillen12-gif/NovaUI/main/NovaUI.lua"))()

local Window = Nova:CreateWindow({
    Name = "Nova.Labs",
    Badge = "PAID",
    Search = true,
    ShowUserPanel = true,
    ToggleKey = "RightShift",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NovaUI",
        FileName = "Example",
    },
})

local Combat = Window:CreateTab("Combat", "✦", "Fight, target and reach")
local Main = Combat:CreateSection("Main", "Primary controls")

Main:CreateToggle({
    Name = "Enabled",
    CurrentValue = false,
    Flag = "Enabled",
    Callback = function(Value)
        print(Value)
    end,
})

Main:CreateSlider({
    Name = "Power",
    Range = {0, 100},
    Increment = 1,
    Suffix = "%",
    CurrentValue = 50,
    Flag = "Power",
    Callback = function(Value)
        print(Value)
    end,
})

Main:CreateDropdown({
    Name = "Mode",
    Options = {"Safe", "Smart", "Aggressive"},
    CurrentOption = {"Smart"},
    MultipleOptions = false,
    Flag = "Mode",
    Callback = function(Options)
        print(Options[1])
    end,
})

Main:CreateButton({
    Name = "Run Action",
    Callback = function()
        Nova:Notify({
            Title = "Nova.Labs",
            Content = "Button pressed",
            Duration = 3,
            Status = "Success",
        })
    end,
})

local Settings = Window:CreateTab("Settings", "⚙", "Interface and account settings")
Settings:CreateSection("Interface")

Settings:CreateInput({
    Name = "Display Name",
    PlaceholderText = "Enter text",
    CurrentValue = "Nova",
    Flag = "DisplayName",
    Callback = function(Text)
        print(Text)
    end,
})

Settings:CreateKeybind({
    Name = "Action Key",
    CurrentKeybind = "F",
    Flag = "ActionKey",
    Callback = function()
        print("Pressed")
    end,
})

Settings:CreateParagraph({
    Title = "Library",
    Content = "The UI is completely separate from the game logic and can be reused by any script.",
})

Nova:LoadConfiguration()