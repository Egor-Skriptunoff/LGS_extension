# LGS_extension
`LGS_script_template.lua` is a template for writing your own Lua scripts in the Logitech Gaming Software programming environment.  
Both **LGS** and **GHUB** are supported.  
Five additional useful features are implemented here:

 1. Function `print()` now displays messages in the bottom window of the script editor, you can use it the same way as in original Lua;
 2. `random()` is an improved drop-in replacement for `math.random()`: better random numbers quality, no need to explicitly set the seed;
 3. LGS standard functions `PressMouseButton()`, `IsMouseButtonPressed()`, ... now accept strings `"L"`, `"R"`, `"M"` instead of numbers for the first 3 mouse buttons;
 4. You can get and set mouse coordinates in pixels: `GetMousePositionInPixels()`, `SetMousePositionInPixels()`;
 5. Global variable `D` in your Lua script is now a persistent Lua table: it is automatically saved to disk on profile exit and is automatically loaded from disk on profile start.

Prior to using this template for writing your own LGS scripts, you have to copy some additional files to your disk.  
See details in **How to install** section at the end of this README.

----

#### FEATURE #1: You can see the output of `print()` in the LGS script editor
```lua
print(...)
```
This function is reimplemented to display messages in the bottom window of the script editor.  
You can use `print()` just like you do in standard Lua!  
When using `print()` instead of `OutputLogMessage()`, don't append `"\n"` to a message.

----

#### FEATURE #2: Random numbers of very high quality
```lua
random()               -- float    0 <= x < 1
random(n)              -- integer  1 <= x <= n
random(m, n)           -- integer  m <= x <= n
```
This new function is a drop-in replacement for standard Lua function `math.random()`.  
It generates different sequences of random numbers on every profile load, so you don't need to set the seed explicitly.  
The random number generator absorbs entropy from every event processed by `OnEvent()`.  
It takes into account everything: event type, button index, mouse position on the screen, current date and running time.  
This entropy is converted by SHAKE128 (SHA3 hash function) into a stream of pseudo-random bits.  
That's why function `random()` returns random numbers having excellent statistical properties.  
Actually, after user clicked mouse buttons 100-200 times (no hurry please), these pseudo-random numbers might be considered cryptographically strong.  

The code example #1 at the end of `LGS_script_template.lua` shows how you could simulate typing random alphanumeric string in Lua script.  
A user should open a text editor and press-and-hold middle mouse button until the string is long enough.  
This is the easiest way to generate a strong password.

```lua
GetEntropyCounter()
```
This function returns estimation of lower bound of number of random bits consumed by random numbers mixer.  
Wait until it reaches 256 bits prior to generating crypto keys.

```lua
SHA3_224(message)
SHA3_256(message)
SHA3_384(message)
SHA3_512(message)
SHAKE128(digest_size_in_bytes, message)
SHAKE256(digest_size_in_bytes, message)
```
I don't know why you might need them, but SHA3 hash functions are available :-)  
The first four `SHA3_224`, `SHA3_256`, `SHA3_384`, `SHA3_512` generate message digest of fixed length.  
The last two `SHAKE128`, `SHAKE256` generate message digest of potentially infinite length.  

Example: How to get SHA3-digest of your message:
```lua
SHA3_224("The quick brown fox jumps over the lazy dog") == "d15dadceaa4d5d7bb3b48f446421d542e08ad8887305e28d58335795"
SHAKE128(5, "The quick brown fox jumps over the lazy dog") == "f4202e3c58"
```
Example: How to convert your short password into infinite sequence of very high quality pseudo-random bytes:  
```lua
-- start the sequence, initialize it with your password
local get_hex_byte = SHAKE128(-1, "your password")
while .... do
   -- get next byte from the inifinite sequence of pseudo-random bytes
   local next_random_byte  = tonumber(get_hex_byte(),  16)   -- integer  0 <= n <= 255
   -- get next dword
   local next_random_dword = tonumber(get_hex_byte(4), 16)   -- integer  0 <= n <= 4294967295
   -- get next floating point number 0 <= x < 1
   local next_random_double = (tonumber(get_hex_byte(3), 16) % 2^21 * 2^32 + tonumber(get_hex_byte(4), 16)) / 2^53
   ....
end
```
----

#### FEATURE #3: Handy names for the first three mouse buttons
`"L"`, `"R"`, `"M"` are new names for the first three mouse buttons.  
As you might have noticed, there is an unpleasant feature in LGS: Logitech and Microsoft enumerate mouse buttons differently.  
In `OnEvent("MOUSE_BUTTON_PRESSED", arg, "mouse")` the parameter `arg` uses Logitech order:  
```
1=Left, 2=Right, 3=Middle, 4=Backward(X1), 5=Forward(X2), 6, 7, 8,...
```   
In `PressMouseButton(button)` and `IsMouseButtonPressed(button)` the parameter `button` uses Microsoft order:  
```
1=Left, 2=Middle, 3=Right, 4=X1(Backward), 5=X2(Forward)
```
As you see, Right and Middle buttons are swapped; this is very confusing.  
To make your code more clear and less error-prone, try to avoid using numbers `1`, `2` and `3`.   
Now you can use strings `"L"`, `"R"`, `"M"` for the first three mouse buttons in all the functions.  
Two modifications have been made:  
 1. The following standard LGS functions now accept strings `"L"`, `"R"`, `"M"` as its argument: `PressMouseButton()`, `ReleaseMouseButton()`, `PressAndReleaseMouseButton()`, `IsMouseButtonPressed()`
 2. `mouse_button` variable was defined inside `OnEvent()` function body, it contains:
     - either string `"L"`, `"R"`, `"M"` (for the first three mouse buttons)
     - or number `4`, `5`, `6`, `7`, `8`,... (for other mouse buttons).
   
These modifications don't break compatibility with your old code.  
You can still use numbers if you want:  
```lua
if event == "MOUSE_BUTTON_PRESSED" and arg == 2 then  -- 2 = RMB in Logitech order
   repeat
      ...
      Sleep(50)
   until not IsMouseButtonPressed(3)                  -- 3 = RMB in Microsoft order
```
But using `"L"`/`"M"`/`"R"` allows you to avoid inconsistent numbers:
```lua
if event == "MOUSE_BUTTON_PRESSED" and mouse_button == "R" then
   repeat
      ...
      Sleep(50)
   until not IsMouseButtonPressed("R")
```

----

#### FEATURE #4: Pixel-oriented functions for mouse coordinates
```lua
GetMousePositionInPixels()
SetMousePositionInPixels(x,y)
```
You can now get and set mouse cursor position **in pixels**.  
`GetMousePositionInPixels()` returns 6 values (you would probably need only the first two):
```
x_in_pixels,              -- integer from 0 to (screen_width-1)
y_in_pixels,              -- integer from 0 to (screen_height-1)
screen_width_in_pixels,   -- for example, 1920
screen_height_in_pixels,  -- for example, 1080
x_64K,                    -- normalized x coordinate 0..65535, this is the first  value returned by 'GetMousePosition()'
y_64K                     -- normalized y coordinate 0..65535, this is the second value returned by 'GetMousePosition()'
```
We already have standard LGS function `MoveMouseRelative()` which operates with distance in pixels, but it has two problems.  
The first problem: `MoveMouseRelative` is limited to narrow distance range: from -127 to +127 pixels from the current position.
``` 
MoveMouseRelative(300, 300)  -- This invocation will work incorrectly because 300 is greater than 127
```
Now you can move mouse cursor farther than 127 pixels away using the new functions:
```lua
local current_x, current_y = GetMousePositionInPixels()
SetMousePositionInPixels(current_x + 300, current_y + 300)
```
The second problem with `MoveMouseRelative` is that it works incorrectly when **Acceleration (Enhance Pointer Precision)** flag is checked in **Pointer settings** tab (this is the third icon from the left at the bottom of the LGS application window): the real distance (how far the mouse pointer moves after you have invoked the function) does not equal to the number of pixels requested in the arguments of `MoveMouseRelative`.  
The **Acceleration** flag is set by default, so this problem hits every user who tries to use `MoveMouseRelative` in his scripts.  
Meanwhile the new functions `GetMousePositionInPixels` and `SetMousePositionInPixels` work fine independently of **Acceleration** flag.

*Important note:*  
Don't forget that you must wait a bit, for example `Sleep(10)`, after simulating any of the following actions:

 - mouse move,
 - button press,
 - button release.
 
In other words, if you read `GetMousePositionInPixels` right after invocation of `SetMousePositionInPixels` without a `Sleep` in between, you will get the old mouse coordinates instead of the new ones.  
This is because Windows needs some time to perform your simulation request.  
Windows messaging system works slowly, there is nothing you can do to make the simulations instant.

*Important note:*  
The script `LGS_script_template.lua` requires **one second** for initialization.  
In other words, when this LGS profile is started, you will have to wait for 1 second before you're able to play.  
Explanation:  
Every time this profile is activated (and every time when your game changes the screen resolution) the process of automatic determination of screen resolution is restarted. This is necessary for correct working of pixel-oriented mouse functions.  
This process takes about one second. During this second, mouse cursor will be programmatically moved some distance away from its current location. This cursor movement might be a hindrance to use your mouse, so just wait until the cursor stops moving.

---

#### FEATURE #5: Persistent table D
Now you have special global variable `D` which contains a Lua table; you can store your own data inside this table.  
The variable `D` is persistent: it is automatically saved to disk on profile exit and is automatically loaded from disk on profile start.  
So, **D** means **Disk**.  
You can accumulate some information in table `D` across years of playing (e.g the total number of times you run this game).  
Table `D` is allowed to contain only simple types: strings, numbers, booleans and nested tables.  
Circular table refrences (non-tree tables) are allowed, for example: `D.a={}; D.b={}; D.a.next=D.b; D.b.prev=D.a`  
Functions, userdatum and metatables will not be saved to disk (they will be silently replaced with nils), so don't store functions inside `D`.  

The table `D` data will be stored in a file; you should give it a name.  
By default the line #187 in `LGS_script_template.lua` looks like the following:
```lua
D_filename = "D_for_profile_1.lua"
```
Replace `profile_1` with current profile name (use only English letters and digits).  
This file will be located in the `C:\LGS extension` folder and will contain human-readable data.  
If two profiles have the same `D_filename` then they share the same `D` table, that's why you might want to make `D_filename` values different for every profile.  

To avoid using my .EXE and .DLL files on your computer, you can turn **feature #5** off:  
 1. Remove the assignment `D_filename = "..."` from `LGS_script_template.lua` line #187
 2. (optional) Delete all the files from the folder `C:\LGS extension` except the main module `LGS_extension.lua`
 3. (optional) Delete the command **RUN_D_SAVER** from LGS/GHUB application.

----

# How to install:

#### Step 1. Create folder `C:\LGS extension`

#### Step 2. Copy the following 5 files into the folder `C:\LGS extension`
 ```
Filename            Description                                                  SHA256 sums of binary files
--------            -----------                                                  ---------------------------
LGS_extension.lua   the main module
D_SAVER.lua         external script which actually writes table D to the file
wluajit.exe         windowless LuaJIT 2.1 x64 (doesn't create a console window)  E9C320E67020C2D85208AD449638BF1566C3ACE4CDA8024079B97C26833BF483
lua51.dll           LuaJIT DLL                                                   112CB858E8448B0E2A6A6EA5CF9A7C25CFD45AC8A8C1A4BA85ECB04B20C2DE88
luajit.exe          LuaJIT 2.1 x64 (does create a console window)                0F593458024EB62035EC41342FC12DAA26108639E68D6236DCF3048E527AE6E5
```
#### Step 3. Create new command
The instructions are different for LGS and GHUB:  
  * In **LGS**:
    - Run **Logitech Gaming Software** application
    - Open **Customise buttons** tab
    - Select profile
    - In the left side you will see the **Commands** pane (list of bindable actions such as keyboard keys, macros, etc), press the big plus sign to add new command
    - In the **Command Editor**, select the **Shortcut** in the left pane
    - Set the 1st text field **Name** to `RUN_D_SAVER`
    - Set the 2nd text field **Enter a shortcut** to `wluajit.exe D_SAVER.lua`
    - Set the 3rd text field **Working Directory** to `C:\LGS extension`
    - Press **OK** button to close the **Command Editor**
    - *Important note:*  
DO NOT bind the **RUN_D_SAVER** command to any button, this command must not be invoked by a human.
  * In **GHUB**:
    - Run **G HUB** application
    - Click on the mouse picture to open **Gear page**
    - Select **Assignments** icon (plus-inside-square) at the left edge
    - Select **SYSTEM** tab (it's the last one in the row of tabs: _COMMANDS-KEYS-ACTIONS-MACROS-SYSTEM_)
    - Click **ADD APPLICATION** under the **Launch Application** list, a file selection dialogue window will appear
    - Find the file `C:\LGS extension\luajit.exe` and click it
    - Click **ADD ARGUMENTS** and replace `New argument` with `D_SAVER.lua`
    - Click **SAVE**
    - Select **MACROS** tab (in the row of tabs: _COMMANDS-KEYS-ACTIONS-MACROS-SYSTEM_)
    - Click **CREATE NEW MACRO**
    - Set `RUN_D_SAVER` as macro name
    - Select **NO REPEAT** type of macro
    - Click **START NOW**
    - Click **LAUNCH APPLICATION**
    - Select **luajit**
    - Click **SAVE**
    - Select **SYSTEM** tab
    - Click **luajit** in the **Launch Application** list
    - Click **DELETE**
    - Click **YES** to confirm
    - *Important note:*  
Now you have the **RUN_D_SAVER** macro on the **MACROS** tab.  
NEVER manually assign this macro to any button, this macro must not be invoked by a human.

#### Step 4. Copy the content of `LGS_script_template.lua` into LGS/GHUB Lua script editor.

----

### How to move the folder `C:\LGS extension` to another location
 - Move all the files from `C:\LGS extension` to your new folder.
 - Change the path in the assignment `extension_module_full_path = ...` in `LGS_script_template.lua` line #280.  
_Please note that LGS and GHUB don't allow you to use non-English letters in string literals in your Lua script.  
All symbols beyond 7-bit ASCII in your folder path must be converted to their Windows ANSI codes.  
Example: `D:\Папка\LGS` should be written as either `path = "D:\\\207\224\239\234\224\\LGS"` or  
`path = [[D:\]]..string.char(207,224,239,234,224)..[[\LGS]]`._
 - Modify the command **RUN_D_SAVER**:
   * In **LGS**:
     - Edit the command **RUN_D_SAVER** and write your new folder path to the 3rd text field **Working Directory**
   * In **GHUB**:
     - Select **MACROS** tab (in the row of tabs: _COMMANDS-KEYS-ACTIONS-MACROS-SYSTEM_)
     - Click **RUN_D_SAVER** to enter macro editor
     - Click **MACRO OPTIONS** in the top right corner
     - Click **DELETE THIS MACRO**
     - Click **YES** to confirm
     - Create the command **RUN_D_SAVER** again: follow the instructions from _"Step 3. Create new command"_ in _"How to install"_ section above, but use your new folder path instead of `C:\LGS extension`

----

## Known issue:

#### LGS does not generate `PROFILE_DEACTIVATED` event on Windows shutdown, so table `D` on disk is not updated for the last profile being active before turning your computer off (usually it's the "Default profile").

Example:

1. You're turning your computer on:  
   - **Default profile** is activated.
2. You're starting a game:  
   - **Default profile** is deactivated, table `D` for **Default profile** is saved to disk in its `PROFILE_DEACTIVATED` event handler,
   - **Your Game** profile is activated.
3. You're exiting the game:  
   - **Your Game** profile is deactivated, table `D` for **Your Game** is saved to disk in its `PROFILE_DEACTIVATED` event handler,
   - **Default profile** is activated.
4. You're shutting down Windows:  
   - **Default profile** should be deactivated, but `PROFILE_DEACTIVATED` event is not generated (bug in LGS), so table `D` for **Default profile** is not updated on disk.

This is LGS-only issue.  
GHUB is OK, table `D` is updated always.

