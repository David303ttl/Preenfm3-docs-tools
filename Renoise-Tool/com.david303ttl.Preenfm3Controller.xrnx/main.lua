-- main.lua
-- Orchestrates shared MIDI in/out and lays out modules.

--[[Simple controller for Preenfm3. My first tool.
Since it is a Renoise tool and not an effect or instrument, there are some limitations.
  
  What works:
- Receives and sends values on the specified faders and buttons.
- Pull all parameters from the device.
- Operators and their envelopes in one place.

  
  What's missing:
- I left out the 'FX' and 'Mod Matrix' section. 
- 'Modulators' section, especially LFO Frequency is troublesome and can crash the hardware.
  
  Features:
- NRPN Receiver - select the input and output channel and click 'Start Receive', then 'Pull All parameters' to get all NRPN values.
- 'All notes off' and 'Reset' buttons. Sometimes they are useful.
- Sliders: User CC1-4 (midi CC 34-37) and Performance 1-4 (midi CC 115-118). 
Unfortunately, due to the fact that this is a tool, it is not possible to modulate these sliders from the effects level (That's why
I made jsfx effect to modulate these sliders, but it is not included in this tool. It works fine with ysfx in Renoise).
So it is more convenient to use 'Instrument MIDI Control' or 'Doofer' and to them internally assign midiCC 34-37 and 115-118.

- The 'FM Engine' section - Velocity/Glide sends after clicking the 'Send' button.
- Values update when you move the encoder:]]

local dialog = nil
local this_tool = renoise.tool()

-- Initialize global dispatcher
if not rawget(_G, "dispatcher") then
  rawset(_G, "dispatcher", {})
  function _G.dispatcher:dispatch(event, ...)
    if self[event] then for _,fn in ipairs(self[event]) do fn(...) end end
  end
  function _G.dispatcher:bind(event, fn)
    self[event] = self[event] or {}
    table.insert(self[event], fn)
  end
end

-- Function to initialize shared MIDI-out (called when needed, not at startup)
local function init_shared_midi_out()
  if rawget(_G, "shared_midi_out") then
    return true -- Already initialized
  end
  
  local devs = renoise.Midi.available_output_devices()
  if #devs > 0 then
    local success, midi_out = pcall(function()
      return renoise.Midi.create_output_device(devs[1])
    end)
    
    if success and midi_out then
      rawset(_G, "shared_midi_out", midi_out)
      renoise.app():show_status("MIDI output initialized: " .. devs[1])
      return true
    else
      renoise.app():show_status("Failed to initialize MIDI output!")
      return false
    end
  else
    renoise.app():show_status("No MIDI outputs found!")
    return false
  end
end

-- Global setter for MIDI-out channel
function _G.set_global_midi_out_channel(new_channel)
  rawset(_G, "global_midi_out_channel", new_channel)
  if this_tool.preferences and this_tool.preferences.write then
    this_tool.preferences:write("global_midi_out_channel", new_channel)
  end
  renoise.app():show_status(string.format("Global MIDI Out Channel set to: %d", new_channel))
end

-- Load all modules
local parameters    = require("nrpn_parameters")
local FM_Engine     = require("FM_Engine")
local FM_Mix        = require("FM_Mix")
local FM_IM         = require("FM_IM")
local Oper_Osc      = require("Oper_Osc")
local Oper_Env      = require("Oper_Env")
local Utils         = require("Utils")
local NRPN_Receiver = require("NRPN_Receiver")

-- Helper functions for parameter ranges
local function get_param_min(idx, plist)
  local p = type(idx)=="table" and idx or (plist or parameters)[idx]
  return p.show_decimal and 0 or (p.gui_min or 0)
end
local function get_param_max(idx, plist)
  local p = type(idx)=="table" and idx or (plist or parameters)[idx]
  return p.show_decimal and (p.max/100) or (p.gui_max or p.max)
end
local function find_param(name)
  for _,p in ipairs(parameters) do
    if p.name == name then return p end
  end
end

-- Define parameter groups *before* we build the UI
local parameters_mod1 = {
  parameters[1], parameters[2], parameters[3], parameters[4]
}
local parameters_mod2 = {
  find_param("Mix1"), find_param("Mix2"), find_param("Mix3"), find_param("Mix4"),
  find_param("Mix5"), find_param("Mix6"),
  find_param("Pan1"), find_param("Pan2"), find_param("Pan3"),
  find_param("Pan4"), find_param("Pan5"), find_param("Pan6"),
}
local parameters_mod3 = {
  parameters[5], parameters[6], parameters[7], parameters[8],
  parameters[9], parameters[10], parameters[11], parameters[12],
  parameters[13], parameters[14], parameters[15], parameters[16],
}
local parameters_mod4 = {
  find_param("Op1 Shape"), find_param("Op2 Shape"), find_param("Op3 Shape"),
  find_param("Op4 Shape"), find_param("Op5 Shape"), find_param("Op6 Shape"),
  find_param("Op1 Freq Type"), find_param("Op2 Freq Type"), find_param("Op3 Freq Type"),
  find_param("Op4 Freq Type"), find_param("Op5 Freq Type"), find_param("Op6 Freq Type"),
  find_param("Op1 Frequency"), find_param("Op2 Frequency"), find_param("Op3 Frequency"),
  find_param("Op4 Frequency"), find_param("Op5 Frequency"), find_param("Op6 Frequency"),
  find_param("Op1 Fine Tune"), find_param("Op2 Fine Tune"), find_param("Op3 Fine Tune"),
  find_param("Op4 Fine Tune"), find_param("Op5 Fine Tune"), find_param("Op6 Fine Tune"),
}
local parameters_mod5 = {}  -- envelopes are handled per-operator 

-- Main menu entry
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Preenfm3 Controller",
  invoke = function()
    -- Initialize MIDI connections ONLY when dialog opens
    if not init_shared_midi_out() then
      -- Show error but continue - user might want to try again
      renoise.app():show_error("Failed to initialize MIDI output. Check your MIDI setup and try again.")
    end
    
    -- load saved channel preference
    if not rawget(_G, "global_midi_out_channel") then
      local saved = (this_tool.preferences and this_tool.preferences.read)
                  and this_tool.preferences:read("global_midi_out_channel")
      rawset(_G, "global_midi_out_channel", saved or 1)
    end

    -- build the UI
    local vb = renoise.ViewBuilder()
    if dialog and dialog.visible then
      dialog:close()
      dialog = nil
    end

    dialog = renoise.app():show_custom_dialog(
      "Preenfm3 Controller",
      vb:column{
        margin = 6,
        spacing = 0,
        vb:row{
          spacing = 0,
          vb:column{
            width = 200,
            spacing = 12,
            vb:text{ text="Utils + Mix/Pan", font="bold" },
            NRPN_Receiver{ vb=vb },
            Utils{ vb=vb },
            FM_Mix{ vb=vb,
                    parameters_mod2 = parameters_mod2,
                    get_param_min   = get_param_min,
                    get_param_max   = get_param_max },
          },
          -- Col 2: Engine + IM
          vb:space{ width = 6 },
          vb:column{
            width = 260,
            spacing = 12,
            vb:text{ text="FM Engine", font="bold" },
            FM_Engine{ vb=vb,
                       parameters_mod1 = parameters_mod1,
                       get_param_min   = get_param_min,
                       get_param_max   = get_param_max },
            FM_IM{ vb=vb,
                   parameters_mod3 = parameters_mod3,
                   get_param_min   = get_param_min,
                   get_param_max   = get_param_max },
          },
          -- Col 3: Six independent operators
          vb:space{ width = 6 },
          vb:column{
            spacing =12,
            vb:text{ text="Operators", font="bold" },
            -- first row: Op 1–3
            vb:row{
              spacing = 6,
              Oper_Osc{ vb=vb, op_index=1,
                        parameters_mod4 = parameters_mod4,
                        get_param_min   = get_param_min,
                        get_param_max   = get_param_max },
              Oper_Osc{ vb=vb, op_index=2,
                        parameters_mod4 = parameters_mod4,
                        get_param_min   = get_param_min,
                        get_param_max   = get_param_max },
              Oper_Osc{ vb=vb, op_index=3,
                        parameters_mod4 = parameters_mod4,
                        get_param_min   = get_param_min,
                        get_param_max   = get_param_max },
            },
            vb:row{
              spacing = 24,
              Oper_Env{ vb=vb, op_index=1,
                        get_param_min   = get_param_min,
                        get_param_max   = get_param_max },
              Oper_Env{ vb=vb, op_index=2,
                        get_param_min   = get_param_min,
                        get_param_max   = get_param_max },
              Oper_Env{ vb=vb, op_index=3,
                        get_param_min   = get_param_min,
                        get_param_max   = get_param_max },
            },
            -- second row: Op 4–6
            vb:row{
              spacing = 6,
              Oper_Osc{ vb=vb, op_index=4,
                        parameters_mod4 = parameters_mod4,
                        get_param_min   = get_param_min,
                        get_param_max   = get_param_max },
              Oper_Osc{ vb=vb, op_index=5,
                        parameters_mod4 = parameters_mod4,
                        get_param_min   = get_param_min,
                        get_param_max   = get_param_max },
              Oper_Osc{ vb=vb, op_index=6,
                        parameters_mod4 = parameters_mod4,
                        get_param_min   = get_param_min,
                        get_param_max   = get_param_max },
            },
            vb:row{
              spacing = 24,
              Oper_Env{ vb=vb, op_index=4,
                        get_param_min   = get_param_min,
                        get_param_max   = get_param_max },
              Oper_Env{ vb=vb, op_index=5,
                        get_param_min   = get_param_min,
                        get_param_max   = get_param_max },
              Oper_Env{ vb=vb, op_index=6,
                        get_param_min   = get_param_min,
                        get_param_max   = get_param_max },
            },
          },
        } 
      }
    )
  end
}

-- Optional: Clean up MIDI connections when tool is unloaded
if this_tool.app_release_document_observable then
  this_tool.app_release_document_observable:add_notifier(function()
    -- Clean up MIDI connections
    local midi_out = rawget(_G, "shared_midi_out")
    if midi_out then
      pcall(function() midi_out:close() end)
      rawset(_G, "shared_midi_out", nil)
    end
    
    local midi_in = rawget(_G, "shared_midi_in")
    if midi_in then
      pcall(function() 
        if midi_in.is_open then
          midi_in:close() 
        end
      end)
      rawset(_G, "shared_midi_in", nil)
    end
  end)
end
