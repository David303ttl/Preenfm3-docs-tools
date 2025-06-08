-- Oper_Env.lua
-- Module: single-operator ADSR + Level controls

return function(args)
  local vb       = args.vb
  local op       = args.op_index           -- 1..6
  local get_min  = args.get_param_min
  local get_max  = args.get_param_max
  local midi_out = rawget(_G, "shared_midi_out")

  -- ADSR descriptors
  local adsr = {
    { key="attack", lsb={68,76,84,92,100,108}, max=16.00, show_decimal=true,  label="A" },
    { key="decay",  lsb={70,78,86,94,102,110}, max=16.00, show_decimal=true,  label="D" },
    { key="sustain",lsb={72,80,88,96,104,112}, max=16.00, show_decimal=true,  label="S" },
    { key="release",lsb={74,82,90,98,106,114}, max=16.00, show_decimal=true,  label="R" },
  }
  -- Level descriptors
  local levels = {
    { key="attack_level", lsb={69,77,85,93,101,109}, max=100, show_decimal=false, label="L1" },
    { key="decay_level",  lsb={71,79,87,95,103,111}, max=100, show_decimal=false, label="L2" },
    { key="sustain_level",lsb={73,81,89,97,105,113}, max=100, show_decimal=false, label="L3" },
    { key="release_level",lsb={75,83,91,99,107,115}, max=100, show_decimal=false, label="L4" },
  }

  -- Persistent state
  local state = rawget(_G, "env_state") or { values = {}, bound_ops = {} }
  rawset(_G, "env_state", state)

  -- initialize storage for this op
  if not state.values[op] then
    state.values[op] = { adsr = {}, levels = {} }
    for _,p in ipairs(adsr)   do state.values[op].adsr[p.key]   = 0 end
    for _,p in ipairs(levels) do state.values[op].levels[p.key] = 0 end
  end

  -- helper to send NRPN
  local function send(param, idx, val)
    if not midi_out then return end
    local raw = param.show_decimal
             and math.floor(val*100+0.5)
             or math.floor(val+0.5)
    local cc6, cc38 = math.floor(raw/128), raw%128
    local ch = (_G.global_midi_out_channel or 1) - 1
    midi_out:send({0xB0+ch,99,0})
    midi_out:send({0xB0+ch,98,param.lsb[idx]})
    midi_out:send({0xB0+ch, 6,cc6})
    midi_out:send({0xB0+ch,38,cc38})
  end

  -- bind receive once per op
  if _G.dispatcher then
    _G.dispatcher:bind("nrpn_received", function(msb, lsb, raw)
      for _,p in ipairs(adsr) do
        if msb==0 and lsb==p.lsb[op] then
          local v = p.show_decimal and (raw/100) or raw
          state.values[op].adsr[p.key] = v
          local id = p.key.."_"..op
          vb.views[id.."_sl"].value = v
          vb.views[id.."_vb"].value = v
          vb.views[id.."_txt"].text = p.show_decimal
            and string.format("%.2f",v)
            or tostring(v)
          return
        end
      end
      for _,p in ipairs(levels) do
        if msb==0 and lsb==p.lsb[op] then
          local v = raw
          state.values[op].levels[p.key] = v
          local id = p.key.."_"..op
          vb.views[id.."_sl"].value = v
          vb.views[id.."_vb"].value = v
          vb.views[id.."_txt"].text = tostring(v)
          return
        end
      end
    end)
  end

  -- build UI for this operator
  local cols = { vb:text{ text="Envelopes "..op, font="bold" } }
  -- ADSR rows
  for _,p in ipairs(adsr) do
    local v  = state.values[op].adsr[p.key]
    local id = p.key.."_"..op
    cols[#cols+1] = vb:row{
      vb:text{ text=p.label },
      vb:slider{
        id       = id.."_sl",
        width = 100,
        min      = 0, max=p.max,
        value    = v,
        notifier = function(v2)
          state.values[op].adsr[p.key] = v2
          vb.views[id.."_vb"].value = v2
          vb.views[id.."_txt"].text = string.format(
            p.show_decimal and "%.2f" or "%d", v2
          )
          send(p, op, v2)
        end
      },
      vb:valuebox{
        id       = id.."_vb",
        min      = 0, max=p.max,
        value    = v,
        notifier = function(v2)
          state.values[op].adsr[p.key] = v2
          vb.views[id.."_sl"].value = v2
          vb.views[id.."_txt"].text = string.format(
            p.show_decimal and "%.2f" or "%d", v2
          )
          send(p, op, v2)
        end
      },
      vb:text{ id=id.."_txt", width = 40, text=string.format(
        p.show_decimal and "%.2f" or "%d", v
      ) }
    }
  end
  -- Level rows
  for _,p in ipairs(levels) do
    local v  = state.values[op].levels[p.key]
    local id = p.key.."_"..op
    cols[#cols+1] = vb:row{
      vb:text{ text=p.label },
      vb:slider{
        id       = id.."_sl",
        width = 100,
        min      = 0, max=p.max,
        value    = v,
        notifier = function(v2)
          state.values[op].levels[p.key] = v2
          vb.views[id.."_vb"].value = v2
          vb.views[id.."_txt"].text = string.format(
            p.show_decimal and "%.2f" or "%d", v2
        )
          send(p, op, v2)
        end
      },
      vb:valuebox{
        id       = id.."_vb",
        min      = 0, max=p.max,
        value    = v,
        notifier = function(v2)
          state.values[op].levels[p.key] = v2
          vb.views[id.."_sl"].value = v2
          vb.views[id.."_txt"].text = string.format(
            p.show_decimal and "%.2f" or "%d", v2
          )
          send(p, op, v2)
        end
      },
      vb:text{ id=id.."_txt", width = 40, text=string.format(
        p.show_decimal and "%.2f" or "%d", v
      ) }
    }
  end

  return vb:column{ margin=4, spacing=4, unpack(cols) }
end
