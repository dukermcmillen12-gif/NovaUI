# Nova UI

Nova UI is the standalone interface layer extracted from the Nova.Labs Premium script and rebuilt as a reusable open-source Roblox Lua UI library.

## Load

```lua
local Nova = loadstring(game:HttpGet("https://raw.githubusercontent.com/dukermcmillen12-gif/NovaUI/main/NovaUI.lua"))()
```

## Window

```lua
local Window = Nova:CreateWindow({
    Name = "Nova.Labs",
    Badge = "PAID",
    Search = true,
    ShowUserPanel = true,
    ToggleKey = "RightShift",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NovaUI",
        FileName = "MyHub",
    },
})
```

## Tabs and sections

```lua
local Combat = Window:CreateTab("Combat", "✦", "Fight, target and reach")
local Main = Combat:CreateSection("Main", "Primary controls")
```

You can create controls on either the tab or the returned section.

## Button

```lua
Main:CreateButton({
    Name = "Run Action",
    Callback = function()
        print("clicked")
    end,
})
```

## Toggle

```lua
local Toggle = Main:CreateToggle({
    Name = "Enabled",
    CurrentValue = false,
    Flag = "Enabled",
    Callback = function(Value)
        print(Value)
    end,
})

Toggle:Set(true)
```

## Slider

```lua
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
```

## Dropdown

```lua
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
```

## Input

```lua
Main:CreateInput({
    Name = "Name",
    PlaceholderText = "Enter text",
    CurrentValue = "Nova",
    Flag = "Name",
    Callback = function(Text)
        print(Text)
    end,
})
```

## Keybind

```lua
Main:CreateKeybind({
    Name = "Action Key",
    CurrentKeybind = "F",
    Flag = "ActionKey",
    Callback = function()
        print("pressed")
    end,
})
```

## Paragraph and label

```lua
Main:CreateParagraph({
    Title = "Information",
    Content = "Reusable information card"
})

Main:CreateLabel("Small label")
```

## Notifications

```lua
Nova:Notify({
    Title = "Nova.Labs",
    Content = "Loaded successfully",
    Duration = 4,
    Status = "Success",
})
```

`Status` can be `Default`, `Success`, `Warning`, or `Error`.

## Flags

```lua
print(Nova.Flags.Enabled)
print(Nova.Flags.Power)
```

## Configuration

```lua
Nova:SaveConfiguration()
Nova:LoadConfiguration()
```

Configuration saving automatically uses executor file APIs when they are available.

## Short aliases

The longer Rayfield-style names and shorter names both work.

```lua
Combat:Button({Name = "Button", Callback = function() end})
Combat:Toggle({Name = "Toggle", CurrentValue = false, Callback = function(Value) end})
Combat:Slider({Name = "Slider", Range = {0, 10}, CurrentValue = 5, Callback = function(Value) end})
```

## Publish

1. Create a public GitHub repository.
2. Upload `NovaUI.lua` to the root of the repository.
3. Open the file on GitHub and choose `Raw`.
4. Copy the raw URL.
5. Replace the placeholder URL in `NovaUI_Loadstring.lua` and `NovaUI_Example.lua`.

The result is the same one-line load pattern used by libraries such as Rayfield, while the source remains readable and open.