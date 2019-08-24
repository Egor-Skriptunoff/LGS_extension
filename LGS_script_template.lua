---------------------------------------------------------------------------------------------
-- LGS_script_template.lua
---------------------------------------------------------------------------------------------
-- Version: 2019-08-24
-- Author:  Egor Skriptunoff
-- License: MIT License
--
-- This is a template for 'Logitech Gaming Software' script file.
-- Five additinal useful features are implemented here:
--   1. Function 'print()' now displays messages in the bottom window of the script editor, you can use it the same way as in original Lua;
--   2. 'random()' is an improved drop-in replacement for 'math.random()': better random numbers quality, no need to explicitly set the seed;
--   3. LGS standard functions 'PressMouseButton()', 'IsMouseButtonPressed()', etc. now accept letters "L", "R", "M" (instead of numbers) for the first 3 mouse buttons;
--   4. You can get and set mouse coordinates in pixels: 'GetMousePositionInPixels()', 'SetMousePositionInPixels()';
--   5. Global variable 'D' is a persistent Lua table: it is automatically saved to disk on profile exit and is automatically loaded from disk on profile start.
--
-- Prior to using this template for writing your own LGS scripts, you have to copy some additional files to your disk.
-- See details in 'How to install' section at the line# 200 in this file.
--
--
--
-- ------------------------------------------------------------------------------------------
--       FEATURE #1 - you can see the output of 'print()' in the LGS script editor
-- ------------------------------------------------------------------------------------------
--    print(...)
-- ------------------------------------------------------------------------------------------
-- Now this function displays messages in the bottom window of the script editor.
-- You can use 'print()' just like in standard Lua!
-- When using 'print()' instead of 'OutputLogMessage()', don't append "\n" to a message.
--
--
--
-- ------------------------------------------------------------------------------------------
--       FEATURE #2 - random numbers of very high quality
-- ------------------------------------------------------------------------------------------
--    random()               -- float    0 <= x < 1
--    random(n)              -- integer  1 <= x <= n
--    random(m, n)           -- integer  m <= x <= n
-- ------------------------------------------------------------------------------------------
-- This new function is a drop-in replacement for standard Lua function 'math.random()'.
-- It generates different sequences of random numbers on every profile load, so you don't need to set the seed explicitly before using PRNG (like you did with 'math.randomseed').
-- The random number generator adsorbs entropy from every event processed by 'OnEvent()'.
-- It takes into account everything: event type, button index, mouse position on the screen, current date and running time.
-- This entropy is converted by SHAKE128 (SHA3 hash function) into stream of pseudo-random bits.
-- That's why function 'random()' returns random numbers having excellent statistical properties.
-- Actually, after user clicked mouse buttons 100-200 times (no hurry please),
-- these pseudo-random numbers might be considered cryptographically strong.
--
-- The code example #2 (at the end of this file) shows how you could generate random alphanumeric strings.
-- It's fast and easy way to create new password of arbitrary length:
-- open text editor, press-and-release mouse button 7, then press-and-hold left mouse button until password length is enough.
--
-- ------------------------------------------------------------------------------------------
--    GetEntropyCounter()
-- ------------------------------------------------------------------------------------------
-- This function returns estimation of lower bound of number of random bits consumed by random numbers mixer
-- (wait until it reaches 256 prior to generating crypto keys)
--
-- ------------------------------------------------------------------------------------------
--    SHA3_224(message)
--    SHA3_256(message)
--    SHA3_384(message)
--    SHA3_512(message)
--    SHAKE128(digest_size_in_bytes, message)
--    SHAKE256(digest_size_in_bytes, message)
-- ------------------------------------------------------------------------------------------
-- SHA3 hash functions are available.
-- The first four (SHA3_224, SHA3_256, SHA3_384, SHA3_512) generate message digest of fixed length
-- The last two (SHAKE128, SHAKE256) generate message digest of potentially infinite length
-- Example: How to get SHA3-digest of your message:
--    SHA3_224("The quick brown fox jumps over the lazy dog") == "d15dadceaa4d5d7bb3b48f446421d542e08ad8887305e28d58335795"
--    SHAKE128(5, "The quick brown fox jumps over the lazy dog") == "f4202e3c58"
-- Example: How to convert your password into infinite sequence of very high quality random bytes (the same password will give the same sequence):
--    -- start the sequence, initialize it with your password
--    local get_hex_byte = SHAKE128(-1, "your password")
--    while .... do
--       -- get next number from the inifinite sequence
--       local next_random_byte  = tonumber(get_hex_byte(),  16)   -- integer  0 <= n <= 255
--       local next_random_dword = tonumber(get_hex_byte(4), 16)   -- integer  0 <= n <= 4294967295
--       -- how to construct floating point number  0 <= x < 1
--       local next_random_float = (tonumber(get_hex_byte(3), 16) % 2^21 * 2^32 + tonumber(get_hex_byte(4), 16)) / 2^53
--       ....
--    end
--
--
--
-- ------------------------------------------------------------------------------------------
--       FEATURE #3 - handy names for first three mouse buttons
-- ------------------------------------------------------------------------------------------
--    "L", "R", "M" are now names for the first three mouse buttons
-- ------------------------------------------------------------------------------------------
-- There is an unpleasant feature in LGS: Logitech and Microsoft enumerate mouse buttons differently.
-- In 'OnEvent("MOUSE_BUTTON_PRESSED", arg, "mouse")' parameter 'arg' uses Logitech order:
--    1=Left, 2=Right, 3=Middle, 4=Backward(X1), 5=Forward(X2), 6,7,8,...
-- In 'PressMouseButton(button)' and 'IsMouseButtonPressed(button)' parameter 'button' uses Microsoft order:
--    1=Left, 2=Middle, 3=Right, 4=X1(Backward), 5=X2(Forward)
-- As you see, Right and Middle buttons are swapped; this is very confusing.
-- To make your code more clear and less error-prone, try to avoid using numbers 1, 2 and 3.
-- Now you can use strings "L", "R", "M" for the first three mouse buttons in all the functions.
-- Two modifications have been made:
-- 1) The following standard LGS functions now accept strings "L", "R", "M" as its argument:
--       PressMouseButton(),
--       ReleaseMouseButton(),
--       PressAndReleaseMouseButton(),
--       IsMouseButtonPressed()
-- 2) 'mouse_button' variable was defined inside OnEvent() function body, it contains:
--       either string "L", "R", "M" (for the first three mouse buttons)
--       or number 4, 5, 6, 7, 8,... (for other mouse buttons).
-- These modifications don't break compatibility with your old code.
-- You can still use numbers if you want:
--    if event == "MOUSE_BUTTON_PRESSED" and arg == 2 then  -- 2 = RMB in Logitech order
--       repeat
--          ...
--          Sleep(50)
--       until not IsMouseButtonPressed(3)                  -- 3 = RMB in Microsoft order
-- But using "L"/"M"/"R" allows you to avoid inconsistent numbers:
--    if event == "MOUSE_BUTTON_PRESSED" and mouse_button == "R" then
--       repeat
--          ...
--          Sleep(50)
--       until not IsMouseButtonPressed("R")
--
--
--
-- ------------------------------------------------------------------------------------------
--       FEATURE #4 - Pixel-oriented functions for mouse coordinates
-- ------------------------------------------------------------------------------------------
--    GetMousePositionInPixels()
--    SetMousePositionInPixels(x,y)
-- ------------------------------------------------------------------------------------------
-- You can now get and set mouse cursor position IN PIXELS.
-- GetMousePositionInPixels() returns 6 values (probably you would need only the first two):
--    x_in_pixels,              -- integer from 0 to (screen_width-1)
--    y_in_pixels,              -- integer from 0 to (screen_height-1)
--    screen_width_in_pixels,   -- for example, 1920
--    screen_height_in_pixels,  -- for example, 1080
--    x_64K,                    -- normalized x coordinate 0..65535, this is the first  value returned by 'GetMousePosition()'
--    y_64K                     -- normalized y coordinate 0..65535, this is the second value returned by 'GetMousePosition()'

-- We already have standard LGS function 'MoveMouseRelative' which operates with distance in pixels, but it has two problems:
-- 1) 'MoveMouseRelative' is limited to narrow distance range: from -127 to +127 pixels from current position.
--    MoveMouseRelative(300, 300)  -- This invocation will work incorrectly because 300 is greater than 127
-- Now you can move mouse cursor farther than 127 pixels away using the new functions (instead of invoking 'MoveMouseRelative'):
--    local current_x, current_y = GetMousePositionInPixels()
--    SetMousePositionInPixels(current_x + 300, current_y + 300)
-- 2) The second problem with 'MoveMouseRelative' is that it works incorrectly when 'Acceleration (Enhance Pointer Precision)' flag
-- is checked in 'Pointer settings' tab (this is the third icon from the left at the bottom of the LGS application window):
-- the real distance does not equal to the number of pixels requested by 'MoveMouseRelative'.
-- The 'Acceleration' flag is set by default, so this problem hits every user who tryes to use 'MoveMouseRelative' in his scripts.
-- Meanwhile the new functions 'GetMousePositionInPixels' and 'SetMousePositionInPixels' work fine independently of 'Acceleration' flag.
--
-- Don't forget that you must wait a bit, for example Sleep(5), after simulating the following actions:
--    mouse move,
--    button press,
--    button release.
-- In other words, if you read 'GetMousePositionInPixels' right after invocation of 'SetMousePositionInPixels'
-- without a 'Sleep' in between, you will get old mouse coordinates instead of new ones.
-- This is because Windows needs some time to perform your simulation request.
-- Windows messaging system works slowly, there is nothing you can do to make the simulations instant.
--
--
-- Important note:
--    The script 'GS_script_template.lua' requires one second for initialization.
--    In other words, when this LGS profile is started, you will have to wait for 1 second before you're able to play.
-- Explanation:
--    Every time this profile is activated and every time when your game changes the screen resolution
--    the process of automatic determination of screen resolution is restarted
--    This is necessary for correct working of pixel-oriented mouse functions.
--    This process takes about one second.
--    During this second, mouse cursor will be programmatically moved some distance away from its current location.
--    This cursor movement might be a hindrance to use your mouse, so just wait until the cursor stops moving.
--
--
--
-- ------------------------------------------------------------------------------------------
--       FEATURE #5 - persistent table D
-- ------------------------------------------------------------------------------------------
-- Now you have special global variable 'D' which contains a Lua table; you can store your own data inside this table.
-- The variable 'D' is persistent: it is automatically saved to disk on profile exit and is automatically loaded from disk on profile start.
-- So, 'D' means 'Disk'.
-- You can accumulate some information in it across months and years (e.g the total number of times you run this game).
-- Table 'D' is allowed to contain only simple types: strings, numbers, booleans and nested tables.
-- Circular table refrences (non-tree tables) are allowed, for example: D.a={}; D.b={}; D.a.next=D.b; D.b.prev=D.a
-- Functions, userdatum and metatables will not be saved to disk (they will be silently replaced with nils), so don't store functions inside D.
D_filename = "D_for_profile_1.lua"
-- This is a name of the file where D table will be stored; replace 'profile_1' with your profile name (only English letters and digits).
-- This file is located in the 'C:\LGS extension' folder and contains human-readable data.
-- If two profiles have the same D_filename then they share the same D table.
-- You might want to make filenames different for every profile.
--
-- You can turn feature #5 off (for example, to avoid using untrusted EXE and DLL files on your computer).
-- To disable autosaving and autoloading of table 'D':
--    1) remove the line 'D_filename = ...' in this file (line# 184)
--    2) (optional) delete 4 files (LGS Debug Interceptor.dll, wluajit.exe, lua51.dll, D_SAVER.lua) from 'C:\LGS extension'
--    3) (optional) delete command 'RUN_D_SAVER' from 'Commands' pane in LGS application
--
--
--
--
-- ------------------------------------------------------------------------------------------
-- How to install:
-- ------------------------------------------------------------------------------------------
--   1) Create folder 'C:\LGS extension'
--   2) Copy the following 5 files into the folder 'C:\LGS extension'                                (SHA256 sum)
--          LGS_extension.lua           the main module                                              2D381537054CD37EF527919E291CAFBC5BEE6DD2B8DF16FAE9A18D01752A68B4
--          LGS Debug Interceptor.dll   downloaded from https://gondwanasoftware.net.au/lgsdi.shtml  53D88679B0432887A6C676F4683FFF316E23D869D6479FEDEEEF2E5A3E71D334
--          wluajit.exe                 windowless LuaJIT 2.1 x64 (doesn't create a console window)  E9C320E67020C2D85208AD449638BF1566C3ACE4CDA8024079B97C26833BF483
--          lua51.dll                   LuaJIT DLL                                                   112CB858E8448B0E2A6A6EA5CF9A7C25CFD45AC8A8C1A4BA85ECB04B20C2DE88
--          D_SAVER.lua                 external script which actually writes table D to the file    1E614F5F65473AFE172EE5FE9C25F11FA7D41B36F114CB02FC26D0A2540AACFD
--   3) Create new command:
--          Run 'Logitech Gaming Software' application
--          Open 'Customise buttons' tab
--          Select profile
--          In the left side you will see the 'Commands' pane (list of bindable actions such as keyboard keys, macros, etc), press the big 'plus' sign to add new command.
--          In the 'Command Editor', select the 'Shortcut' in the left pane
--          Set the 1st text field 'Name'              to 'RUN_D_SAVER'
--          Set the 2nd text field 'Enter a shortcut'  to 'wluajit.exe D_SAVER.lua'
--          Set the 3rd text field 'Working Directory' to 'C:\LGS extension'
--          Press 'OK' button to close the 'Command Editor'
--          Important note: DO NOT bind this new command to any button, this action must not be used by a human.
--
--
--
-- If you want to install it (or to move already installed) to another folder (instead of 'C:\LGS extension'),
-- please modify the folder name in two places:
--    1) in the line 'extension_module_full_path = ...' in this file (line #233)
--    2) in the properties of the command 'RUN_D_SAVER', the 'Working Directory' field
--
-- ------------------------------------------------------------------------------------------



-- Loading 'LGS extension' module
extension_module_full_path = [[C:\LGS extension\LGS_extension.lua]]
dofile(extension_module_full_path)


----------------------------------------------------------------------
-- FUNCTIONS AND VARIABLES
----------------------------------------------------------------------
-- insert all your functions and variables here
--



function OnEvent(event, arg, family)
   local mouse_button
   if event == "MOUSE_BUTTON_PRESSED" or event == "MOUSE_BUTTON_RELEASED" then
      mouse_button = Logitech_order[arg] or arg  -- convert 1,2,3 to "L","R","M"
   elseif event == "PROFILE_ACTIVATED" then
      ClearLog()
      EnablePrimaryMouseButtonEvents(true)
      update_internal_state(GetDate())  -- it takes about 1 second because of determining your screen resolution
      ----------------------------------------------------------------------
      -- CODE FOR PROFILE ACTIVATION
      ----------------------------------------------------------------------
      -- set your favourite mouse sensitivity
      SetMouseDPITableIndex(2)
      -- turn NumLock ON if it is currently OFF (to make numpad keys 0-9 usable in a game)
      if not IsKeyLockOn"NumLock" then
         PressAndReleaseKey"NumLock"
      end
      D = Load_table_D and Load_table_D() or {} -- load persistent table 'D'

      ------ this is example how to use the persistent table 'D':
      D.profile_run_cnt = (D.profile_run_cnt or 0) + 1
      D.profile_total_time_in_msec = D.profile_total_time_in_msec or 0
      print("Total number of times this profile was started = "..D.profile_run_cnt)
      local sec = math.floor(D.profile_total_time_in_msec / 1000)
      local min = math.floor(sec / 60)
      local hr = math.floor(min / 60)
      print("Total amount of time spent in this profile (hr:min:sec) = "..string.format("%d:%02d:%02d", hr, min % 60, sec % 60))
      ------ (end of example)

      -- insert your code here (initialize variables, display "Hello" on LCD screen, etc.)
      --
   end
   update_internal_state(event, arg, family)    -- this invocation adds entropy to RNG (it's very fast)
   ----------------------------------------------------------------------
   -- LOG THIS EVENT
   ----------------------------------------------------------------------
   -- print(
   --    "event = '"..event.."'",
   --    not mouse_button and "arg = "..arg or "mouse_button = "..(type(mouse_button) == "number" and mouse_button or "'"..mouse_button.."'"),
   --    "family = '"..family.."'"
   -- )
   --
   if event == "PROFILE_DEACTIVATED" then
      EnablePrimaryMouseButtonEvents(false)
      ----------------------------------------------------------------------
      -- CODE FOR PROFILE DEACTIVATION
      ----------------------------------------------------------------------
      -- insert your code here (display "Bye!" on LCD screen, etc.)
      -- please note that profile deactivation handler must not contain very long operations
      -- you have only one second before the script will be forcibly aborted
      --

      ------ this is example how to use the persistent table 'D':
      D.profile_total_time_in_msec = D.profile_total_time_in_msec + GetRunningTime()
      ------ (end of example)

      -- save persistent table 'D'
      if Save_table_D then Save_table_D() end
      return
   end

   ----------------------------------------------------------------------
   -- MOUSE EVENTS PROCESSING
   -- (you need it if you have Logitech G-series mouse)
   ----------------------------------------------------------------------
   if event == "MOUSE_BUTTON_PRESSED" and mouse_button == "L" then  -- left mouse button

      -- the following line is needed only for code example #2, see below (remove it when code example #2 is removed)
      if random_string_generator then random_string_generator() end
      -------------------

   end
   if event == "MOUSE_BUTTON_RELEASED" and mouse_button == "L" then -- left mouse button
   end

   if event == "MOUSE_BUTTON_PRESSED" and mouse_button == "R" then  -- right mouse button
   end
   if event == "MOUSE_BUTTON_RELEASED" and mouse_button == "R" then -- right mouse button
   end

   if event == "MOUSE_BUTTON_PRESSED" and mouse_button == "M" then  -- middle mouse button
   end
   if event == "MOUSE_BUTTON_RELEASED" and mouse_button == "M" then -- middle mouse button
   end

   if event == "MOUSE_BUTTON_PRESSED" and mouse_button == 4 then  -- 'backward' (X1) mouse button
   end
   if event == "MOUSE_BUTTON_RELEASED" and mouse_button == 4 then -- 'backward' (X1) mouse button
   end

   if event == "MOUSE_BUTTON_PRESSED" and mouse_button == 5 then  -- 'forward' (X2) mouse button
   end
   if event == "MOUSE_BUTTON_RELEASED" and mouse_button == 5 then -- 'forward' (X2) mouse button
   end

   if event == "MOUSE_BUTTON_PRESSED" and mouse_button == 6 then

      -- (this is code example #1, remove it after reading or testing)
      -- move mouse cursor along a circle
      local R = 50
      local x, y = GetMousePositionInPixels()
      x = x + R  -- (x,y) = center
      for j = 1, 90 do
         local angle = (2 * math.pi) * (j / 90)
         SetMousePositionInPixels(x - R * math.cos(angle), y - R * math.sin(angle))
         Sleep()
      end
      -- (end of code example #1)

   end
   if event == "MOUSE_BUTTON_RELEASED" and mouse_button == 6 then
   end

   if event == "MOUSE_BUTTON_PRESSED" and mouse_button == 7 then

      -- (this is code example #2, remove it after reading or testing)
      -- press-and-release mouse button7, then press-and-hold left mouse button (in your text editor) to simulate typing a random string 13 chars per second
      -- if you press Shift+button7 instead of button7, then random string will contain only decimal digits
      -- if you press Ctrl+button7 instead of button7, then random string will contain pairs of hexadecimal digits
      local alpha = "abcdefghijklmnopqrstuvwxyz"
      local is_ctrl = IsModifierPressed"Ctrl"
      local is_shift = IsModifierPressed"Shift"
      local all_chars = "0123456789"..(is_ctrl and alpha:sub(1, 6):upper() or is_shift and "" or alpha..alpha:upper())
      function random_string_generator()
         random_string_generator = nil
         repeat
            for _ = 1, is_ctrl and 2 or 1 do
               local k = random(#all_chars)
               local c = all_chars:sub(k, k)
               local shift_needed = c:find"%u"
               if shift_needed then
                  PressKey"LShift"
               end
               PressKey(c)
               Sleep()
               ReleaseKey(c)
               if shift_needed then
                  ReleaseKey"LShift"
               end
               Sleep()
            end
            Sleep(40)
         until not IsMouseButtonPressed("L")
      end
      -- (end of code example #2)

   end
   if event == "MOUSE_BUTTON_RELEASED" and mouse_button == 7 then
   end

   if event == "MOUSE_BUTTON_PRESSED" and mouse_button == 8 then

      -- (this is code example #3, remove it after reading or testing)
      -- print misc info (in the bottom panel of LGS script editor) on mouse button 8 press
      local t = math.floor(GetRunningTime() / 1000)
      print("profile running time = "..math.floor(t / 3600)..":"..string.sub(100 + math.floor(t / 60) % 60, -2)..":"..string.sub(100 + t % 60, -2))
      print("approximately "..GetEntropyCounter().." bits of entropy was received from button press events")
      local i = random(6)       -- integer 1 <= i <= 6
      print("random dice roll:", i)
      local b = random(0, 255)  -- integer 0 <= b <= 255
      print("random byte:", ("%02X"):format(b))
      local x = random()        -- float   0 <= x < 1
      print("random float:", x)
      local mouse_x, mouse_y, screen_width, screen_height = GetMousePositionInPixels()
      print("your screen size is "..screen_width.."x"..screen_height)
      print("your mouse cursor is at pixel ("..mouse_x..","..mouse_y..")")
      -- (end of code example #3)

   end
   if event == "MOUSE_BUTTON_RELEASED" and mouse_button == 8 then
   end

   ----------------------------------------------------------------------
   -- KEYBOARD AND LEFT-HANDED-CONTROLLER EVENTS PROCESSING
   -- (you need it if you have any Logitech device with keys G1, G2, ...)
   ----------------------------------------------------------------------
   if event == "G_PRESSED" and arg == 1 then    -- G1 key
   end
   if event == "G_RELEASED" and arg == 1 then   -- G1 key
   end

   if event == "G_PRESSED" and arg == 6 then    -- G6 key
   end
   if event == "G_RELEASED" and arg == 6 then   -- G6 key
   end


   if event == "M_PRESSED" and arg == 1 then    -- M1 key
   end
   if event == "M_RELEASED" and arg == 1 then   -- M1 key
   end

   if event == "M_PRESSED" and arg == 2 then    -- M2 key
   end
   if event == "M_RELEASED" and arg == 2 then   -- M2 key
   end

   if event == "M_PRESSED" and arg == 3 then    -- M3 key
   end
   if event == "M_RELEASED" and arg == 3 then   -- M3 key
   end


   ----------------------------------------------------------------------
   -- EXIT EVENT PROCESSING
   ----------------------------------------------------------------------
   -- After current event is processed, we have some time before the next event occurs, because a human can't press buttons very frequently
   -- So, it's a good time for 'background calculations'
   perform_calculations()    -- precalculate next 25 strong random numbers (only if needed), it will take about 30 ms on a modern PC
end
