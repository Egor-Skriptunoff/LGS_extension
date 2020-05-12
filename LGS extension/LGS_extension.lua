---------------------------------------------------------------------------------------------
-- LGS_extension.lua
---------------------------------------------------------------------------------------------
-- This module is invoked by 'LGS_script_template.lua'
-- The full path to this module must be assigned to variable 'extension_module_full_path', see 'LGS_script_template.lua' line #280

local
   select, tostring, type, floor,      min,      max,      sqrt,      format,        byte,        char,        rep,        sub,        gsub,        concat      =
   select, tostring, type, math.floor, math.min, math.max, math.sqrt, string.format, string.byte, string.char, string.rep, string.sub, string.gsub, table.concat
local
   MoveMouseRelative, MoveMouseTo, GetMousePosition, Sleep_orig, GetRunningTime, OutputLogMessage, OutputDebugMessage =
   MoveMouseRelative, MoveMouseTo, GetMousePosition, Sleep,      GetRunningTime, OutputLogMessage, OutputDebugMessage

function print(...)
   local t = {...}
   for j = 1, select("#", ...) do
      t[j] = tostring(t[j])
   end
   OutputLogMessage("%s\n", concat(t, "\t"))
end

local GetMousePositionInPixels
do
   local xy_data, xy_64K, xy_pixels, enabled = {{}, {}}, {}, {}, true

   function GetMousePositionInPixels()
      -- The function returns mouse_x_pixels, mouse_y_pixels, screen_width, screen_height, x_64K, y_64K
      -- 0 <= mouse_x_pixels < screen_width
      -- 0 <= mouse_y_pixels < screen_height
      -- it's assumed that both width and height of your screen are between 150 and 10240 pixels
      xy_64K[1], xy_64K[2] = GetMousePosition()
      if enabled then
         local jump
         local attempts_qty = 3
         for attempt = 1, attempts_qty + 1 do
            for i = 1, 2 do
               local result
               local size = xy_data[i][4]
               if size then
                  local coord_64K = xy_64K[i]
                  -- How to convert between pos_64K (0...65535) and pixel (0...(size-1))
                  --    pos_64K = floor(pixel * 65535 / (size-1) + 0.5)
                  --    pixel   = floor((pos_64K + (0.5 + 2^-16)) * (size-1) / 65535)
                  local pixels = floor((coord_64K + (0.5 + 2^-16)) * (size - 1) / 65535)
                  if 65535 * pixels >= (coord_64K - (0.5 + 2^-16)) * (size - 1) then
                     result = pixels
                  end
               end
               xy_pixels[i] = result
            end
            if xy_pixels[1] and xy_pixels[2] then
               return xy_pixels[1], xy_pixels[2], xy_data[1][4], xy_data[2][4], xy_64K[1], xy_64K[2]
            elseif attempt <= attempts_qty then
               if jump then
                  MoveMouseTo(3*2^14 - xy_64K[1]/2, 3*2^14 - xy_64K[2]/2)
                  Sleep_orig(10)
                  xy_64K[1], xy_64K[2] = GetMousePosition()
               end
               jump = true
               for _, data in ipairs(xy_data) do
                  data[1] = {[0] = true}
                  data[2] = 0
                  data[3] = 45 * 225
                  data[4] = nil
                  data[5] = 6
                  for j = 6, 229 do
                     data[j] = (2^45 - 1) * 256 + 1 + j
                  end
                  data[230] = (2^45 - 1) * 256
               end
               local dx = xy_64K[1] < 2^15 and 1 or -1
               local dy = xy_64K[2] < 2^15 and 1 or -1
               local prev_coords_processed_1, prev_coords_processed_2, prev_variants_qty, trust
               for frame = 1, 90 * attempt do
                  for i = 1, 2 do
                     local data, coord_64K = xy_data[i], xy_64K[i]
                     local data_1 = data[1]
                     if not data_1[coord_64K] then
                        data_1[coord_64K] = true
                        data[2] = data[2] + 1
                        local min_size
                        local prev_idx = 5
                        local idx = data[prev_idx]
                        while idx > 0 do
                           local N = data[idx]
                           local mask = 2^53
                           local size_from = idx * 45 + (150 - 6 * 45)
                           for size = size_from, size_from + 44 do
                              mask = mask / 2
                              if N >= mask then
                                 N = N - mask
                                 if 65535 * floor((coord_64K + (0.5 + 2^-16)) * (size - 1) / 65535) < (coord_64K - (0.5 + 2^-16)) * (size - 1) then
                                    data[idx] = data[idx] - mask
                                    data[3] = data[3] - 1
                                 else
                                    min_size = min_size or size
                                 end
                              end
                           end
                           if data[idx] < mask then
                              data[prev_idx] = data[prev_idx] + (N - idx)
                           else
                              prev_idx = idx
                           end
                           idx = N
                        end
                        data[4] = min_size
                     end
                  end
                  local variants_qty = xy_data[1][3] + xy_data[2][3]
                  local coords_processed_1 = xy_data[1][2]
                  local coords_processed_2 = xy_data[2][2]
                  if variants_qty ~= prev_variants_qty then
                     prev_variants_qty = variants_qty
                     prev_coords_processed_1 = coords_processed_1
                     prev_coords_processed_2 = coords_processed_2
                  end
                  if min(coords_processed_1 - prev_coords_processed_1, coords_processed_2 - prev_coords_processed_2) >= 20 then
                     trust = true
                     break
                  end
                  local num = sqrt(frame + 0.1) % 1 < 0.5 and 2^13 or 0
                  MoveMouseRelative(
                     dx * max(1, floor(num / ((xy_64K[1] - 2^15) * dx + (2^15 + 2^13/8)))),
                     dy * max(1, floor(num / ((xy_64K[2] - 2^15) * dy + (2^15 + 2^13/8))))
                  )
                  Sleep_orig(10)
                  xy_64K[1], xy_64K[2] = GetMousePosition()
               end
               if not trust then
                  xy_data[1][4], xy_data[2][4] = nil
               end
            end
         end
         enabled = false
         print'Function "GetMousePositionInPixels()" failed to determine screen resolution and has been disabled'
      end
      return 0, 0, 0, 0, xy_64K[1], xy_64K[2]  -- functionality is disabled, so no pixel-related information is returned
   end

end
_G.GetMousePositionInPixels = GetMousePositionInPixels

function SetMousePositionInPixels(x, y)
   local _, _, width, height = GetMousePositionInPixels()
   if width > 0 then
      MoveMouseTo(
         floor(max(0, min(width  - 1, x)) * (2^16-1) / (width  - 1) + 0.5),
         floor(max(0, min(height - 1, y)) * (2^16-1) / (height - 1) + 0.5)
      )
   end
end

local update_internal_state, perform_calculations
do

   local function create_array_of_lanes()
      local arr = {}
      for j = 1, 50 do
         arr[j] = 0
      end
      return arr
   end

   local keccak_feed, XOR53
   do
      local RC_lo, RC_hi, AND, XOR = {}, {}
      do
         local AND_of_two_bytes, m, sh_reg = {[0] = 0}, 0, 29
         for y = 0, 127 * 256, 256 do
            for x = y, y + 127 do
               x = AND_of_two_bytes[x] * 2
               AND_of_two_bytes[m] = x
               AND_of_two_bytes[m + 1] = x
               AND_of_two_bytes[m + 256] = x
               AND_of_two_bytes[m + 257] = x + 1
               m = m + 2
            end
            m = m + 256
         end

         function AND(x, y, xor)
            local x0 = x % 2^32
            local y0 = y % 2^32
            local rx = x0 % 256
            local ry = y0 % 256
            local res = AND_of_two_bytes[rx + ry * 256]
            x = x0 - rx
            y = (y0 - ry) / 256
            rx = x % 65536
            ry = y % 256
            res = res + AND_of_two_bytes[rx + ry] * 256
            x = (x - rx) / 256
            y = (y - ry) / 256
            rx = x % 65536 + y % 256
            res = res + AND_of_two_bytes[rx] * 65536
            res = res + AND_of_two_bytes[(x + y - rx) / 256] * 16777216
            if xor then
               return x0 + y0 - 2 * res
            else
               return res
            end
         end

         function XOR(x, y, z, t, u)
            if z then
               if t then
                  if u then
                     t = AND(t, u, true)
                  end
                  z = AND(z, t, true)
               end
               y = AND(y, z, true)
            end
            return AND(x, y, true)
         end

         local function split53(x)
            local lo = x % 2^32
            return lo, (x - lo) / 2^32
         end

         function XOR53(x, y)
            local x_lo, x_hi = split53(x)
            local y_lo, y_hi = split53(y)
            return XOR(x_hi, y_hi) * 2^32 + XOR(x_lo, y_lo)
         end

         local function next_bit()
            local r = sh_reg % 2
            sh_reg = XOR((sh_reg - r) / 2, 142 * r)
            return r * m
         end

         for idx = 1, 24 do
            local lo = 0
            for j = 0, 5 do
               m = 2^(2^j - 1)
               lo = lo + next_bit()
            end
            RC_lo[idx], RC_hi[idx] = lo, next_bit()
         end
      end

      function keccak_feed(lanes, str, offs, size, block_size_in_bytes)
         for pos = offs, offs + size - 1, block_size_in_bytes do
            for j = 1, block_size_in_bytes / 4 do
               pos = pos + 4
               local a, b, c, d = byte(str, pos - 3, pos)
               lanes[j] = XOR(lanes[j], ((d * 256 + c) * 256 + b) * 256 + a)
            end
            local
               L01_lo, L01_hi, L02_lo, L02_hi, L03_lo, L03_hi, L04_lo, L04_hi, L05_lo, L05_hi, L06_lo, L06_hi, L07_lo, L07_hi, L08_lo, L08_hi,
               L09_lo, L09_hi, L10_lo, L10_hi, L11_lo, L11_hi, L12_lo, L12_hi, L13_lo, L13_hi, L14_lo, L14_hi, L15_lo, L15_hi, L16_lo, L16_hi,
               L17_lo, L17_hi, L18_lo, L18_hi, L19_lo, L19_hi, L20_lo, L20_hi, L21_lo, L21_hi, L22_lo, L22_hi, L23_lo, L23_hi, L24_lo, L24_hi, L25_lo, L25_hi =
               lanes[01], lanes[02], lanes[03], lanes[04], lanes[05], lanes[06], lanes[07], lanes[08], lanes[09], lanes[10], lanes[11],
               lanes[12], lanes[13], lanes[14], lanes[15], lanes[16], lanes[17], lanes[18], lanes[19], lanes[20], lanes[21], lanes[22], lanes[23], lanes[24],
               lanes[25], lanes[26], lanes[27], lanes[28], lanes[29], lanes[30], lanes[31], lanes[32], lanes[33], lanes[34], lanes[35], lanes[36], lanes[37],
               lanes[38], lanes[39], lanes[40], lanes[41], lanes[42], lanes[43], lanes[44], lanes[45], lanes[46], lanes[47], lanes[48], lanes[49], lanes[50]
            for round_idx = 1, 24 do
               local C1_lo = XOR(L01_lo, L06_lo, L11_lo, L16_lo, L21_lo)
               local C1_hi = XOR(L01_hi, L06_hi, L11_hi, L16_hi, L21_hi)
               local C2_lo = XOR(L02_lo, L07_lo, L12_lo, L17_lo, L22_lo)
               local C2_hi = XOR(L02_hi, L07_hi, L12_hi, L17_hi, L22_hi)
               local C3_lo = XOR(L03_lo, L08_lo, L13_lo, L18_lo, L23_lo)
               local C3_hi = XOR(L03_hi, L08_hi, L13_hi, L18_hi, L23_hi)
               local C4_lo = XOR(L04_lo, L09_lo, L14_lo, L19_lo, L24_lo)
               local C4_hi = XOR(L04_hi, L09_hi, L14_hi, L19_hi, L24_hi)
               local C5_lo = XOR(L05_lo, L10_lo, L15_lo, L20_lo, L25_lo)
               local C5_hi = XOR(L05_hi, L10_hi, L15_hi, L20_hi, L25_hi)
               local D_lo = XOR(C1_lo, C3_lo * 2 + (C3_hi - C3_hi % 2^31) / 2^31)
               local D_hi = XOR(C1_hi, C3_hi * 2 + (C3_lo - C3_lo % 2^31) / 2^31)
               local T0_lo = XOR(D_lo, L02_lo)
               local T0_hi = XOR(D_hi, L02_hi)
               local T1_lo = XOR(D_lo, L07_lo)
               local T1_hi = XOR(D_hi, L07_hi)
               local T2_lo = XOR(D_lo, L12_lo)
               local T2_hi = XOR(D_hi, L12_hi)
               local T3_lo = XOR(D_lo, L17_lo)
               local T3_hi = XOR(D_hi, L17_hi)
               local T4_lo = XOR(D_lo, L22_lo)
               local T4_hi = XOR(D_hi, L22_hi)
               L02_lo = (T1_lo - T1_lo % 2^20) / 2^20 + T1_hi * 2^12
               L02_hi = (T1_hi - T1_hi % 2^20) / 2^20 + T1_lo * 2^12
               L07_lo = (T3_lo - T3_lo % 2^19) / 2^19 + T3_hi * 2^13
               L07_hi = (T3_hi - T3_hi % 2^19) / 2^19 + T3_lo * 2^13
               L12_lo = T0_lo * 2 + (T0_hi - T0_hi % 2^31) / 2^31
               L12_hi = T0_hi * 2 + (T0_lo - T0_lo % 2^31) / 2^31
               L17_lo = T2_lo * 2^10 + (T2_hi - T2_hi % 2^22) / 2^22
               L17_hi = T2_hi * 2^10 + (T2_lo - T2_lo % 2^22) / 2^22
               L22_lo = T4_lo * 2^2 + (T4_hi - T4_hi % 2^30) / 2^30
               L22_hi = T4_hi * 2^2 + (T4_lo - T4_lo % 2^30) / 2^30
               D_lo = XOR(C2_lo, C4_lo * 2 + (C4_hi - C4_hi % 2^31) / 2^31)
               D_hi = XOR(C2_hi, C4_hi * 2 + (C4_lo - C4_lo % 2^31) / 2^31)
               T0_lo = XOR(D_lo, L03_lo)
               T0_hi = XOR(D_hi, L03_hi)
               T1_lo = XOR(D_lo, L08_lo)
               T1_hi = XOR(D_hi, L08_hi)
               T2_lo = XOR(D_lo, L13_lo)
               T2_hi = XOR(D_hi, L13_hi)
               T3_lo = XOR(D_lo, L18_lo)
               T3_hi = XOR(D_hi, L18_hi)
               T4_lo = XOR(D_lo, L23_lo)
               T4_hi = XOR(D_hi, L23_hi)
               L03_lo = (T2_lo - T2_lo % 2^21) / 2^21 + T2_hi * 2^11
               L03_hi = (T2_hi - T2_hi % 2^21) / 2^21 + T2_lo * 2^11
               L08_lo = (T4_lo - T4_lo % 2^3) / 2^3 + T4_hi * 2^29 % 2^32
               L08_hi = (T4_hi - T4_hi % 2^3) / 2^3 + T4_lo * 2^29 % 2^32
               L13_lo = T1_lo * 2^6 + (T1_hi - T1_hi % 2^26) / 2^26
               L13_hi = T1_hi * 2^6 + (T1_lo - T1_lo % 2^26) / 2^26
               L18_lo = T3_lo * 2^15 + (T3_hi - T3_hi % 2^17) / 2^17
               L18_hi = T3_hi * 2^15 + (T3_lo - T3_lo % 2^17) / 2^17
               L23_lo = (T0_lo - T0_lo % 2^2) / 2^2 + T0_hi * 2^30 % 2^32
               L23_hi = (T0_hi - T0_hi % 2^2) / 2^2 + T0_lo * 2^30 % 2^32
               D_lo = XOR(C3_lo, C5_lo * 2 + (C5_hi - C5_hi % 2^31) / 2^31)
               D_hi = XOR(C3_hi, C5_hi * 2 + (C5_lo - C5_lo % 2^31) / 2^31)
               T0_lo = XOR(D_lo, L04_lo)
               T0_hi = XOR(D_hi, L04_hi)
               T1_lo = XOR(D_lo, L09_lo)
               T1_hi = XOR(D_hi, L09_hi)
               T2_lo = XOR(D_lo, L14_lo)
               T2_hi = XOR(D_hi, L14_hi)
               T3_lo = XOR(D_lo, L19_lo)
               T3_hi = XOR(D_hi, L19_hi)
               T4_lo = XOR(D_lo, L24_lo)
               T4_hi = XOR(D_hi, L24_hi)
               L04_lo = T3_lo * 2^21 % 2^32 + (T3_hi - T3_hi % 2^11) / 2^11
               L04_hi = T3_hi * 2^21 % 2^32 + (T3_lo - T3_lo % 2^11) / 2^11
               L09_lo = T0_lo * 2^28 % 2^32 + (T0_hi - T0_hi % 2^4) / 2^4
               L09_hi = T0_hi * 2^28 % 2^32 + (T0_lo - T0_lo % 2^4) / 2^4
               L14_lo = T2_lo * 2^25 % 2^32 + (T2_hi - T2_hi % 2^7) / 2^7
               L14_hi = T2_hi * 2^25 % 2^32 + (T2_lo - T2_lo % 2^7) / 2^7
               L19_lo = (T4_lo - T4_lo % 2^8) / 2^8 + T4_hi * 2^24 % 2^32
               L19_hi = (T4_hi - T4_hi % 2^8) / 2^8 + T4_lo * 2^24 % 2^32
               L24_lo = (T1_lo - T1_lo % 2^9) / 2^9 + T1_hi * 2^23 % 2^32
               L24_hi = (T1_hi - T1_hi % 2^9) / 2^9 + T1_lo * 2^23 % 2^32
               D_lo = XOR(C4_lo, C1_lo * 2 + (C1_hi - C1_hi % 2^31) / 2^31)
               D_hi = XOR(C4_hi, C1_hi * 2 + (C1_lo - C1_lo % 2^31) / 2^31)
               T0_lo = XOR(D_lo, L05_lo)
               T0_hi = XOR(D_hi, L05_hi)
               T1_lo = XOR(D_lo, L10_lo)
               T1_hi = XOR(D_hi, L10_hi)
               T2_lo = XOR(D_lo, L15_lo)
               T2_hi = XOR(D_hi, L15_hi)
               T3_lo = XOR(D_lo, L20_lo)
               T3_hi = XOR(D_hi, L20_hi)
               T4_lo = XOR(D_lo, L25_lo)
               T4_hi = XOR(D_hi, L25_hi)
               L05_lo = T4_lo * 2^14 + (T4_hi - T4_hi % 2^18) / 2^18
               L05_hi = T4_hi * 2^14 + (T4_lo - T4_lo % 2^18) / 2^18
               L10_lo = T1_lo * 2^20 % 2^32 + (T1_hi - T1_hi % 2^12) / 2^12
               L10_hi = T1_hi * 2^20 % 2^32 + (T1_lo - T1_lo % 2^12) / 2^12
               L15_lo = T3_lo * 2^8 + (T3_hi - T3_hi % 2^24) / 2^24
               L15_hi = T3_hi * 2^8 + (T3_lo - T3_lo % 2^24) / 2^24
               L20_lo = T0_lo * 2^27 % 2^32 + (T0_hi - T0_hi % 2^5) / 2^5
               L20_hi = T0_hi * 2^27 % 2^32 + (T0_lo - T0_lo % 2^5) / 2^5
               L25_lo = (T2_lo - T2_lo % 2^25) / 2^25 + T2_hi * 2^7
               L25_hi = (T2_hi - T2_hi % 2^25) / 2^25 + T2_lo * 2^7
               D_lo = XOR(C5_lo, C2_lo * 2 + (C2_hi - C2_hi % 2^31) / 2^31)
               D_hi = XOR(C5_hi, C2_hi * 2 + (C2_lo - C2_lo % 2^31) / 2^31)
               T1_lo = XOR(D_lo, L06_lo)
               T1_hi = XOR(D_hi, L06_hi)
               T2_lo = XOR(D_lo, L11_lo)
               T2_hi = XOR(D_hi, L11_hi)
               T3_lo = XOR(D_lo, L16_lo)
               T3_hi = XOR(D_hi, L16_hi)
               T4_lo = XOR(D_lo, L21_lo)
               T4_hi = XOR(D_hi, L21_hi)
               L06_lo = T2_lo * 2^3 + (T2_hi - T2_hi % 2^29) / 2^29
               L06_hi = T2_hi * 2^3 + (T2_lo - T2_lo % 2^29) / 2^29
               L11_lo = T4_lo * 2^18 + (T4_hi - T4_hi % 2^14) / 2^14
               L11_hi = T4_hi * 2^18 + (T4_lo - T4_lo % 2^14) / 2^14
               L16_lo = (T1_lo - T1_lo % 2^28) / 2^28 + T1_hi * 2^4
               L16_hi = (T1_hi - T1_hi % 2^28) / 2^28 + T1_lo * 2^4
               L21_lo = (T3_lo - T3_lo % 2^23) / 2^23 + T3_hi * 2^9
               L21_hi = (T3_hi - T3_hi % 2^23) / 2^23 + T3_lo * 2^9
               L01_lo = XOR(D_lo, L01_lo)
               L01_hi = XOR(D_hi, L01_hi)
               L01_lo, L02_lo, L03_lo, L04_lo, L05_lo = XOR(L01_lo, AND(-1-L02_lo, L03_lo)), XOR(L02_lo, AND(-1-L03_lo, L04_lo)), XOR(L03_lo, AND(-1-L04_lo, L05_lo)), XOR(L04_lo, AND(-1-L05_lo, L01_lo)), XOR(L05_lo, AND(-1-L01_lo, L02_lo))
               L01_hi, L02_hi, L03_hi, L04_hi, L05_hi = XOR(L01_hi, AND(-1-L02_hi, L03_hi)), XOR(L02_hi, AND(-1-L03_hi, L04_hi)), XOR(L03_hi, AND(-1-L04_hi, L05_hi)), XOR(L04_hi, AND(-1-L05_hi, L01_hi)), XOR(L05_hi, AND(-1-L01_hi, L02_hi))
               L06_lo, L07_lo, L08_lo, L09_lo, L10_lo = XOR(L09_lo, AND(-1-L10_lo, L06_lo)), XOR(L10_lo, AND(-1-L06_lo, L07_lo)), XOR(L06_lo, AND(-1-L07_lo, L08_lo)), XOR(L07_lo, AND(-1-L08_lo, L09_lo)), XOR(L08_lo, AND(-1-L09_lo, L10_lo))
               L06_hi, L07_hi, L08_hi, L09_hi, L10_hi = XOR(L09_hi, AND(-1-L10_hi, L06_hi)), XOR(L10_hi, AND(-1-L06_hi, L07_hi)), XOR(L06_hi, AND(-1-L07_hi, L08_hi)), XOR(L07_hi, AND(-1-L08_hi, L09_hi)), XOR(L08_hi, AND(-1-L09_hi, L10_hi))
               L11_lo, L12_lo, L13_lo, L14_lo, L15_lo = XOR(L12_lo, AND(-1-L13_lo, L14_lo)), XOR(L13_lo, AND(-1-L14_lo, L15_lo)), XOR(L14_lo, AND(-1-L15_lo, L11_lo)), XOR(L15_lo, AND(-1-L11_lo, L12_lo)), XOR(L11_lo, AND(-1-L12_lo, L13_lo))
               L11_hi, L12_hi, L13_hi, L14_hi, L15_hi = XOR(L12_hi, AND(-1-L13_hi, L14_hi)), XOR(L13_hi, AND(-1-L14_hi, L15_hi)), XOR(L14_hi, AND(-1-L15_hi, L11_hi)), XOR(L15_hi, AND(-1-L11_hi, L12_hi)), XOR(L11_hi, AND(-1-L12_hi, L13_hi))
               L16_lo, L17_lo, L18_lo, L19_lo, L20_lo = XOR(L20_lo, AND(-1-L16_lo, L17_lo)), XOR(L16_lo, AND(-1-L17_lo, L18_lo)), XOR(L17_lo, AND(-1-L18_lo, L19_lo)), XOR(L18_lo, AND(-1-L19_lo, L20_lo)), XOR(L19_lo, AND(-1-L20_lo, L16_lo))
               L16_hi, L17_hi, L18_hi, L19_hi, L20_hi = XOR(L20_hi, AND(-1-L16_hi, L17_hi)), XOR(L16_hi, AND(-1-L17_hi, L18_hi)), XOR(L17_hi, AND(-1-L18_hi, L19_hi)), XOR(L18_hi, AND(-1-L19_hi, L20_hi)), XOR(L19_hi, AND(-1-L20_hi, L16_hi))
               L21_lo, L22_lo, L23_lo, L24_lo, L25_lo = XOR(L23_lo, AND(-1-L24_lo, L25_lo)), XOR(L24_lo, AND(-1-L25_lo, L21_lo)), XOR(L25_lo, AND(-1-L21_lo, L22_lo)), XOR(L21_lo, AND(-1-L22_lo, L23_lo)), XOR(L22_lo, AND(-1-L23_lo, L24_lo))
               L21_hi, L22_hi, L23_hi, L24_hi, L25_hi = XOR(L23_hi, AND(-1-L24_hi, L25_hi)), XOR(L24_hi, AND(-1-L25_hi, L21_hi)), XOR(L25_hi, AND(-1-L21_hi, L22_hi)), XOR(L21_hi, AND(-1-L22_hi, L23_hi)), XOR(L22_hi, AND(-1-L23_hi, L24_hi))
               L01_lo = XOR(L01_lo, RC_lo[round_idx])
               L01_hi = L01_hi + RC_hi[round_idx]
            end
            lanes[01], lanes[02], lanes[03], lanes[04], lanes[05], lanes[06], lanes[07], lanes[08], lanes[09], lanes[10], lanes[11],
            lanes[12], lanes[13], lanes[14], lanes[15], lanes[16], lanes[17], lanes[18], lanes[19], lanes[20], lanes[21], lanes[22], lanes[23], lanes[24],
            lanes[25], lanes[26], lanes[27], lanes[28], lanes[29], lanes[30], lanes[31], lanes[32], lanes[33], lanes[34], lanes[35], lanes[36], lanes[37],
            lanes[38], lanes[39], lanes[40], lanes[41], lanes[42], lanes[43], lanes[44], lanes[45], lanes[46], lanes[47], lanes[48], lanes[49], lanes[50] =
            L01_lo, L01_hi % 2^32, L02_lo, L02_hi, L03_lo, L03_hi, L04_lo, L04_hi, L05_lo, L05_hi, L06_lo, L06_hi, L07_lo, L07_hi, L08_lo, L08_hi,
            L09_lo, L09_hi, L10_lo, L10_hi, L11_lo, L11_hi, L12_lo, L12_hi, L13_lo, L13_hi, L14_lo, L14_hi, L15_lo, L15_hi, L16_lo, L16_hi,
            L17_lo, L17_hi, L18_lo, L18_hi, L19_lo, L19_hi, L20_lo, L20_hi, L21_lo, L21_hi, L22_lo, L22_hi, L23_lo, L23_hi, L24_lo, L24_hi, L25_lo, L25_hi
         end
      end

      local function keccak(block_size_in_bytes, digest_size_in_bytes, is_SHAKE, message)
         local tail, lanes = "", create_array_of_lanes()
         local result

         local function partial(message_part)
            if message_part then
               if tail then
                  local offs = 0
                  if tail ~= "" and #tail + #message_part >= block_size_in_bytes then
                     offs = block_size_in_bytes - #tail
                     keccak_feed(lanes, tail..sub(message_part, 1, offs), 0, block_size_in_bytes, block_size_in_bytes)
                     tail = ""
                  end
                  local size = #message_part - offs
                  local size_tail = size % block_size_in_bytes
                  keccak_feed(lanes, message_part, offs, size - size_tail, block_size_in_bytes)
                  tail = tail..sub(message_part, #message_part + 1 - size_tail)
                  return partial
               else
                  error("Adding more chunks is not allowed after receiving the result", 2)
               end
            else
               if tail then
                  local gap_start = is_SHAKE and 31 or 6
                  tail = tail..(#tail + 1 == block_size_in_bytes and char(gap_start + 128) or char(gap_start)..rep("\0", (-2 - #tail) % block_size_in_bytes).."\128")
                  keccak_feed(lanes, tail, 0, #tail, block_size_in_bytes)
                  tail = nil

                  local lanes_used = 0
                  local total_lanes = block_size_in_bytes / 4
                  local dwords = {}

                  local function get_next_dwords_of_digest(dwords_qty)
                     if lanes_used >= total_lanes then
                        keccak_feed(lanes, nil, 0, 1, 1)
                        lanes_used = 0
                     end
                     dwords_qty = floor(min(dwords_qty, total_lanes - lanes_used))
                     for j = 1, dwords_qty do
                        dwords[j] = format("%08x", lanes[lanes_used + j])
                     end
                     lanes_used = lanes_used + dwords_qty
                     return
                        gsub(concat(dwords, "", 1, dwords_qty), "(..)(..)(..)(..)", "%4%3%2%1"),
                        dwords_qty * 4
                  end

                  local parts = {}
                  local last_part, last_part_size = "", 0

                  local function get_next_part_of_digest(bytes_needed)
                     bytes_needed = bytes_needed or 1
                     if bytes_needed <= last_part_size then
                        last_part_size = last_part_size - bytes_needed
                        local part_size_in_nibbles = bytes_needed * 2
                        local result = sub(last_part, 1, part_size_in_nibbles)
                        last_part = sub(last_part, part_size_in_nibbles + 1)
                        return result
                     end
                     local parts_qty = 0
                     if last_part_size > 0 then
                        parts_qty = 1
                        parts[parts_qty] = last_part
                        bytes_needed = bytes_needed - last_part_size
                     end
                     while bytes_needed >= 4 do
                        local next_part, next_part_size = get_next_dwords_of_digest(bytes_needed / 4)
                        parts_qty = parts_qty + 1
                        parts[parts_qty] = next_part
                        bytes_needed = bytes_needed - next_part_size
                     end
                     if bytes_needed > 0 then
                        last_part, last_part_size = get_next_dwords_of_digest(1)
                        parts_qty = parts_qty + 1
                        parts[parts_qty] = get_next_part_of_digest(bytes_needed)
                     else
                        last_part, last_part_size = "", 0
                     end
                     return concat(parts, "", 1, parts_qty)
                  end

                  if digest_size_in_bytes < 0 then
                     result = get_next_part_of_digest
                  else
                     result = get_next_part_of_digest(digest_size_in_bytes)
                  end

               end
               return result
            end
         end

         if message then
            -- Actually perform calculations and return the SHA3 digest of a message
            return partial(message)()
         else
            -- Return function for chunk-by-chunk loading
            -- User should feed every chunk of input data as single argument to this function and finally get SHA3 digest by invoking this function without an argument
            return partial
         end

      end

      function SHA3_224(message)                       return keccak(144, 28, false, message)                  end
      function SHA3_256(message)                       return keccak(136, 32, false, message)                  end
      function SHA3_384(message)                       return keccak(104, 48, false, message)                  end
      function SHA3_512(message)                       return keccak( 72, 64, false, message)                  end
      function SHAKE128(digest_size_in_bytes, message) return keccak(168, digest_size_in_bytes, true, message) end
      function SHAKE256(digest_size_in_bytes, message) return keccak(136, digest_size_in_bytes, true, message) end

   end

   local entropy_counter = 0

   function GetEntropyCounter()
      return floor(entropy_counter)
   end

   local to_be_refined, to_be_refined_qty = {}, 0    -- buffer for entropy from user actions: 32-bit values, max 128 elements
   local refined, refined_qty = {}, 0                -- buffer for precalculated random numbers: 53-bit values, max 1024 elements
   local rnd_lanes = create_array_of_lanes()
   local RND = 0

   local function mix16(n)
      n = ((n + 0xDEAD) % 2^16 + 1) * 0xBEEF % (2^16 + 1) - 1
      local K53 = RND
      local L36 = K53 % 2^36
      RND = L36 * 126611 + (K53 - L36) * (505231 / 2^36) + n % 256 * 598352261448 + n * 2348539529
   end

   function perform_calculations()
      -- returns true if job's done
      if to_be_refined_qty >= 42 or refined_qty <= 1024 - 25 then
         local used_qty = min(42, to_be_refined_qty)
         for j = 1, used_qty do
            rnd_lanes[j] = rnd_lanes[j] + to_be_refined[j]
         end
         for j = 42 + 1, to_be_refined_qty do
            to_be_refined[j - 42] = to_be_refined[j]
         end
         to_be_refined_qty = to_be_refined_qty - used_qty
         keccak_feed(rnd_lanes, nil, 0, 1, 1)
         local lane_idx, queued_bits_qty, queued_bits = 0, 0, 0
         for j = 1, 25 do
            if queued_bits_qty < 21 then
               lane_idx = lane_idx + 1
               queued_bits = queued_bits * 2^32 + rnd_lanes[lane_idx]
               queued_bits_qty = queued_bits_qty + 32
            end
            local value53 = queued_bits % 2^21
            queued_bits = (queued_bits - value53) / 2^21
            queued_bits_qty = queued_bits_qty - 21
            lane_idx = lane_idx + 1
            value53 = rnd_lanes[lane_idx] * 2^21 + value53
            if refined_qty < 1024 then
               refined_qty = refined_qty + 1
               refined[refined_qty] = value53
            else
               local refined_idx = RND % refined_qty + 1
               local old_value53 = refined[refined_idx]
               refined[refined_idx] = XOR53(old_value53, value53)
               mix16(old_value53)
            end
         end
      else
         return true -- nothing to do
      end
   end
   _G.perform_calculations = perform_calculations

   local function refine32(value32)
      if to_be_refined_qty < 128 then
         to_be_refined_qty = to_be_refined_qty + 1
         to_be_refined[to_be_refined_qty] = value32 % 2^32
      else
         local idx = RND % to_be_refined_qty + 1
         to_be_refined[idx] = (to_be_refined[idx] + value32) % 2^32
      end
   end

   do
      local log = math.log
      local log4 = log(4)

      local function entropy_from_delta(delta)
         -- 'delta' is a difference between two sequential measurements of some integer parameter controlled by user: mouse position, current time
         -- all bits except 3 highest might be considered random
         delta = delta * delta / 64
         return delta < 1 and 0 or log(delta) / log4
      end

      local prev_x, prev_y, prev_t
      local enumerated = {MOUSE_BUTTON_PRESSED = 600, G_PRESSED = 500, M_PRESSED = 400, MOUSE_BUTTON_RELEASED = 300, G_RELEASED = 200, M_RELEASED = 100, lhc = 50}

      function update_internal_state(event, arg, family)
         local x, y, size_x, size_y, c, d = GetMousePositionInPixels()
         mix16(c)
         mix16(d)
         local t = GetRunningTime()
         mix16(t)
         if event then
            if arg then
               event = (enumerated[event] or 0) + (enumerated[family] or 0) + arg
               mix16(event)
            else
               for j = 1, #event, 2 do
                  local low, high = byte(event, j, j + 1)
                  local value16 = low + (high or 0) * 256
                  mix16(value16)
                  refine32(value16)
               end
               event, prev_x, prev_y, prev_t = 400, x, y, t
            end
            if event >= 400 then  -- only 'pressed' events increase entropy
               refine32(t * 2^10 + event)
               mix16(x)
               refine32(c * 2^16 + d)
               mix16(y)
               entropy_counter = entropy_counter + entropy_from_delta((t - prev_t) / 16)            -- timer's resolution is 16 ms
                  + ((x < 16 or x >= size_x - 16) and 0 or min(4, entropy_from_delta(x - prev_x)))  -- mouse x (mouse position modulo 16 pixels might be considered pure random except when near screen edge)
                  + ((y < 16 or y >= size_y - 16) and 0 or min(4, entropy_from_delta(y - prev_y)))  -- mouse y
               prev_x, prev_y, prev_t = x, y, t
            end
         end
      end
      _G.update_internal_state = update_internal_state

   end

   local function get_53_random_bits()
      if refined_qty == 0 then
         perform_calculations()  -- precalculate next 25 random numbers (53 bits each), it will take 30 ms
      end
      local refined_idx = RND % refined_qty + 1
      local value53 = refined[refined_idx]
      refined[refined_idx] = refined[refined_qty]
      refined_qty = refined_qty - 1
      mix16(value53)
      return value53
   end

   local cached_bits, cached_bits_qty = 0, 0

   local function get_random_bits(number_of_bits)
      local pwr_number_of_bits = 2^number_of_bits
      local result
      if number_of_bits <= cached_bits_qty then
         result = cached_bits % pwr_number_of_bits
         cached_bits = (cached_bits - result) / pwr_number_of_bits
      else
         local new_bits = get_53_random_bits()
         result = new_bits % pwr_number_of_bits
         cached_bits = (new_bits - result) / pwr_number_of_bits * 2^cached_bits_qty + cached_bits
         cached_bits_qty = 53 + cached_bits_qty
      end
      cached_bits_qty = cached_bits_qty - number_of_bits
      return result
   end

   local prev_width, prev_bits_in_factor, prev_k = 0

   function random(m, n)
      -- drop-in replacement for math.random()
      if m then
         if not n then
            m, n = 1, m
         end
         local k = n - m + 1
         if k < 1 or k > 2^53 then
            error("Invalid arguments for function 'random()'", 2)
         end
         local width, bits_in_factor, modk
         if k == prev_k then
            width, bits_in_factor = prev_width, prev_bits_in_factor
         else
            local pwr_prev_width = 2^prev_width
            if k > pwr_prev_width / 2 and k <= pwr_prev_width then
               width = prev_width
            else
               width = 53
               local width_low = -1
               repeat
                  local w = floor((width_low + width) / 2)
                  if k <= 2^w then
                     width = w
                  else
                     width_low = w
                  end
               until width - width_low == 1
               prev_width = width
            end
            bits_in_factor = 0
            local bits_in_factor_high = width + 1
            while bits_in_factor_high - bits_in_factor > 1 do
               local bits_in_new_factor = floor((bits_in_factor + bits_in_factor_high) / 2)
               if k % 2^bits_in_new_factor == 0 then
                  bits_in_factor = bits_in_new_factor
               else
                  bits_in_factor_high = bits_in_new_factor
               end
            end
            prev_k, prev_bits_in_factor = k, bits_in_factor
         end
         local factor, saved_bits, saved_bits_qty, pwr_saved_bits_qty = 2^bits_in_factor, 0, 0, 2^0
         k = k / factor
         width = width - bits_in_factor
         local pwr_width = 2^width
         local gap = pwr_width - k
         repeat
            modk = get_random_bits(width - saved_bits_qty) * pwr_saved_bits_qty + saved_bits
            local modk_in_range = modk < k
            if not modk_in_range then
               local interval = gap
               saved_bits = modk - k
               saved_bits_qty = width - 1
               pwr_saved_bits_qty = pwr_width / 2
               repeat
                  saved_bits_qty = saved_bits_qty - 1
                  pwr_saved_bits_qty = pwr_saved_bits_qty / 2
                  if pwr_saved_bits_qty <= interval then
                     if saved_bits < pwr_saved_bits_qty then
                        interval = nil
                     else
                        interval = interval - pwr_saved_bits_qty
                        saved_bits = saved_bits - pwr_saved_bits_qty
                     end
                  end
               until not interval
            end
         until modk_in_range
         return m + modk * factor + get_random_bits(bits_in_factor)
      else
         return get_53_random_bits() / 2^53
      end
   end

end

-- function Sleep() is reimplemented to automatically update internal state on every wake-up and to precalculate random numbers instead of long sleeping
local function Sleep(delay_ms)
   delay_ms = delay_ms or 5
   local start_time = GetRunningTime()
   local time_now, jobs_done = start_time
   while not jobs_done and time_now < start_time + delay_ms - 50 do
      jobs_done = perform_calculations()  -- 30 ms of useful job
      time_now = GetRunningTime()
   end
   delay_ms = delay_ms - (time_now - start_time)
   if delay_ms > 0 then
      Sleep_orig(delay_ms)
   end
   update_internal_state()  -- this invocation adds entropy to RNG (it's very fast)
end
_G.Sleep = Sleep

local Logitech_order = {"L", "R", "M"}
local Microsoft_order = {L=1, M=2, R=3, l=1, m=2, r=3}

local
   PressMouseButton_orig, ReleaseMouseButton_orig, PressAndReleaseMouseButton_orig, IsMouseButtonPressed_orig =
   PressMouseButton,      ReleaseMouseButton,      PressAndReleaseMouseButton,      IsMouseButtonPressed

-- These functions now accept strings "L", "R", "M" instead of button number
function PressMouseButton(button)
   PressMouseButton_orig(Microsoft_order[button] or button)
end

function ReleaseMouseButton(button)
   ReleaseMouseButton_orig(Microsoft_order[button] or button)
end

function PressAndReleaseMouseButton(button)
   PressAndReleaseMouseButton_orig(Microsoft_order[button] or button)
end

function IsMouseButtonPressed(button)
   return IsMouseButtonPressed_orig(Microsoft_order[button] or button)
end

if D_filename then

   local D_folder = extension_module_full_path:match"^(.-)[^\\/]*$"

   local function execute_Lua_script(filespec, err_message)
      local ok, result = pcall(dofile, filespec)
      if ok then
         return result
      elseif err_message then
         print(err_message..tostring(result))
      end
   end

   function Load_table_D()
      local table_d = execute_Lua_script(D_folder..D_filename, "ERROR loading table D from disk\n")
      PlayMacro"RUN_D_SAVER"
      return table_d
   end

   local out94
   local standard_Lua_tables = {}
   local pushed_digits = {}
   local pushed_string_chars = {[10] = 2, [13] = 3, [9] = 4}
   for c = 32, 119 do
      pushed_string_chars[c] = c - 26
   end
   local low_zeroes = {[0] = 11}
   do
      local pos = 1

      local function fill_low_zeroes(k)
         if k > 0 then
            k = k - 1
            fill_low_zeroes(k)
            low_zeroes[pos] = k
            pos = pos + 1
            fill_low_zeroes(k)
         end
      end

      fill_low_zeroes(11)
   end
   local list_of_known_values = {0/0, 0, -0, 1/0, -1/0, false, true}
   local known_value_to_list_index = {[1/0]=4, [-1/0]=5, [false]=6, [true]=7}
   local stack_of_tables_to_parse = {8}

   local function PushValue(val, tp)
      local prev_index
      if val ~= val then
         prev_index = 1
      elseif val == 0 then
         prev_index = 1/val < 0 and 3 or 2
      else
         prev_index = known_value_to_list_index[val]
      end
      local g, m, e
      if prev_index then
         g = 1
         m = prev_index - g
      else
         local known_index = #list_of_known_values + 1
         list_of_known_values[known_index] = val
         known_value_to_list_index[val] = known_index
         local string_to_send
         if tp == "number" then
            g = val < 0 and 0 or 2
            m, e = math.frexp((g - 1) * val)
            m = m * 2^53
            e = e - 53
            repeat
               local w = low_zeroes[m % 2048]
               m = m / 2^w
               e = e + w
            until w < 11
            m = (m - 1) / 2
         elseif tp == "string" then
            out94(90)
            string_to_send = val
         else
            local expr = standard_Lua_tables[val]
            if expr then
               out94(91)
               string_to_send = expr
            else
               out94(92)
               table.insert(stack_of_tables_to_parse, known_index)
            end
         end
         if string_to_send then
            for j = 1, #string_to_send do
               local c = byte(string_to_send, j)
               local b = pushed_string_chars[c]
               if not b then
                  c = (c - 120) % 256
                  b = c % 94
                  c = (c - b) / 94
                  out94(c)
               end
               out94(b)
            end
            out94(5)
         end
      end
      if g then
         g = g * 30
         if m < 22 then
            out94(g + m)
         else
            m = m - 22
            local L = 0
            repeat
               local mod = m % 94
               L = L + 1
               pushed_digits[L] = mod
               m = (m - mod) / 94 - 1
            until m < 0
            out94(g + 21 + L)
            for L = L, 1, -1 do
               out94(pushed_digits[L])
            end
         end
         if e then
            if e >= -17 and e <= 53 then
               out94(e + 17)
            else
               local m = e % 94
               e = (e - m) / 94
               out94(83 + e)
               out94(m)
            end
         end
      end
   end

   function Save_table_D()
      if type(D) ~= "table" then
         return
      end
      local prefix = "ESk"
      local prepared_messages = {}
      local current_message = {}
      local current_message_length = 0
      local chksum = 0

      local function flush_message()
         if current_message_length > 0 then
            for j = 1, current_message_length do
               current_message[j] = char(current_message[j])
            end
            prepared_messages[#prepared_messages + 1] = concat(current_message, "", 1, current_message_length)
            current_message_length = 0
         end
      end

      function out94(b)
         if current_message_length == 60000 then
            flush_message()
         end
         local L36 = chksum % 68719476736
         local H17 = (chksum - L36) / 68719476736
         chksum = L36 * 126611 + H17 * 505231 + b * 3083
         b = b == 5 and 0x7E or b + 0x20
         current_message_length = current_message_length + 1
         current_message[current_message_length] = b
      end

      local data_to_send = {D, D_filename}
      list_of_known_values[8] = data_to_send
      known_value_to_list_index[data_to_send] = 8
      repeat
         local tbl = list_of_known_values[table.remove(stack_of_tables_to_parse)]
         local next_arr_index = 1
         repeat
            local value = tbl[next_arr_index]
            local tp = type(value)
            local ok = tp == "number" or tp == "string" or tp == "table" or tp == "boolean"
            if ok then
               next_arr_index = next_arr_index + 1
               PushValue(value, tp)
            end
         until not ok
         out94(93)
         for key, value in pairs(tbl) do
            local tpk = type(key)
            if tpk == "string" or tpk == "table" or tpk == "boolean" or tpk == "number" and not (key > 0 and key < next_arr_index and key == floor(key)) then
               local tpv = type(value)
               if tpv == "number" or tpv == "string" or tpv == "table" or tpv == "boolean" then
                  PushValue(key, tpk)
                  PushValue(value, tpv)
               end
            end
         end
         out94(93)
      until #stack_of_tables_to_parse == 0
      local cs = chksum % 64847759419249
      for _ = 1, 7 do
         local b = cs % 94
         cs = (cs - b) / 94
         out94(b)
      end
      flush_message()
      for j, mes in ipairs(prepared_messages) do
         OutputDebugMessage(prefix..(j == 1 and "-" or j % 10)..mes.."\n")
      end
      OutputDebugMessage"\n"
   end

   local function enum_standard_tables(expr)
      local t = loadstring("return "..expr)()
      local old_expr = standard_Lua_tables[t]
      if not old_expr or #old_expr > #expr then
         standard_Lua_tables[t] = expr
         for key, value in pairs(t) do
            if type(key) == "string" and type(value) == "table" and not key:find'[%c"\\]' then
               local key_is_identifier = key:find"^[%a_][%w_]*$"
               enum_standard_tables(expr == "_G" and key_is_identifier and key or expr..(key_is_identifier and "."..key or '["'..key..'"]'))
            end
         end
      end
   end

   enum_standard_tables"debug.getmetatable''"
   enum_standard_tables"debug.getregistry()"
   enum_standard_tables"_G"
end

do
   -- Test SHA3 functions
   assert(SHA3_224("The quick brown fox jumps over the lazy dog") == "d15dadceaa4d5d7bb3b48f446421d542e08ad8887305e28d58335795")
   assert(SHA3_256("") == "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a")
   assert(SHA3_384("The quick brown fox jumps over the lazy dog") == "7063465e08a93bce31cd89d2e3ca8f602498696e253592ed26f07bf7e703cf328581e1471a7ba7ab119b1a9ebdf8be41")
   assert(SHAKE128(11, "The quick brown fox jumps over the lazy dog") == "f4202e3c5852f9182a0430")
   local generator = SHAKE128(-1, "The quick brown fox jumps over the lazy dog") -- negative digest size means 'return generator of infinite stream'
   assert(generator(5) == "f4202e3c58")  -- first 5 bytes
   assert(generator(4) == "52f9182a")    -- next 4 bytes, and so on...
end

_G.Logitech_order = Logitech_order
