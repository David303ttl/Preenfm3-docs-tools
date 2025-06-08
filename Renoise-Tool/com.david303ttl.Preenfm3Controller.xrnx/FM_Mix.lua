-- FM_Mix.lua
-- Module: immediate NRPN send and receive on Mix & Pan sliders/valueboxes

return function(args)
    local vb            = args.vb
    local parameters    = args.parameters_mod2   
    local get_param_min = args.get_param_min
    local get_param_max = args.get_param_max

    local midi_out = rawget(_G, "shared_midi_out")

    -- Persisted module state 
    local state = rawget(_G, "mix_state") or {
        values  = {},    
    }
    rawset(_G, "mix_state", state)

    -- Initialize defaults once
    if not state.inited then
        for i, p in ipairs(parameters) do
            local mn, mx = get_param_min(p), get_param_max(p)
            state.values[i] = p.name:match("^Mix") and mx or ((mn + mx)/2)
        end
        state.inited = true
    end

    -- NRPN send helper
    local function send_nrpn(param, ui_val)
        if not midi_out then return end
        local raw = param.show_decimal and math.floor(ui_val * 100 + 0.5) or math.floor(ui_val + 0.5)
        if param.midi_offset then raw = raw + param.midi_offset end
        local cc6  = math.floor(raw / 128)
        local cc38 = raw % 128
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
                    local mn, mx = get_param_min(p), get_param_max(p)
                    ui_val = math.max(mn, math.min(mx, ui_val))
                    if p.name:match("^Mix") then
                        vb.views["mix_sl"..i].value = ui_val
                        vb.views["mix_lbl"..i].text  = tostring(math.floor(ui_val+0.5))
                    else
                        local idx = i - 6
                        vb.views["pan_sl"..idx].value = ui_val
                        vb.views["pan_lbl"..idx].text = string.format("%.2f", (ui_val-mn)/(mx-mn)*2-1)
                    end
                    state.values[i] = ui_val
                    break
                end
            end
        end)
    end

    -- Build UI 
    local rows = {}
    for i = 1, 6 do
        local p = parameters[i]
        local mn, mx = get_param_min(p), get_param_max(p)
        table.insert(rows, vb:row{
            vb:text { text = p.name..":" },
            vb:slider{
                id    = "mix_sl"..i,
                width = 100,
                min   = mn,
                max   = mx,
                value = state.values[i],
                notifier = function(v)
                    state.values[i] = v
                    vb.views["mix_lbl"..i].text = tostring(math.floor(v+0.5))
                    send_nrpn(p, v)
                end
            },
            vb:text{
                id    = "mix_lbl"..i,
                width = 40,
                text = tostring(math.floor(state.values[i]+0.5))
            }
        })
    end

    for i = 7, 12 do
        local p = parameters[i]
        local mn, mx = get_param_min(p), get_param_max(p)
        local idx = i - 6
        table.insert(rows, vb:row{
            vb:text { text = p.name..":" },
            vb:slider{
                id    = "pan_sl"..idx,
                width = 100,
                min   = mn,
                max   = mx,
                value = state.values[i],
                notifier = function(v)
                    state.values[i] = v
                    vb.views["pan_lbl"..idx].text = string.format("%.2f", (v-mn)/(mx-mn)*2-1)
                    send_nrpn(p, v)
                end
            },
            vb:text{
                id    = "pan_lbl"..idx,
                width = 40,
                text = string.format("%.2f", (state.values[i]-mn)/(mx-mn)*2-1)
            }
        })
    end
    return vb:column{ spacing=8, margin=12, unpack(rows) }
end
