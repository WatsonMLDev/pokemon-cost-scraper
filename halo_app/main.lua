-- ================================================================
--  PKMN_VAL_V1.0 - main.lua
--  Pokemon card valuation HUD for Brilliant Labs Halo
--  256x256 circular display, Lua 5.3
--
--  State machine:
--    RETICLE --(button_single)--> SEARCH
--    SEARCH  --(imu_tap)       --> scroll cursor down (wraps)
--    SEARCH  --(button_single) --> REPORT (selected card)
--    REPORT  --(imu_tap)       --> cycle condition page
--    ANY     --(button_long)   --> RETICLE
--
--  BLE inject protocol (from Python host):
--    0x01 = card data update   -> navigate to REPORT
--    0x02 = search list update -> navigate to SEARCH
-- ================================================================

-- ----------------------------------------------------------------
-- Font char-width estimates (px per char, used for centering)
-- Calibrated from PIL textbbox measurements
local CW10 = 6    -- font size 10
local CW11 = 6    -- font size 11
local CW12 = 8    -- font size 12

-- ----------------------------------------------------------------
-- Palette (0xRRGGBB)
local PRIMARY   = 0xDFED00   -- electric yellow-green
local SECONDARY = 0x36FFC4   -- mint teal
local DIM       = 0xC8C8AB   -- muted warm grey
local OUTLINE   = 0x474832   -- dark olive
local BLACK     = 0x000000
local SURFACE   = 0x131313   -- near-black background

-- ----------------------------------------------------------------
-- BLE message types
local MSG_CARD_DATA    = 0x01   -- full card update (conditions + sales)
local MSG_SEARCH_ITEMS = 0x02   -- search results list update
local MSG_STATUS       = 0x05   -- status/loading text update

-- ----------------------------------------------------------------
-- App state
local STATE_RETICLE = 0
local STATE_SEARCH  = 1
local STATE_REPORT  = 2
local STATE_LOADING = 3

local state         = STATE_RETICLE
local blink_tick    = 0
local search_cursor = 1
local loading_text  = "LOADING..."

-- ----------------------------------------------------------------
-- Dynamic search results (injectable via BLE MSG_SEARCH_ITEMS)
local search_items = {}

-- ----------------------------------------------------------------
-- Dynamic card data (injectable via BLE MSG_CARD_DATA)
-- Conditions are indexed; cond_page tracks which is displayed.
local current_card = {
    name = "",
    conditions = {},
}
local cond_page = 1

-- ----------------------------------------------------------------
-- String helpers for BLE payload parsing

-- Iterate lines in a string (split on \n)
local function each_line(s)
    local lines = {}
    for line in s:gmatch("[^\n]+") do
        lines[#lines + 1] = line
    end
    return lines
end

-- Split a string on a separator character, return table of fields
local function split_on(s, sep)
    local fields = {}
    for field in (s .. sep):gmatch("([^" .. sep .. "]*)" .. sep) do
        fields[#fields + 1] = field
    end
    return fields
end

-- ----------------------------------------------------------------
-- BLE receive callback: parses injected card or search data

frame.bluetooth.receive_callback(function(raw)
    local msg = string.byte(raw, 1)
    local payload = raw:sub(2)   -- drop the message-type byte

    -- MSG_STATUS (0x05): Update loading string dynamically
    if msg == MSG_STATUS then
        loading_text = payload
        if state ~= STATE_LOADING then
            state = STATE_LOADING
        end

    -- MSG_CARD_DATA (0x01):
    elseif msg == MSG_CARD_DATA then
        print("DEBUG: Received MSG_CARD_DATA")
        local ls = each_line(payload)
        print("DEBUG: Number of lines in payload = " .. #ls)
        if #ls < 1 then return end

        local new_card = { name = ls[1], conditions = {} }
        local cur_cond = nil

        for i = 2, #ls do
            local line = ls[i]
            if line == "---" then
                if cur_cond then
                    new_card.conditions[#new_card.conditions + 1] = cur_cond
                end
                cur_cond = nil
            elseif cur_cond == nil then
                -- First line of a new condition block: "SHORT|LONG NAME"
                local f = split_on(line, "|")
                cur_cond = {
                    short = f[1] or "?",
                    long  = f[2] or f[1] or "?",
                    sales = {},
                }
            else
                -- Sale row: "DATE|TYPE|QTY|PRICE"
                local f = split_on(line, "|")
                if f[1] and f[4] then
                    cur_cond.sales[#cur_cond.sales + 1] = {
                        date  = f[1],
                        type  = f[2] or "",
                        qty   = f[3] or "",
                        price = f[4],
                    }
                end
            end
        end

        -- Flush last condition if no trailing "---"
        if cur_cond then
            new_card.conditions[#new_card.conditions + 1] = cur_cond
        end

        print("DEBUG: Parsed conditions: " .. #new_card.conditions)
        current_card = new_card
        cond_page    = 1
        state        = STATE_REPORT
        print("DEBUG: state set to STATE_REPORT")

    -- MSG_SEARCH_ITEMS (0x02):
    elseif msg == MSG_SEARCH_ITEMS then
        local ls = each_line(payload)
        local new_items = {}
        for _, line in ipairs(ls) do
            local f = split_on(line, "|")
            if f[1] then
                new_items[#new_items + 1] = {
                    name = f[1],
                    num  = f[2] or "",
                }
            end
        end
        if #new_items > 0 then
            search_items  = new_items
            search_cursor = 1
            state         = STATE_SEARCH
        end
    end
end)

-- ----------------------------------------------------------------
-- Input callbacks

frame.button.single(function()
    if state == STATE_RETICLE then
        pcall(frame.bluetooth.send, string.char(0x04))
        state = STATE_LOADING
    elseif state == STATE_SEARCH then
        pcall(frame.bluetooth.send, string.char(0x03, search_cursor))
        state = STATE_LOADING
    end
end)

frame.button.long(function()
    state      = STATE_RETICLE
    blink_tick = 0
end)

frame.imu.tap_callback(function()
    if state == STATE_SEARCH then
        search_cursor = (search_cursor % #search_items) + 1
    elseif state == STATE_REPORT then
        local num_conds = #current_card.conditions
        if num_conds > 0 then
            cond_page = (cond_page % num_conds) + 1
        end
    end
end)

-- ----------------------------------------------------------------
-- Drawing helpers

-- Scanline overlay (horizontal dark lines every 4px, clipped to lens)
local function draw_scanlines()
    local y = 1
    while y <= 256 do
        local dy = math.abs(y - 128)
        if dy < 110 then
            local hw = math.max(0, math.floor(math.sqrt(110*110 - dy*dy)) - 6)
            frame.display.line(128 - hw, y, 128 + hw, y, 0x1A1A1A)
        end
        y = y + 4
    end
end

-- Dashed horizontal line
local function draw_dashed(y, x0, x1, color)
    local x, on = x0, true
    while x < x1 do
        if on then
            frame.display.line(x, y, math.min(x + 3, x1), y, color)
        end
        x  = x + 5
        on = not on
    end
end

-- Corner bracket marks around a rectangle (for selected list item)
local function draw_corner_marks(x0, y0, x1, y1, color)
    local s = 3
    frame.display.line(x0, y0, x0+s, y0, color)
    frame.display.line(x0, y0, x0, y0+s, color)
    frame.display.line(x1, y0, x1-s, y0, color)
    frame.display.line(x1, y0, x1, y0+s, color)
    frame.display.line(x0, y1, x0+s, y1, color)
    frame.display.line(x0, y1, x0, y1-s, color)
    frame.display.line(x1, y1, x1-s, y1, color)
    frame.display.line(x1, y1, x1, y1-s, color)
end

-- Center text horizontally given an estimated pixel width of the string.
-- char_w is the per-character pixel width for the current font.
local function draw_centered(txt, y, color, char_w)
    local px_w = #txt * char_w
    local x    = 128 - math.floor(px_w / 2)
    frame.display.text(txt, x, y, color)
end

-- ----------------------------------------------------------------
-- Screen: RETICLE

local function draw_reticle()
    frame.display.clear(BLACK)
    draw_scanlines()

    frame.display.circle(128, 128, 118, 0x1A1A1A, false)

    frame.display.set_font(1, 11)
    draw_centered("PKMN_VAL_V1.0", 26, PRIMARY, CW11)

    -- Tactical bracket reticle (120x120 centred at 128,128)
    local cx, cy, sz, arm = 128, 128, 60, 26
    frame.display.line(cx-sz, cy-sz, cx-sz+arm, cy-sz,       PRIMARY)
    frame.display.line(cx-sz, cy-sz, cx-sz,     cy-sz+arm,   PRIMARY)
    frame.display.line(cx+sz, cy-sz, cx+sz-arm, cy-sz,       PRIMARY)
    frame.display.line(cx+sz, cy-sz, cx+sz,     cy-sz+arm,   PRIMARY)
    frame.display.line(cx-sz, cy+sz, cx-sz+arm, cy+sz,       PRIMARY)
    frame.display.line(cx-sz, cy+sz, cx-sz,     cy+sz-arm,   PRIMARY)
    frame.display.line(cx+sz, cy+sz, cx+sz-arm, cy+sz,       PRIMARY)
    frame.display.line(cx+sz, cy+sz, cx+sz,     cy+sz-arm,   PRIMARY)

    -- Dim crosshair axes
    frame.display.line(cx-10, cy, cx+10, cy, 0x2A2A10)
    frame.display.line(cx, cy-10, cx, cy+10, 0x2A2A10)

    -- Centre dot
    frame.display.circle(cx, cy, 2, PRIMARY, true)

    -- Blinking footer
    if blink_tick % 2 == 0 then
        frame.display.set_font(1, 11)
        draw_centered("PRESS [B1] TO SCAN", 218, SECONDARY, CW11)
    end

    frame.display.show()
end

-- ----------------------------------------------------------------
-- Screen: SEARCH RESULTS

local function draw_search()
    frame.display.clear(SURFACE)
    draw_scanlines()

    local sx0, sx1 = 35, 221
    local pad = sx0 + 4

    -- Header
    frame.display.set_font(1, 11)
    local hdr = "RESULTS [" .. #search_items .. "]"
    draw_centered(hdr, 30, PRIMARY, CW11)
    draw_dashed(43, sx0, sx1, OUTLINE)

    -- List items
    local item_h = 34
    local y0     = 52

    for i, item in ipairs(search_items) do
        local iy0 = y0 + (i-1) * item_h
        local iy1 = iy0 + item_h - 2

        -- Clip to screen
        if iy0 > 210 then break end

        if i == search_cursor then
            frame.display.rect(sx0, iy0, sx1-sx0, item_h-2, PRIMARY, true)
            draw_corner_marks(sx0, iy0, sx1, iy1, 0x1B1D00)

            frame.display.set_font(1, 14)
            frame.display.text(">", pad, iy0+3, 0x1B1D00)

            frame.display.set_font(1, 13)
            frame.display.text(item.name, pad+16, iy0+2, 0x1B1D00)

            frame.display.set_font(1, 10)
            frame.display.text(item.num, pad+16, iy0+17, 0x3A3D00)
        else
            frame.display.set_font(1, 13)
            frame.display.text(item.name, pad+20, iy0+2, DIM)

            frame.display.set_font(1, 10)
            frame.display.text(item.num, pad+20, iy0+17, OUTLINE)
        end

        if i < #search_items then
            draw_dashed(iy1+1, sx0, sx1, OUTLINE)
        end
    end

    -- Footer
    frame.display.set_font(1, 10)
    draw_centered("[TAP] NAV  [B1] SELECT", 222, DIM, CW10)

    frame.display.show()
end

-- ----------------------------------------------------------------
-- Screen: VALUATION REPORT
--
-- Table layout:
--   DATE   - left anchor  (sx0)
--   TYPE   - left of middle (sx0 + DATE_COL_W)
--   QTY    - right of middle (before price)
--   PRICE  - right-anchored per-row using #price * CW10

local function draw_report()
    frame.display.clear(SURFACE)
    draw_scanlines()

    local sx0, sx1 = 32, 224

    -- Guard: no conditions loaded yet
    if #current_card.conditions == 0 then
        frame.display.set_font(1, 11)
        draw_centered("NO DATA", 128, DIM, CW11)
        frame.display.show()
        return
    end

    local cond = current_card.conditions[cond_page]

    -- Header: card name
    local disp_name = current_card.name
    if #disp_name > 22 then
        disp_name = string.sub(disp_name, 1, 19) .. "..."
    end
    frame.display.set_font(1, 11)
    draw_centered(disp_name, 22, PRIMARY, CW11)

    -- Condition label: "[LP] LIGHTLY PLAYED"
    local cond_label = "[" .. cond.short .. "] " .. cond.long
    frame.display.set_font(1, 10)
    draw_centered(cond_label, 35, SECONDARY, CW10)
    draw_dashed(48, sx0, sx1, OUTLINE)

    -- ---- Table column anchors ----
    -- Safe area: sx0=32, sx1=224, total width=192px
    -- DATE  : left anchor          (x=32)
    -- TYPE  : after date + gap     (x=82)
    -- QTY   : fixed center-right   (x=160)
    -- PRICE : right-anchored      per row: sx1 - #price * CW10
    local col_date  = sx0           -- 32
    local col_type  = sx0 + 50     -- 82
    local col_qty   = sx0 + 128    -- 160

    -- Column header row
    local hy = 56
    frame.display.set_font(1, 10)
    frame.display.text("DATE",  col_date, hy, DIM)
    frame.display.text("TYPE",  col_type, hy, DIM)
    frame.display.text("QTY",   col_qty,  hy, DIM)
    -- Right-anchor PRICE header to match data rows
    -- "$15.90" = 6 chars -> price_x = 224-36=188; PRICE hdr = 224-30=194
    local price_hdr_x = sx1 - 5*CW10
    frame.display.text("PRICE", price_hdr_x, hy, DIM)

    draw_dashed(hy + 11, sx0, sx1, OUTLINE)

    -- Data rows
    local row_y = hy + 15
    for idx, sale in ipairs(cond.sales) do
        -- DATE (left anchor)
        frame.display.set_font(1, 11)
        frame.display.text(sale.date, col_date, row_y, PRIMARY)

        frame.display.set_font(1, 10)
        -- TYPE (left of middle)
        frame.display.text(sale.type, col_type, row_y, PRIMARY)
        -- QTY (right of middle, fixed)
        frame.display.text(sale.qty, col_qty, row_y, DIM)
        -- PRICE: right-anchored - start x = sx1 - width of this price string
        local price_x = sx1 - #sale.price * CW10
        frame.display.text(sale.price, price_x, row_y, PRIMARY)

        -- Row separator (skip after last)
        if idx < #cond.sales then
            draw_dashed(row_y + 12, sx0, sx1, 0x2A2A1E)
        end

        row_y = row_y + 18
        if row_y > 210 then break end
    end

    -- Condition page indicator dots
    local num_conds = #current_card.conditions
    local dot_y     = 218
    local spacing   = 12
    local dot_cx    = 128 - math.floor((num_conds-1) * spacing / 2)
    for d = 1, num_conds do
        local dx = dot_cx + (d-1) * spacing
        if d == cond_page then
            frame.display.circle(dx, dot_y, 3, PRIMARY, true)
        else
            frame.display.circle(dx, dot_y, 3, OUTLINE, false)
        end
    end

    -- Footer
    frame.display.set_font(1, 10)
    draw_centered("[TAP] NEXT COND", 228, DIM, CW10)

    frame.display.show()
end

local function draw_loading()
    frame.display.clear(SURFACE)
    draw_scanlines()
    frame.display.set_font(1, 11)
    draw_centered(loading_text, 120, PRIMARY, CW11)
    frame.display.show()
end

-- ----------------------------------------------------------------
-- Main render loop

while true do
    local ok, err = pcall(function()
        blink_tick = blink_tick + 1

        if state == STATE_RETICLE then
            draw_reticle()
        elseif state == STATE_SEARCH then
            draw_search()
        elseif state == STATE_REPORT then
            draw_report()
        elseif state == STATE_LOADING then
            draw_loading()
        end
    end)

    if not ok then
        print("[PKMN_VAL error]: " .. tostring(err))
        frame.display.clear(0)
        break
    end

    frame.sleep(0.5)
end
