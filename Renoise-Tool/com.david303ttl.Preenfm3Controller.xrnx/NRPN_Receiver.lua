-- NRPN_Receiver.lua
-- Module: Simple NRPN receive functionality for PreenFM3 NRPN Controller
return function(args)
  local vb = args.vb
  
  -- 1. Persistent state for receiver
  local state = rawget(_G, "nrpn_recv_state") or { 
    channel = 1, 
    listening = false,
    device_name = nil 
  }
  rawset(_G, "nrpn_recv_state", state)
  
  local midi_in = rawget(_G, "shared_midi_in")
  
  -- 3. Temp storage for NRPN parts
  local msb, lsb, data_msb, data_lsb
  
  local function on_midi(msg)
    -- msg = { status, cc, value }
    local status = msg[1]
    local incoming_chan = (status % 16) + 1
    
    if incoming_chan ~= state.channel then
      return
    end
    
    local cc, val = msg[2], msg[3]
    
    if cc == 99 then
      msb = val
    elseif cc == 98 then
      lsb = val
    elseif cc == 6 then
      data_msb = val
    elseif cc == 38 then
      data_lsb = val
    end
    
    if msb and lsb and data_msb and data_lsb then
      local raw_value = data_msb * 128 + data_lsb
      
      renoise.app():show_status(
        string.format("Received NRPN %d:%d → %d on Ch %d",
                      msb, lsb, raw_value, state.channel)
      )
      
      if _G.dispatcher and _G.dispatcher.dispatch then
        _G.dispatcher:dispatch("nrpn_received", msb, lsb, raw_value)
      end
      
      msb, lsb, data_msb, data_lsb = nil, nil, nil, nil
    end
  end

-- Function to send Pull All parameters NRPN command
local function send_pull_command()
  local midi_out = rawget(_G,"shared_midi_out")
  if not midi_out then
    renoise.app():show_status("Error: MIDI output not initialized!")
    return
  end

  local status = 0xB0 + (state.channel - 1)
  -- NRPN MSB (CC99) = 127
  midi_out:send({ status, 99, 127 })
  -- NRPN LSB (CC98) = 127
  midi_out:send({ status, 98, 127 })
  -- Data Entry MSB (CC6) = 0
  midi_out:send({ status,  6,   0 })
  -- Data Entry LSB (CC38) = 0
  midi_out:send({ status, 38,   0 })

  renoise.app():show_status(
    string.format("Sent Pull All (127:127) on Ch %d", state.channel)
  )
end


local function close_input()
    if midi_in then
      pcall(function() 
        if midi_in.is_open then
          midi_in:close() 
        end
      end)
      rawset(_G, "shared_midi_in", nil)
      midi_in = nil
    end
    state.listening = false
  end
  
  local function get_available_devices()
    local devices = {}
    pcall(function()
      devices = renoise.Midi.available_input_devices()
    end)
    return devices
  end
  
  local function open_midi_input()
    if state.listening then
      return false, "Already listening"
    end
    close_input()
    
    local devices = get_available_devices()
    if #devices == 0 then
      return false, "No MIDI input devices found!"
    end
    
    local device_to_use = state.device_name or devices[1]
    
    local device_available = false
    for _, dev in ipairs(devices) do
      if dev == device_to_use then
        device_available = true
        break
      end
    end
    
    if not device_available then
      device_to_use = devices[1]
    end

    local success, error_msg = pcall(function()
      midi_in = renoise.Midi.create_input_device(device_to_use, on_midi)
      rawset(_G, "shared_midi_in", midi_in)
      state.listening = true
      state.device_name = device_to_use
    end)
    
    if success and midi_in then
      return true, "MIDI input opened: " .. device_to_use
    else
      return false, "Failed to open MIDI device: " .. (error_msg or "unknown error")
    end
  end
  
  local function auto_reconnect()
    if state.listening and not midi_in then
      local success, msg = open_midi_input()
      if success then
        renoise.app():show_status("Auto-reconnected: " .. msg)
        if vb.views["btn_start"] then
          vb.views["btn_start"].text = "Listening..."
        end
      end
    end
  end
  
  if state.listening then
    auto_reconnect()
  end
  
  return vb:column{
    margin  = 12,
    spacing = 8,
    
    vb:text{ text="NRPN Receiver", font="bold" },
    vb:row{
      vb:text { text = "MIDI In Channel:   " },
      vb:popup{
        id       = "recv_chan",
        width    = 40,
        items    = (function()
                     local t = {}
                     for i = 1, 16 do t[i] = tostring(i) end
                     return t
                   end)(),
        value    = state.channel,
        notifier = function(v)
          state.channel = v
        end
      }
    },
    
    -- Start / Stop
    vb:row{
      spacing = 16,
      
      -- Start Receive
      vb:button{
        id   = "btn_start",
        text = state.listening and "Listening..." or "Start Receive",
        notifier = function()
          if not state.listening then
            local success, msg = open_midi_input()
            
            if success then
              vb.views["btn_start"].text = "Listening..."
              renoise.app():show_status(msg)
            else
              renoise.app():show_status("Error: " .. msg)
            end
          end
        end
      },
      
      -- Stop Receive
      vb:button{
        text = "Stop Receive",
        notifier = function()
          close_input()
          if vb.views["btn_start"] then
            vb.views["btn_start"].text = "Start Receive"
          end
          renoise.app():show_status("MIDI input handler closed")
        end
      }
    },
    -- Pull All NRPN (oneshot)
    vb:row{
      spacing = 16,
      vb:button{
        text = "Pull All parameters",
        notifier = function()
          send_pull_command()
        end
      }
    },
  }
   
end