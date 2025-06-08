-- Oper_Osc.lua
-- Module: single-operator Osc controls (shape, type, freq, fine)
-- Usage: Oper_Osc{ vb=vb, op_index=N, parameters_mod4=plist, get_param_min=fn, get_param_max=fn }

return function(args)
  local vb          = args.vb
  local op          = args.op_index              -- 1..6
  local flat        = args.parameters_mod4       -- list of 24 params
  local get_min     = args.get_param_min
  local get_max     = args.get_param_max
  local midi_out    = rawget(_G, "shared_midi_out")

  -- map only this operator’s 4 NRPN params
  local map = {
    shape = flat[      op],
    ftype = flat[6   + op],
    freq  = flat[12  + op],
    fine  = flat[18  + op],
  }

  -- persistent state across calls
  local state = rawget(_G, "osc_state") or { values = {}, bound_ops = {} }
  rawset(_G, "osc_state", state)

  -- initialize defaults
  if not state.values[op] then
    state.values[op] = {
      shape = 1,
      ftype = 1,
      freq  = (get_min(map.freq)),
      fine  = (get_min(map.fine) + get_max(map.fine)) / 2,
    }
  end

  -- helper to send NRPN
  local function send(param, ui)
    if not midi_out then return end
    local raw = param.show_decimal
             and math.floor(ui*100+0.5)
             or math.floor(ui+0.5)
    local cc6, cc38 = math.floor(raw/128), raw%128
    local ch = (_G.global_midi_out_channel or 1) - 1
    midi_out:send({0xB0+ch,99,param.msb})
    midi_out:send({0xB0+ch,98,param.lsb})
    midi_out:send({0xB0+ch, 6, cc6})
    midi_out:send({0xB0+ch,38,cc38})
  end

  -- bind receive once per-operator
  if _G.dispatcher then
    _G.dispatcher:bind("nrpn_received", function(msb, lsb, raw)
      -- shape?
      if     msb==map.shape.msb and lsb==map.shape.lsb then
        local v = raw+1
        state.values[op].shape = v
        vb.views["osc_shape_"..op].value = v
        return
      -- type?
      elseif msb==map.ftype.msb and lsb==map.ftype.lsb then
        local v = raw+1
        state.values[op].ftype = v
        vb.views["osc_ftype_"..op].value = v
        return
      -- freq?
      elseif msb==map.freq.msb and lsb==map.freq.lsb then
        local v = raw/100
        state.values[op].freq = v
        vb.views["osc_freq_"..op].value = v
        vb.views["osc_freq_box_"..op].value = v
        vb.views["osc_freq_label_"..op].text = string.format("%.2f",v)
        return
      -- fine?
      elseif msb==map.fine.msb and lsb==map.fine.lsb then
        local v = raw/100
        state.values[op].fine = v
        vb.views["osc_fine_"..op].value = v
        vb.views["osc_fine_box_"..op].value = v
        vb.views["osc_fine_label_"..op].text = string.format("%.2f",v)
        return
      end
    end)
  end

  -- build this operator’s UI
  local vals = state.values[op]
  return vb:column{
    margin = 6, spacing = 8,
    vb:text{ text = "Operator "..op, font = "bold" },

    -- Shape
    vb:row{
      vb:text{ text="Shape:" },
      vb:popup{
        id       = "osc_shape_"..op,
        width = 60,
        items    = {"sin","saw","squa","s^2","sine0","sine+","rand","off","usr1","usr2","usr3","usr4","usr5","usr6"},
        value    = vals.shape,
        notifier = function(v)
          vals.shape = v
          send(map.shape, v-1)
        end
      }
    },

    -- Freq Type
    vb:row{
      vb:text{ text="Type:" },
      vb:popup{
        id       = "osc_ftype_"..op,
        width = 68,
        items    = {"keyb","fixed","kehz"},
        value    = vals.ftype,
        notifier = function(v)
          vals.ftype = v
          send(map.ftype, v-1)
        end
      }
    },

    -- Frequency
    vb:row{
      vb:text{ text="Freq:" },
      vb:slider{
        id       = "osc_freq_"..op,
        width = 100,
        min      = get_min(map.freq),
        max      = get_max(map.freq),
        value    = vals.freq,
        notifier = function(v)
          vals.freq = v
          vb.views["osc_freq_box_"..op].value = v
          vb.views["osc_freq_label_"..op].text = string.format("%.2f",v)
          send(map.freq, v)
        end
      },
      vb:valuebox{
        id       = "osc_freq_box_"..op,
        min      = get_min(map.freq),
        max      = get_max(map.freq),
        value    = vals.freq,
        notifier = function(v)
          vals.freq = v
          vb.views["osc_freq_"..op].value = v
          vb.views["osc_freq_label_"..op].text = string.format("%.2f",v)
          send(map.freq, v)
        end
      },
      vb:text{ 
        id   = "osc_freq_label_"..op,
        width = 40,
        text = string.format("%.2f", vals.freq)
      }
    },

    -- Fine Tune
    vb:row{
      vb:text{ text="Fine:" },
      vb:slider{
        id       = "osc_fine_"..op,
        width = 100,
        min      = get_min(map.fine),
        max      = get_max(map.fine),
        value    = vals.fine,
        notifier = function(v)
          vals.fine = v
          vb.views["osc_fine_box_"..op].value = v
          local display_value = v - 9
          vb.views["osc_fine_label_"..op].text = string.format("%.2f",display_value)
          send(map.fine, v)
        end
      },
      vb:valuebox{
        id       = "osc_fine_box_"..op,
        min      = get_min(map.fine),
        max      = get_max(map.fine),
        value    = vals.fine,
        notifier = function(v)
          vals.fine = v
          vb.views["osc_fine_"..op].value = v
          local display_value = v - 9
          vb.views["osc_fine_label_"..op].text = string.format("%.2f",display_value)
          send(map.fine, v)
        end
      },
      vb:text{
        id   = "osc_fine_label_"..op, width = 40,
        text = string.format("%.2f", vals.fine -9)
      }
    },
  }
end
