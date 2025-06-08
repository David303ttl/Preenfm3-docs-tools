-- FM_Engine.lua
-- Module: Engine parameters with Algorithm quick-buttons, Mode buttons,
-- and parameter slider/valuebox, using shared MIDI output from main.lua

return function(args)
  -- Ensure unpack is defined for this Lua version
  local unpack = table.unpack or unpack
  local vb           = args.vb
  local parameters   = args.parameters_mod1
  local get_param_min = args.get_param_min
  local get_param_max = args.get_param_max

  -- Shared MIDI output provided by main.lua
  local midi_out = rawget(_G, "shared_midi_out")

  local state = rawget(_G, "engine_state") or { selected_param_idx = 2, display_value = nil }
  rawset(_G, "engine_state", state)

  -- Override ranges for Algorithm Number UI
  local function gui_min(idx)
    return parameters[idx].name == "Algorithm Number" and 1 or get_param_min(idx, parameters)
  end
  local function gui_max(idx)
    if parameters[idx].name == "Algorithm Number" then
      return parameters[idx].max + 1
    end
    return get_param_max(idx, parameters)
  end

  if state.display_value == nil then
    state.display_value = gui_min(state.selected_param_idx)
  end

  -- NRPN send helper
  local function send_nrpn(param, ui_val) 
    local raw = (param.name == "Algorithm Number") and (ui_val - 1) or ui_val
    local cc6  = math.floor(raw / 128)
    local cc38 = raw % 128
    if midi_out then 
      local target_channel_0_15 = _G.global_midi_out_channel - 1 

      midi_out:send({0xB0 + target_channel_0_15, 99, param.msb})
      midi_out:send({0xB0 + target_channel_0_15, 98, param.lsb})
      midi_out:send({0xB0 + target_channel_0_15, 6,  cc6})
      midi_out:send({0xB0 + target_channel_0_15, 38, cc38})
    else
      renoise.app():show_status("MIDI Output Device not selected!")
    end
  end

  local rows = {}

  -- Algorithm buttons grid
  table.insert(rows, vb:text{ text = "Select Algorithm:" })
  for r = 0, 3 do
    local cols = {}
    for c = 1, 8 do
      local idx = r * 8 + c
      cols[#cols+1] = vb:button{
        text     = tostring(idx),
        width    = 30,
        notifier = function() send_nrpn(parameters[1], idx) end
      }
    end
    table.insert(rows, vb:row{ unpack(cols) })
  end

  -- Mode quick-buttons
  table.insert(rows, vb:row{
    vb:text { text = "Mode:" },
    vb:button{ text = "Mono", notifier = function() send_nrpn(parameters[3], 0) end },
    vb:button{ text = "Poly", notifier = function() send_nrpn(parameters[3], 1) end },
    vb:button{ text = "Unison", notifier = function() send_nrpn(parameters[3], 2) end }
  })

  -- Popup for other parameters
  local names = {}
  for i, p in ipairs(parameters) do
    if i ~= 1 and i ~= 3 then names[#names+1] = p.name end
  end
  table.insert(rows, vb:row{
    vb:text { text = "Parameter:" },
    vb:popup{
      id    = "engine_param",
      items = names,
      value = 1, 
      notifier = function(v)
        state.selected_param_idx = (v < 2) and v + 1 or v + 2
        state.display_value = math.max(gui_min(state.selected_param_idx), math.min(state.display_value, gui_max(state.selected_param_idx)))
        vb.views.eng_slider.min = gui_min(state.selected_param_idx)
        vb.views.eng_slider.max = gui_max(state.selected_param_idx)
        vb.views.eng_slider.value = state.display_value
        vb.views.eng_box.min = gui_min(state.selected_param_idx)
        vb.views.eng_box.max = gui_max(state.selected_param_idx)
        vb.views.eng_box.value = state.display_value
      end
    }
  })

  -- Value slider + box
  table.insert(rows, vb:row{
    vb:text { text = "Value:" },
    vb:slider{
      id    = "eng_slider",
      width = 100,
      min   = gui_min(state.selected_param_idx),
      max   = gui_max(state.selected_param_idx),
      value = state.display_value,
      notifier = function(v) state.display_value = math.floor(v + 0.5); vb.views.eng_box.value = state.display_value end
    },
    vb:valuebox{
      id    = "eng_box",
      min   = gui_min(state.selected_param_idx),
      max   = gui_max(state.selected_param_idx),
      value = state.display_value,
      notifier = function(v) state.display_value = math.floor(v + 0.5); vb.views.eng_slider.value = state.display_value end
    }
  })
  -- Send current parameter
  table.insert(rows, vb:row{
    vb:button{ text = "Send", notifier = function() send_nrpn(parameters[state.selected_param_idx], state.display_value) end } 
  })

  -- Build final column
  return vb:column{ margin = 12, spacing = 8, unpack(rows) }
end
