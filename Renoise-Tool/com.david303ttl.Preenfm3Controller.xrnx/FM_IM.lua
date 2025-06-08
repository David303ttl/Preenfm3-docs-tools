-- FM_IM.lua
-- Module for controlling IM and IM Velocity parameters 

return function(args)
  local vb            = args.vb
  local parameters    = args.parameters_mod3
  local get_param_min = args.get_param_min
  local get_param_max = args.get_param_max

  local midi_out = rawget(_G, "shared_midi_out")

  -- Persisted module state 
  local state = rawget(_G, "im_state") or {
    mode_idx = 1,    
    values   = {},   
  }
  rawset(_G, "im_state", state)

  -- Helper: send NRPN
  local function send_nrpn(param, ui_val)
    if not midi_out then return end
    local raw = param.show_decimal and math.floor(ui_val * 100 + 0.5) or math.floor(ui_val + 0.5)
    if param.midi_offset then raw = raw + param.midi_offset end
    local cc6  = math.floor(raw / 128)
    local cc38 = raw % 128
    
    -- _G.global_midi_out_channel 
    local target_channel_0_15 = _G.global_midi_out_channel - 1

    midi_out:send({0xB0 + target_channel_0_15, 99, param.msb})
    midi_out:send({0xB0 + target_channel_0_15, 98, param.lsb})
    midi_out:send({0xB0 + target_channel_0_15, 6,  cc6})
    midi_out:send({0xB0 + target_channel_0_15, 38, cc38})
  end

  -- Bind to NRPN receive events to update UI
  if _G.dispatcher then
    _G.dispatcher:bind("nrpn_received", function(msb, lsb, raw)
      for i, p in ipairs(parameters) do
        if p.msb == msb and p.lsb == lsb then
          local ui_val = p.show_decimal and (raw / 100) or raw
          local minv, maxv = get_param_min(p), get_param_max(p)
          ui_val = math.max(minv, math.min(maxv, ui_val))
          local slider = vb.views["im_sl"..i]
          local box    = vb.views["im_box"..i]
          local lbl    = vb.views["im_lbl"..i]
          if slider then slider.value = ui_val end
          if box    then box.value    = ui_val end
          if lbl    then lbl.text     = p.show_decimal and string.format("%.2f", ui_val) or tostring(ui_val) end
          state.values[i] = ui_val
          break
        end
      end
    end)
  end

  local rows = {}
  -- Sliders and boxes for each parameter
  for i, p in ipairs(parameters) do
    local minv, maxv = get_param_min(p), get_param_max(p)
    rows[#rows+1] = vb:row{
      vb:text{ text = p.name },
      vb:slider{
        id = "im_sl"..i,
        width = 100,
        min = minv, max = maxv,
        value = state.values[i] or minv,
        notifier = function(v)
          state.values[i] = v
          local box = vb.views["im_box"..i]
          local lbl = vb.views["im_lbl"..i]
          if box then box.value = v end
          if lbl then lbl.text = p.show_decimal and string.format("%.2f", v) or tostring(v) end
          send_nrpn(p, v)
        end
      },
      vb:valuebox{
        id = "im_box"..i,
        min = minv, max = maxv,
        value = state.values[i] or minv,
        notifier = function(v)
          state.values[i] = v
          local slider = vb.views["im_sl"..i]
          local lbl    = vb.views["im_lbl"..i]
          if slider then slider.value = v end
          if lbl    then lbl.text    = p.show_decimal and string.format("%.2f", v) or tostring(v) end
          send_nrpn(p, v)
        end
      },
      vb:text{
        id = "im_lbl"..i, width = 40,
        text = p.show_decimal and string.format("%.2f", state.values[i] or minv) or tostring(state.values[i] or minv)
      }
    }
  end

  return vb:column{ margin = 12, spacing = 8, unpack(rows) }
end
