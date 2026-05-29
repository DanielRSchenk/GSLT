---- Lua utilities

function dump(object, indent)
	-- given	a value
	-- 			how many indentation
	-- returns	a string representation of the table
	-- note		mostly for debugging purposes
	-- inspired by https://stackoverflow.com/q/9168058

	if type(object) ~= 'table' then
		return tostring(object)
	end

	indent = indent or 0
	local indent_string = "  "

	local s = '{'
	for key, value in pairs(object) do
		if type(key) ~= 'number' then key = '‘' .. key .. '’' end
		s = s .. '\n' .. string.rep(indent_string, indent + 1)
		.. key .. ': ' .. dump(value, indent + 1) .. ','
	end
	return s .. '\n' .. string.rep(indent_string, indent) .. '}'
end

---- LuaTeX utilities

-- aliases for print function
if texio then
	write = texio.write_nl
	rite = texio.write
end

-- constants for node ids
hlist_t = 0
vlist_t = 1
disc_t = 7
whatsit_t = 8
glue_t = 12
kern_t = 13
penalty_t = 14
glyph_t = 29
temp_t = 41
--? sub_box_t = 24

function in_range(i) return i >= 32 and i <= 127 end

function safe_char(i)
	if in_range(i) then
		return '‘' .. string.char(i) .. '’'
	end
	return i
end

function lower(i)
	-- Given a character index, returns the lowered character, if it is in the safe range.
	if not in_range(i) then
		return ' ' -- space character does not match any pattern
	elseif 65 <= i and i < 91 then -- uppercase
		return string.char(i + 32) -- make lowercase
	else
		return string.char(i)
	end
end

function dump_node(i, n)
	-- given	an index
	-- 			a node
	-- returns	a one-line representation of the node

	local result = "[" .. dump(i) .. "] "

	if n.id == glue_t then
		result = result .. "glue"
		.. " " .. n.subtype
	elseif n.id == temp_t then
		result = result .. "temp"
		.. " " .. dump(n.fields)
	elseif n.id == penalty_t then
		result = result .. "penalty"
		.. ", p = " .. n.penalty
	elseif n.id == glyph_t then
		result = result .. "glyph"
		.. ", char = " .. safe_char(n.char)
	elseif n.id == hlist_t then
		result = result .. "hlist"
	elseif n.id == vlist_t then
		result = result .. "vlist"
		.. ", w = " .. n.width
	elseif n.id == disc_t then
		local pre = 'no pre'
		if n.pre then
			pre = dump_node(1, n.pre)
		end
		result = result .. "disc"
		.. " " .. n.subtype
		.. ", p = " .. n.penalty
		.. ", pre = " .. (n.pre.char or "-")
		.. ", font = " .. (n.pre.font or "-")
		-- n.pre et al. are pointers to text, not text
		.. "\n  " .. pre
		-- .. "}{" .. (n.post or "")
		-- .. "}{" .. (n.replace or "")
		-- .. "}"
	elseif n.id == kern_t then
		result = result .. "kern"
	else
		result = result .. "id = " .. n.id
	end

	return result .. "\n"
end

---- hyphenation

function import_hyphenation_dictionary(dic_file)
	-- Imports a hyphen dic file into a table and returns this table.

	local rules = {} -- The table.

	-- Whether to include aligned original patterns (for demonstration purposes).
	align = true --[[, but --]] if luatexbase then align = false end

	-- For each line in the dictionary file:
	for line in io.lines(dic_file) do
		local rule = {}
		rule.original = line

		-- Whether the pattern is strictly a prefix or a suffix.
		rule.prefix = '.' == string.sub(line, 1, 1)
		rule.suffix = '.' == string.sub(line, -1)

		if rule.prefix then
			line = string.sub(line, 2) -- trim first character
		end
		if rule.suffix then
			line = string.sub(line, 1, -2) -- trim last character
		end

		-- Example: `line` could be 'y3thin'
		-- Set the pattern (e.g. 'ythin') and the indices of the hyphens (e.g. {2: 3}).
		-- In `.hyphens`, an integer 'n' at index 'i' means: a level-'n' hyphen should be placed before the 'i'th letter in `.pattern`.
		-- The length of `.hyphens` is always #`.pattern` + 1.
		-- If the index of 'n' is #`.pattern` + 1, then a level-'n' hyphen should be placed after the pattern.

		rule.pattern = ''
		if align then
			rule.aligned = ''
		end
		local last_is_hyphen = false
		rule.hyphens = {}
		for i = 1, #line do
			local char = string.sub(line, i, i)
			local level = string.byte(char) - string.byte('0')

			-- As for possible hyphen characters:
			-- Liang originally used only 1, 2, 3, 4 and 5,
			-- but in the current .dic, up to 9 is used.
			if level >= 1 and level <= 9 then -- hyphen
				rule.hyphens[#rule.pattern + 1] = level
				if align then
					rule.aligned = rule.aligned .. char
				end
				last_is_hyphen = true
			else -- character
				rule.pattern = rule.pattern .. char
				if align then
					local sep = ' '
					if last_is_hyphen then
						-- no space, because there is already a hyphenation digit
						sep = ''
					end
					rule.aligned = rule.aligned .. sep .. char
				end
				last_is_hyphen = false
			end
		end

		-- Add trailing '…' or '.' to indicate prefix or suffix rule.
		if align then
			if rule.prefix then
				rule.aligned = rule.aligned .. '…'
			end
			if rule.suffix then
				rule.aligned = rule.aligned .. '.'
			end
		end

		table.insert(rules, rule)
	end

	return rules
end

dic = import_hyphenation_dictionary('hyph_en.dic')

function matches(rule, word)
	-- Recognises whether a hyphenation rule matches a word; returns at what offsets it does.
	local match_offsets = {}

	-- offset start, offset end
	local os, oe = 0, #word - #rule.pattern
	
	if rule.prefix then
		oe = 0
	end

	if rule.suffix then
		os = #word - #rule.pattern
		if os < 0 then return match_offsets end
	end

	for offset = os, oe do
		if rule.pattern == string.sub(word, offset + 1, offset + #rule.pattern) then
			table.insert(match_offsets, offset)
		end
	end

	return match_offsets
end

function hyphen_indices_of(word, debug)
	-- Returns the indices of the characters before which should be hyphenated.

	-- Update the table with all rules that match.
	levels = {}
	for _, rule in ipairs(dic) do -- for each rule
		dump(rule.pattern)
		local m = matches(rule, word)

		for _, offset in ipairs(m) do -- for each match offset
			if debug and #m > 0 then
				print(string.rep(' ', 2 * offset) .. rule.aligned)
			end

			for index, level in pairs(rule.hyphens) do
				levels[offset + index] = math.max(levels[offset + index] or 0, level)
			end
		end
	end

	-- Return the indices of odd-level hyphens.
	result = {}
	local word_length = #word
	for index, level in pairs(levels) do
		if level % 2 == 1 and index > 2 and index <= word_length - 1 then
			-- do not hyphenate the first or last letter
			table.insert(result, index)
		end
	end
	table.sort(result)

	return result, levels
end

function levels_aligned(word, levels)
	-- 1s2u s1t a4i4n1a2b2i l1i1t y
	local result = ''

	for index = 1, #word + 1 do
		sep = ' '
		if levels[index] then -- hyphen at this position
			sep = levels[index]
		end
		result = result .. sep .. string.sub(word, index, index)
	end

	return result
end

function hyphens_aligned(word, indices)
	-- s u s·t a i n·a b i l·i·t y
	local result = ''
	local hyphen_index = 1

	for index = 1, #word + 1 do
		sep = ' '
		if indices[hyphen_index] == index then -- hyphen at this position
			sep = '·'
			hyphen_index = hyphen_index + 1
		end
		result = result .. sep .. string.sub(word, index, index)
	end

	return result
end

function hyphens_normal(word, indices)
	-- sus·tain·abil·i·ty
	local result = ''
	local last = 1

	for _, index in ipairs(indices) do
		result = result .. string.sub(word, last, index - 1)
		result = result .. '·'
		last = index
	end

	return result .. string.sub(word, last)
end

-- Human-readable hyphenation function for debugging purposes.
function hyp(word)
	print(string.rep('-', 2 * #word + 1))
	local indices, levels = hyphen_indices_of(word, true)
	local align = true

	if align then
		print(string.rep('=', 2 * #word + 1))
		print(levels_aligned(word, levels))
		print(hyphens_aligned(word, indices))
	end

	print(string.rep('-', 2 * #word + 1))
	print (' ' .. hyphens_normal(word, indices))
	print(string.rep('-', 2 * #word + 1))
end

function new_disc(font, is_hyphen)
	-- Given a font and whether to have a hyphen or not,
	-- generate a discretionary hyphen in this font.
	
	local disc = node.new(disc_t)
	disc.subtype = 3
	disc.penalty = tex.hyphenpenalty

	if is_hyphen then
		local hyphen = node.new(glyph_t)
		hyphen.char = 45
		hyphen.font = font
		disc.pre = hyphen
		-- disc.post and disc.replace are empty
	end

	return disc
end

function insert_shy_after(node)
	-- Inserts a soft hyphen (discretionary hyphen) after this node in the node list.

	local new = new_disc(node.font, true)

	-- Connect the new hyphen node to the current and next node.
	new.prev = node
	new.next = node.next

	-- Connect the current and next node to the new hyphen node.
	if node.next then
		node.next.prev = new
	end
	node.next = new

	--[[ -- raises an error
	if not node.check_discretionary(new) then -- check for errors
		write("Aagh! The disc node is wrong!")
	end
	--]]

end

-- TODO insert an empty discretionary node after this node
function insert_empty_disc_after(node)
end

function insert_hyphens(first_of_word, indices)
	-- Insert hyphens into the node list, before the given indices
	-- from the first node of some word.
	if #indices == 0 then return false end -- no hyphens to insert

	local cii = 1 -- current index in indices list
	local current_node = first_of_word

	for i = 1, indices[#indices] do
		if i + 1 == indices[cii] then
			-- If the next index is a hyphenation point,
			-- insert a hyphenation point after the current index.
			insert_shy_after(current_node)
			cii = cii + 1
			current_node = current_node.next -- advance over the just-inserted disc
		end
		current_node = current_node.next
	end
	return true
end

function hyphenator(head, tail)
	-- Hyphenates words by inserting soft hyphens into the node list.

	-- TODO after each already-included hyphen, add empty disc

	local current_word = ''
	local first_of_word = nil
	local words_hyphenated = 0

	for current_node in node.traverse(head) do
		-- write(dump_node(i, current_node))
		if current_node.id == glyph_t then
			-- mark this node as ‘first of word’ if not yet set
			if not first_of_word then first_of_word = current_node end
			-- append char to current word
			current_word = current_word .. lower(current_node.char)
		elseif current_node.id == kern_t then
			-- continue
		elseif first_of_word then
			-- End of word. If there was a word, hyphenate it.
			-- write('End of word ‘' .. current_word .. '’.')
			if insert_hyphens(first_of_word, hyphen_indices_of(current_word)) then
				words_hyphenated = words_hyphenated + 1
			end
			current_word = ''
			first_of_word = nil
		end
	end

	if words_hyphenated > 0 then
		rite(" " .. words_hyphenated .. "w")
	end

	-- rite(node.check_discretionaries(head) or '') -- check for disc errors
end

function dumper(head, groupcode)
	-- Iterate over the node list to dump all the nodes.
	write('Dumping!')
	local i = 1
	for n in node.traverse(head) do
		write(dump_node(i, n))
		i = i + 1
	end
	return head
end

-- add our own function to the callback
if luatexbase then
	local config = require('config')
	if config.algorithm == 0 then -- no algorithm
		luatexbase.add_to_callback("hyphenate", function() return false end, "null hyphenator")
	elseif config.algorithm == 1 then -- TeX's algorithm
		-- do nothing
	elseif config.algorithm == 2 then -- our algorithm
		luatexbase.add_to_callback("hyphenate", hyphenator, "hyphenator")
	else
		write("Invalid value for `algorithm` in `config.lua`: it must be 0, 1 or 2.")
	end
	-- luatexbase.add_to_callback("pre_linebreak_filter", dumper, "dumps the node list")
end

-- when iterating over a par:
	-- TODO how to deal with hyphens/dashes in words? how to ignore math mode?
	-- TODO add an empty disc node after a hyphen

-- TODO toggle: original algo / no callback at all / our algo
-- Make config.lua and import it in here?
-- And hide it in .gitignore afterwards.

-- Special characters (ï) are coded to not match any pattern. (as spaces)
