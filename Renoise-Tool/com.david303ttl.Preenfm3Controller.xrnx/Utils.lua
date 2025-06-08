-- Utils.lua
-- Module: User-defined CC controls and utility functions for PreenFM3 NRPN Controller

return function(args)
  local vb       = args.vb
  local midi_out = rawget(_G, "shared_midi_out")

  -- persisted state
  local state = rawget(_G, "utils_state") or {}
  rawset(_G, "utils_state", state)

  -- CC definitions for the sliders/buttons
  local ui_defs = {
    { label = "User 1",    cc = 34 },
    { label = "User 2",    cc = 35 },
    { label = "User 3",    cc = 36 },
    { label = "User 4",    cc = 37 },
    { label = "Perf 1",    cc = 115 },
    { label = "Perf 2",    cc = 116 },
    { label = "Perf 3",    cc = 117 },
    { label = "Perf 4",    cc = 118 },
    { label = "All Notes Off", cc = 123, button = true },
    { label = "Reset",     cc = 127, button = true },
  }

  -- send helper
  local function send_cc(cc_num, value)
    if not midi_out then return end
    local channel = rawget(_G, "global_midi_out_channel") or 1
    local ch = channel - 1
    midi_out:send({0xB0 + ch, cc_num, value})
  end

  -- build rows
  local rows = {}

  -- global MIDI-out channel selector
  rows[#rows+1] = vb:row{
    vb:text { text = "MIDI Out Channel:" },
    vb:popup{
      id       = "global_out_chan",
      width = 40,
      items    = (function() local t={} for i=1,16 do t[i]=tostring(i) end return t end)(),
      value    = rawget(_G, "global_midi_out_channel") or 1,
      notifier = function(v) _G.set_global_midi_out_channel(v) end
    }
  }
  rows[#rows+1] = vb:space{ height = 12 }

  -- one row per CC definition
  for i, def in ipairs(ui_defs) do
    -- initialize stored value to zero
    state[i] = state[i] or 0

    if def.button then
      rows[#rows+1] = vb:row{
        vb:button{
          text     = def.label,
          notifier = function() send_cc(def.cc, 0) end
        }
      }
    else
      rows[#rows+1] = vb:row{
        vb:text { text = def.label },
        vb:slider{
          id    = "util_sl"..i,
          width = 100,
          min   = 0, max = 127,
          value = state[i],
          notifier = function(v)
            state[i] = v
            vb.views["util_vb"..i].value = v
            send_cc(def.cc, v)
          end
        },
        vb:valuebox{
          id    = "util_vb"..i,
          min   = 0, max = 127,
          value = state[i],
          notifier = function(v)
            state[i] = v
            vb.views["util_sl"..i].value = v
            send_cc(def.cc, v)
          end
        }
      }
    end
  end

  return vb:column{ spacing = 8, margin = 12, unpack(rows) }
end
