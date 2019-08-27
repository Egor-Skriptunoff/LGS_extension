---------------------------------------------------------------------------------------------
-- D_SAVER.lua
---------------------------------------------------------------------------------------------
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local type = type
local floor = math.floor
local math_log = math.log
local max = math.max
local min = math.min
local byte = string.byte
local char = string.char
local format = string.format
local gsub = string.gsub
local match = string.match
local rep = string.rep
local sub = string.sub
local table_sort = table.sort
local table_concat = table.concat

local ffi = require"ffi"
local ffi_string = ffi.string

-- see https://gondwanasoftware.net.au/lgsdi.shtml about how to use "LGS Debug Interceptor"
ffi.cdef[[
typedef int (__stdcall *MessageCallbackType)(const char* message);
typedef void (__stdcall *StatusCallbackType)(int status);
int LGSDIConnectCallback(bool async, MessageCallbackType messageCallback, StatusCallbackType statusCallback);
]]

local lgsdi = ffi.load"LGS Debug Interceptor"

local arrived_data = {}
local message_no
local prefix = "ESk"

local function messageCallback(message)
   -- message contains only bytes 0x20..0x7E, without percent (0x25), this string was sent by 'OutputDebugMessage()' in LGS script
   message = ffi_string(message)
   if sub(message, 1, 4) == prefix..(message_no or "-") then
      message_no = ((message_no or 1) + 1) % 10
      arrived_data[#arrived_data + 1] = message
      return 0
   else
      if message ~= "\n" then
         arrived_data = nil
      end
      return 1
   end
end

-- Receive all messages through callback function
lgsdi.LGSDIConnectCallback(false, messageCallback, function() end)

-- process arrived data
local queue
if arrived_data then
   queue = {}
   for k = 1, #arrived_data do
      local message = arrived_data[k]
      arrived_data[k] = nil
      for j = 5, #message - 1 do
         local b = byte(message, j)
         b = b == 0x7E and 5 or b - 0x20
         if b >= 0 and b < 94 then
            queue[#queue + 1] = b
         else
            queue = nil
            break
         end
      end
      if not queue then
         break
      end
   end
   arrived_data = nil
end
if queue then
   -- Calculating checksum
   local chksum = 0
   for pos = 1, #queue - 7 do
      local b = queue[pos]
      local L36 = chksum % 68719476736  -- 2^36
      local H17 = (chksum - L36) / 68719476736
      chksum = L36 * 126611 + H17 * 505231 + b * 3083
   end
   local tail7 = 0
   for pos = #queue, #queue - 6, -1 do
      local b = queue[pos]
      tail7 = tail7 * 94 + b
   end
   if tail7 ~= chksum % 64847759419249 then   -- max prime below 94^7
      queue = nil
   end
end
if queue then
   local pos = 0
   local popped_string = {}
   local popped_string_special_chars = {nil, 10, 13, 9}

   local function in94()
      pos = pos + 1
      return queue[pos]
   end

   local function PopInt52OrSymbol()
      local b = in94()
      if b < 3 * 30 then
         local value52 = b % 30
         local group_no = (b - value52) / 30
         if value52 >= 22 then
            local L = value52 - 21
            value52 = 0
            for j = 1, L do
               b = in94()
               value52 = value52 * 94 + b + 1
            end
            value52 = value52 + 21
         end
         return group_no, value52 + 1
      else
         return nil, b - 3 * 30
      end
   end

   local function PopInt11()
      local b = in94()
      if b < 71 then
         return b - 17
      else
         local c = in94()
         return (b - 83) * 94 + c
      end
   end

   local function PopString()
      local str_length = 0
      repeat
         local b = in94()
         if b < 2 then
            local c = in94()
            b = (b * 94 + c + 120) % 256
         elseif b > 5 then
            b = b + 26
         else
            b = popped_string_special_chars[b]
         end
         if b then
            str_length = str_length + 1
            popped_string[str_length] = b
         end
      until not b
      local aggr_cnt = 0
      for j = 1, str_length, 100 do
         aggr_cnt = aggr_cnt + 1
         popped_string[aggr_cnt] = char(unpack(popped_string, j, min(str_length, j + 99)))
      end
      return table_concat(popped_string, "", 1, aggr_cnt)
   end

   local received_data = {}
   local serialized_objects = {}
   local list_of_known_values = {0/0, 0, -0, 1/0, -1/0, false, true, received_data}
   local stack_of_tables_to_parse = {8}      -- contains indexes of non-parsed tables in array_of_known_values
   local end_of_list = {}

   local function PopValue()
      local group_no, num = PopInt52OrSymbol()
      if group_no == 1 then
         return list_of_known_values[num]
      elseif not group_no and num == 3 then
         return end_of_list
      else
         local value
         if group_no then
            value = (group_no - 1) * (num * 2 - 1) * 2^PopInt11()
         elseif num == 0 then
            value = PopString()
         else
            value = {}
            if num == 1 then
               serialized_objects[value] = PopString()
            else  --  num == 2
               table.insert(stack_of_tables_to_parse, #list_of_known_values + 1)
            end
         end
         table.insert(list_of_known_values, value)
         return value
      end
   end

   repeat
      local tbl = list_of_known_values[table.remove(stack_of_tables_to_parse)]
      repeat
         local value = PopValue()
         local finished = value == end_of_list
         if not finished then
            table.insert(tbl, value)
         end
      until finished
      repeat
         local key = PopValue()
         local finished = key == end_of_list
         if not finished then
            local value = PopValue()
            tbl[key] = value
         end
      until finished
   until #stack_of_tables_to_parse == 0
   queue = pos + 7 == #queue and {received_data = received_data, serialized_objects = serialized_objects}
end
if queue then

   local D = queue.received_data[1]
   local D_filename = queue.received_data[2]
   local already_serialized = queue.serialized_objects

   -- serializing table D

   local Lua_keywords = { -- for 5.1
      ["and"]=1, ["break"]=1, ["do"]=1, ["else"]=1, ["elseif"]=1, ["end"]=1, ["false"]=1, ["for"]=1, ["function"]=1, ["if"]=1,
      ["in"]=1, ["local"]=1, ["nil"]=1, ["not"]=1, ["or"]=1, ["repeat"]=1, ["return"]=1, ["then"]=1, ["true"]=1, ["until"]=1, ["while"]=1
   }

   local function boolean_ordering_function(a, b)
      return not a and b
   end

   local function alphanumeric_ordering_function(a, b)
      local pa, pb, lena, lenb = 1, 1, #a, #b
      local last_str_a, last_str_b = 1, 1
      local pna, pnb

      while pa <= lena and pb <= lenb do
         local ca, cb = byte(a, pa), byte(b, pb)
         local da = ca >= 48 and ca <= 57
         local db = cb >= 48 and cb <= 57
         if not da and not db then
            if ca ~= cb then
               return ca < cb
            end
            pa, pb = pa + 1, pb + 1
         elseif da ~= db then
            return db
         else
            pna, pa = match(a, "0*()%d*()", pa)
            pnb, pb = match(b, "0*()%d*()", pb)
            local nlamb = (pa - pna) - (pb - pnb)
            if nlamb ~= 0 then
               return nlamb < 0
            end
            local na, nb = sub(a, pna, pa - 1), sub(b, pnb, pb - 1)
            if na ~= nb then
               return na < nb
            end
            repeat
               na = match(a, "^%.?%d", pa) or ""
               nb = match(b, "^%.?%d", pb) or ""
               if na ~= nb then
                  return na < nb
               end
               pa = pa + #na
               pb = pb + #nb
            until na == ""
            last_str_a, last_str_b = pa, pb
         end
      end

      local lamb = (lena - pa) - (lenb - pb)
      return lamb < 0 or lamb == 0 and a < b
   end


   local ser_simple_type
   do

      local function get_shortest_string(str1, str2)
         return str1 and (str2 and #str2 < #str1 and str2 or str1) or str2
      end

      local function fraction_to_string(N, D, k)
         if (D ~= 1 or k ~= 0) and k >= -1074 and k <= 1023 and N < 2^20 and D < 2^20 then
            local div, denom = N ~= D and k < 0 and k >= -1023, format("%.f", D)
            return
                  N == 1 and D ~= 1 and k ~= 0 and "2^"..k.." / "..denom
               or
                  (N == D and "" or format("%.f", N)..(D == 1 and "" or "/"..denom)..(k == 0 and "" or div and " / " or " * "))
                  ..(k == 0 and "" or "2^"..(div and -k or k))
         end
      end

      local function serialize_number(float_number)
         if float_number ~= float_number then
            return "0/0"
         end
         if float_number == 0 then
            return 1/float_number < 0 and "-0" or "0"
         end
         local shortest
         local sign, positive_float = "", float_number
         if positive_float < 0 then
            sign, positive_float = "-", -positive_float
         end
         if positive_float == 1/0 then
            shortest = "1/0"
         else
            local integer = positive_float < 2^53 and floor(positive_float) == positive_float and format("%.f", positive_float)
            shortest = integer
            local mant_int, mant_frac, exponent = match(format("%.17e", positive_float), "^(%d)%D+(%d+)e([-+]%d+)$")
            local mantissa, trailing_zeroes = match(mant_int..mant_frac, "^([^0].-)(0*)$")
            exponent = tonumber(exponent) + #trailing_zeroes - #mant_frac
            --assert(tonumber(mantissa.."e"..exponent) == positive_float)
            repeat
               local truncated_mantissa, incr = match(mantissa, "^(.*)(.)$")
               incr = tonumber(incr) > 4
               for _ = 1, 2 do
                  local new_exponent, new_mantissa = exponent + 1
                  if incr then
                     local head, digit, tail = match("0"..truncated_mantissa, "^(.-)(.)(9*)$")
                     new_mantissa, incr = match(head, "^0?(.*)$")..char(byte(digit) + 1)
                     new_exponent = new_exponent + #tail
                  else
                     new_mantissa, incr = match(truncated_mantissa, "^(.-)(0*)$")
                     new_exponent = new_exponent + #incr
                  end
                  if tonumber(new_mantissa.."e"..new_exponent) == positive_float then
                     mantissa, exponent, truncated_mantissa = new_mantissa, new_exponent
                     break
                  end
               end
            until truncated_mantissa
            local good_fixed_point, scientific
            local mm9 = #mantissa - 9
            for shift = min(-6, mm9), max(mm9 + 15, 9) do
               local e = exponent + shift
               local exp = e ~= 0 and format("e%+04d", e) or ""
               local str =
                  shift < 1 and mantissa..rep("0", -shift)..(e == 0 and "" or exp)
                  or shift < #mantissa and sub(mantissa, 1, -shift-1).."."..sub(mantissa, -shift)..exp
                  or "0."..rep("0", shift - #mantissa)..mantissa..exp
               scientific = get_shortest_string(scientific, shift == mm9 + 8 and str)
               shortest = shortest or e == 0 and shift > 0 and str
               good_fixed_point = good_fixed_point or e == 0 and shift >= mm9 and shift <= 9 and mm9 <= 0 and str
            end
            if good_fixed_point then
               shortest = get_shortest_string(integer, good_fixed_point)
            else
               shortest = get_shortest_string(shortest, scientific)
               local k = floor(math_log(positive_float, 2) + 0.5)
               local e = 2^k
               if positive_float < e then
                  k = k - 1
                  e = 2^k
               end
               local x, pn, n, pd, d, N, D = positive_float / e - 1, 0, 1, 1, 0
               repeat
                  local Q, q = x + 0.5, x - x % 1
                  Q = Q - Q % 1
                  pd, d, D = d, q*d + pd, Q*d + pd
                  pn, n, N = n, q*n + pn, Q*n + pn + D
                  if N >= 2^20 then
                     break
                  elseif N/D * e == positive_float then
                     while k > 0 and D % 2 == 0 do
                        k, D = k - 1, D / 2
                     end
                     while k < 0 and N % 2 == 0 do
                        k, N = k + 1, N / 2
                     end
                     local frac = fraction_to_string(k > 0 and N * 2^k or N, k < 0 and D * 2^-k or D, 0)
                     shortest = get_shortest_string(shortest, frac)
                     if not frac then
                        local dk = k > 0 and 1 or -1
                        local fN = (3 + dk) / 2
                        local fD, shortest_fraction = 2 / fN
                        k, N, D = k - dk, N * fN, D * fD
                        while N % fN + D % fD == 0 do
                           k, N, D = k + dk, N / fN, D / fD
                           shortest_fraction = fraction_to_string(N, D, k) or shortest_fraction
                        end
                        shortest = get_shortest_string(shortest, shortest_fraction)
                     end
                     break
                  end
                  x = 1 / (x - q)
               until x >= 2^20 or x ~= x
            end
         end
         shortest = sign..shortest
         --assert(assert(loadstring("return "..shortest))() == float_number)
         return shortest
      end

      local escapings = {
         ["\\"] = "\\\\",
         ["\a"] = "\\a",
         ["\b"] = "\\b",
         ["\f"] = "\\f",
         ["\n"] = "\\n",
         ["\r"] = "\\r",
         ["\t"] = "\\t",
         ["\v"] = "\\v",
         ["'"]  = "\\'",
         ['"']  = '\\"'
      }

      local function quote_string(str, quote)   -- " or '
         return
            quote
            ..gsub(
               gsub(
                  gsub(
                     str,
                     "[%c\\"..quote.."]",
                     function(c)
                        return escapings[c] or format("\a%03d", byte(c))
                     end
                  ),
                  "\a(%d%d%d%d)",
                  "\\%1"
               ),
               "\a0?0?",
               "\\"
            )
            ..quote
      end

      local function serialize_string_value(str)
         local single = quote_string(str, "'")
         local double = quote_string(str, '"')
         return #single < #double and single or double
      end

      function ser_simple_type(val)
         local tp = type(val)
         if tp == "number" then
            return serialize_number(val)
         elseif tp == "string" then
            return serialize_string_value(val)
         elseif tp == "boolean" or tp == "nil" then
            return tostring(val)
         end
      end

   end

   local add_to_heap, extract_from_heap
   do
      local heap_size, heap, indices = 0, {}, {}

      local function comparison_func(a, b)
         local a_pq, b_pq = a.non_ready_pairs_qty, b.non_ready_pairs_qty
         return a_pq < b_pq or a_pq == b_pq and a.times_used > b.times_used
      end

      function add_to_heap(elem)
         local elem_pos = indices[elem]
         if not elem_pos then
            heap_size = heap_size + 1
            elem_pos = heap_size
         end
         while elem_pos > 1 do
            local parent_pos = (elem_pos - elem_pos % 2) / 2
            local parent = heap[parent_pos]
            if comparison_func(elem, parent) then
               heap[elem_pos] = parent
               indices[parent] = elem_pos
               elem_pos = parent_pos
            else
               break
            end
         end
         heap[elem_pos] = elem
         indices[elem] = elem_pos
      end

      function extract_from_heap()
         if heap_size > 0 then
            local root_elem = heap[1]
            local parent = heap[heap_size]
            heap[heap_size] = nil
            indices[root_elem] = nil
            heap_size = heap_size - 1
            if heap_size > 0 then
               local pos = 1
               local last_node_pos = heap_size / 2
               while pos <= last_node_pos do
                  local child_pos = pos + pos
                  local child = heap[child_pos]
                  if child_pos < heap_size then
                     local child_pos2 = child_pos + 1
                     local child2 = heap[child_pos2]
                     if comparison_func(child2, child) then
                        child_pos = child_pos2
                        child = child2
                     end
                  end
                  if comparison_func(child, parent) then
                     heap[pos] = child
                     indices[child] = pos
                     pos = child_pos
                  else
                     break
                  end
               end
               heap[pos] = parent
               indices[parent] = pos
            end
            return root_elem
         end
      end
   end

   local user_tables = {}
   local index_of_user_table = {}

   do
      local table_to_process = {D}
      local table_index_to_process = 0

      repeat
         local real_table
         if table_index_to_process ~= 0 then
            real_table = user_tables[table_index_to_process]
            table_to_process = real_table.the_table
         end
         local non_ready_pairs_qty = 0
         for k, v in pairs(table_to_process) do
            local this_pair_depends_on_a_table = 0
            local the_table = k
            for kv = 1, 2 do
               if type(the_table) == "table" and not already_serialized[the_table] then
                  this_pair_depends_on_a_table = 1
                  local user_table_index = index_of_user_table[the_table]
                  local user_table
                  if user_table_index then
                     user_table = user_tables[user_table_index]
                     user_table.times_used = user_table.times_used + 1
                  else
                     user_table = {the_table = the_table, used_by = {}, times_used = 1}
                     user_tables[#user_tables + 1] = user_table
                     user_table_index = #user_tables
                     index_of_user_table[the_table] = user_table_index
                  end
                  if table_index_to_process ~= 0 then
                     local used_by = user_table.used_by
                     local used_by_idx = used_by[table_index_to_process]
                     if not used_by_idx then
                        used_by_idx = {}
                        used_by[table_index_to_process] = used_by_idx
                     end
                     if kv == 2 and k ~= v then
                        used_by_idx[#used_by_idx + 1] = k
                     end
                  end
               end
               the_table = v
            end
            non_ready_pairs_qty = non_ready_pairs_qty + this_pair_depends_on_a_table
         end
         if real_table then
            real_table.non_ready_pairs_qty = non_ready_pairs_qty
            add_to_heap(real_table)
         end
         table_index_to_process = table_index_to_process + 1
      until table_index_to_process > #user_tables
   end

   local instructions = {}
   local return_indent_level = ""
   do
      local function value_ready(x)
         local idx = index_of_user_table[x]
         return not idx or user_tables[idx].definition
      end

      local function ser_existing_value(val, ref, referred_vars)
         local ser_by_user = already_serialized[val]
         if ser_by_user then
            return ser_by_user
         end
         local idx = index_of_user_table[val]
         if idx then
            local def = user_tables[idx].definition
            local instr = instructions[def]
            local inner_level = instr.inlined_level
            if inner_level < 7 then
               instr.type = "inlined"
               --assert(not instr.last_ref)
               for referred_var in pairs(instr.referred_vars) do
                  instructions[referred_var].last_ref = ref
                  if referred_vars then
                     referred_vars[referred_var] = true
                  end
               end
               local outer_instr = instructions[ref]
               if outer_instr then
                  local outer_level = outer_instr.inlined_level
                  if outer_level then
                     outer_instr.inlined_level = max(outer_level, 1 + inner_level)
                  end
               end
            else
               if referred_vars then
                  referred_vars[def] = true
               end
               instr.last_ref = ref
            end
            return def
         end
         return ser_simple_type(val)
      end

      repeat
         local table_to_define = extract_from_heap()
         if table_to_define then
            local the_table = table_to_define.the_table
            local inlinable = table_to_define.times_used == 1 and table_to_define.non_ready_pairs_qty == 0
            local referred_vars = inlinable and {} or nil
            local new_instruction = {type = "definition", inlined_level = inlinable and 1 or 1/0, referred_vars = referred_vars}
            local instr_index = #instructions + 1
            instructions[instr_index] = new_instruction
            local keys_of_type_number = {}
            local keys_of_type_string = {}
            local keys_of_type_boolean = {}
            local keys_of_other_types = {}
            local keys_by_type = {number = keys_of_type_number, string = keys_of_type_string, boolean = keys_of_type_boolean}
            for k, v in pairs(the_table) do
               if value_ready(v) and value_ready(k) then
                  local t = keys_by_type[type(k)] or keys_of_other_types
                  t[#t + 1] = k
               end
            end
            table_sort(keys_of_type_number)
            table_sort(keys_of_type_string, alphanumeric_ordering_function)
            table_sort(keys_of_type_boolean, boolean_ordering_function)
            local j = 1
            for _, key_array in ipairs{keys_of_type_number, keys_of_type_string, keys_of_type_boolean, keys_of_other_types} do
               for _, k in ipairs(key_array) do
                  new_instruction[j] = ser_existing_value(k, instr_index, referred_vars)
                  new_instruction[j + 1] = ser_existing_value(the_table[k], instr_index, referred_vars)
                  j = j + 2
               end
            end
            table_to_define.definition = instr_index
            for i, ti_key_list in pairs(table_to_define.used_by) do
               local ti = user_tables[i]
               local ti_table = ti.the_table
               local ti_def = ti.definition
               local new_ready_pairs = 0
               for j = 0, #ti_key_list do
                  local x, k, v
                  if j == 0 then
                     k = the_table
                     v = ti_table[k]
                     --assert(#ti_key_list ~= 0 or v ~= nil)
                     x = v
                  else
                     v = the_table
                     k = ti_key_list[j]
                     --assert(ti_table[k] == v)
                     x = k
                  end
                  if x ~= nil and value_ready(x) then
                     if ti_def then
                        local ref = #instructions + 1
                        instructions[ref] = {type = "assignment", table = ti_def, key = ser_existing_value(k, ref), value = ser_existing_value(v, ref)}
                        instructions[ti_def].last_ref = ref
                     else
                        new_ready_pairs = new_ready_pairs + 1
                     end
                  end
               end
               if new_ready_pairs ~= 0 then
                  ti.non_ready_pairs_qty = ti.non_ready_pairs_qty - new_ready_pairs
                  add_to_heap(ti)
               end
            end
            table_to_define.used_by = nil
         end
      until not table_to_define
      local instr_index = #instructions + 1
      instructions[instr_index] = {ser_existing_value(D, instr_index), type = "return"}
   end

   local get_free_variable_name, release_variable_name
   do
      local variable_names = {}
      local total_variables_qty = 0

      function get_free_variable_name()
         for len = 1, #variable_names do
            local names = variable_names[len]
            local qty = #names
            if qty ~= 0 then
               local name = names[qty]
               names[qty] = nil
               return name, name.." = ", "\n"
            end
         end
         total_variables_qty = total_variables_qty + 1
         if total_variables_qty <= 18 then
            local name = char(96 + total_variables_qty)
            return name, "local "..name.." = ", "\n"
         elseif total_variables_qty <= 193 then
            local n = total_variables_qty - 19
            local m = n % 25
            local name = char((n - m) / 25 + 115, m + 97)
            return name, "local "..name.." = ", "\n"
         elseif total_variables_qty == 194 then
            return "z[1]", "local z = {", "}\n"
         else
            local name = "z["..tostring(total_variables_qty - 193).."]"
            return name, name.." = ", "\n"
         end
      end

      function release_variable_name(name)
         local len = #name
         local t = variable_names[len]
         if not t then
            t = {}
            variable_names[len] = t
            for j = len - 1, 1, -1 do
               if variable_names[j] then
                  break
               end
               variable_names[j] = {}
            end
         end
         t[#t + 1] = name
      end

   end

   local text = {}

   local function write_text(some_text)
      --assert(some_text)
      text[#text + 1] = some_text
   end

   local function extract_identifier(expr)
      if type(expr) == "string" then
         local q, identifier = match(expr, "^(['\"])(.*)%1$")
         return identifier and not Lua_keywords[identifier] and match(identifier, "^[A-Za-z_][A-Za-z0-9_]*$")
      end
   end

   local write_table_constructor

   local function write_value(value, indent_level)
      --assert(type(indent_level) == "string")
      if type(value) == "string" then
         return write_text(value)
      else
         local instr = instructions[value]
         if instr.type == "inlined" then
            return write_table_constructor(value, indent_level)
         else
            return write_text(instr.variable_name)
         end
      end
   end

   function write_table_constructor(instr_index, indent_level)
      --assert(type(indent_level) == "string")
      write_text"{"
      local instr = instructions[instr_index]
      local instr_len = #instr
      if instr_len ~= 0 then
         local final_indent = indent_level
         indent_level = indent_level.."\t"
         write_text"\n"
         write_text(indent_level)
         local separator = ",\n"..indent_level
         for j = 1, instr_len, 2 do
            if j ~= 1 then
               write_text(separator)
            end
            local key = instr[j]
            local key_as_identifier = extract_identifier(key)
            if key_as_identifier then
               write_text(key_as_identifier)
               write_text" = "
            else
               write_text"["
               write_value(key, indent_level)
               write_text"] = "
            end
            write_value(instr[j + 1], indent_level)
         end
         write_text"\n"
         write_text(final_indent)
      end
      write_text"}"
   end

   for current_instr_index, current_instr in ipairs(instructions) do
      local current_instr_type = current_instr.type
      local terminating_vars = current_instr.terminating_vars
      if terminating_vars then
         --assert(current_instr_type ~= "inlined")
         for _, var in ipairs(terminating_vars) do
            release_variable_name(instructions[var].variable_name)
         end
      end
      if current_instr_type == "definition" then
         do
            local term_instr = instructions[current_instr.last_ref]
            local term_vars = term_instr.terminating_vars
            if not term_vars then
               term_vars = {}
               term_instr.terminating_vars = term_vars
            end
            term_vars[#term_vars + 1] = current_instr_index
         end
         local variable_name, assignment_prefix, assignment_suffix = get_free_variable_name()
         current_instr.variable_name = variable_name
         write_text(assignment_prefix)
         write_table_constructor(current_instr_index, "")
         write_text(assignment_suffix)
      elseif current_instr_type == "assignment" then
         write_text(instructions[current_instr.table].variable_name)
         local key = current_instr.key
         local key_as_identifier = extract_identifier(key)
         if key_as_identifier then
            write_text"."
            write_text(key_as_identifier)
            write_text" = "
         else
            write_text"["
            write_value(key, "")
            write_text"] = "
         end
         write_value(current_instr.value, "")
         write_text"\n"
      elseif current_instr_type == "return" then
         write_text"return "
         local separator = ",\n\t"
         for j, value in ipairs(current_instr) do
            if j ~= 1 then
               write_text(separator)
            end
            write_value(value, return_indent_level)
         end
         write_text"\n"
      end
   end

   text = gsub(table_concat(text), "\n", "\r\n")

   -- create D-script file in the current directory
   local file = io.open(D_filename, "wb")
   file:write(text)
   file:close()

end
