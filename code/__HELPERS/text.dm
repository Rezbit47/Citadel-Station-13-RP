/**
 * Holds procs designed to help with filtering text
 * Contains groups:
 *	! SQL sanitization
 *	! Text sanitization
 *	! Text searches
 *	! Text modification
 *	! Misc
 */

/**
 *! SQL sanitization
 */

/proc/format_table_name(table)
	return CONFIG_GET(string/sql_server_prefix) + table

/proc/format_unified_table_name(table)
	return CONFIG_GET(string/sql_unified_prefix) + table

/**
 *! Text sanitization
 */

// todo probably split this file into other files

/// Used for preprocessing entered text.
//  todo: extra is a bad param, we should instead just have linebreaks = n for n linebreaks, and a way to disable it.
/proc/sanitize(input, max_length = MAX_MESSAGE_LEN, encode = TRUE, trim = TRUE, extra = TRUE)
	if(!input)
		// don't toss out blank input by nulling it
		return input

	if(max_length)
		input = copytext(input,1,max_length)

	if(extra)
		var/temp_input = replace_characters(input, list("\n"="  ","\t"=" "))//one character is replaced by two
		if(length_char(input) < (length_char(temp_input) - (6 * 2))) //12 is the number of linebreaks allowed per message
			input = replace_characters(temp_input,list("  "=" "))//replace again, this time the double spaces with single ones

	if(encode)
		// The below \ escapes have a space inserted to attempt to enable Travis auto-checking of span class usage. Please do not remove the space.
		//In addition to processing html, html_encode removes byond formatting codes like "\ red", "\ i" and other.
		//It is important to avoid double-encode text, it can "break" quotes and some other characters.
		//Also, keep in mind that escaped characters don't work in the interface (window titles, lower left corner of the main window, etc.)
		input = html_encode(input)
	else
		//If not need encode text, simply remove < and >
		//note: we can also remove here byond formatting codes: 0xFF + next byte
		input = replace_characters(input, list("<"=" ", ">"=" "))

	if(trim)
		//Maybe, we need trim text twice? Here and before copytext?
		input = trim(input)

	return input

/**
 * standard sanitization for atom names
 *
 * disallows linebreaks, trims, encodes html.
 */
/proc/sanitize_atom_name(str, max_len = 32)
	return sanitize(str, max_len, TRUE, TRUE, FALSE)

//TODO: Have to rewrite this sanitize code :djoy:
/proc/sanitize_filename(t)
	return sanitize_simple_tg(t, list("\n"="", "\t"="", "/"="", "\\"="", "?"="", "%"="", "*"="", ":"="", "|"="", "\""="", "<"="", ">"=""))

/**
 * Removes a few problematic characters. Renamed because namespace.
 */
/proc/sanitize_simple_tg(t, list/repl_chars = list("\n"="#","\t"="#"))
	for(var/char in repl_chars)
		var/index = findtext(t, char)
		while(index)
			t = copytext(t, 1, index) + repl_chars[char] + copytext(t, index + length(char))
			index = findtext(t, char, index + length(char))
	return t

/**
 * Run sanitize(), but remove <, >, " first to prevent displaying them as &gt; &lt; &34; in some places, after html_encode().
 * Best used for sanitize object names, window titles.
 * If you have a problem with sanitize() in chat, when quotes and >, < are displayed as html entites -
 * this is a problem of double-encode(when & becomes &amp;), use sanitize() with encode=0, but not the sanitizeSafe()!
 */
/proc/sanitizeSafe(input, max_length = MAX_MESSAGE_LEN, encode = TRUE, trim = TRUE, extra = TRUE)
	return sanitize(replace_characters(input, list(">"=" ","<"=" ", "\""="'")), max_length, encode, trim, extra)

/**
 * Filters out undesirable characters from names.
 */
/proc/sanitizeName(input, max_length = MAX_NAME_LEN)
	if(!input || length(input) > max_length)
		return //Rejects the input if it is null or if it is longer then the max length allowed

	var/number_of_alphanumeric = 0
	var/last_char_group = 0
	var/output = ""

	for(var/i=1, i<=length(input), i++)
		var/ascii_char = text2ascii(input,i)
		switch(ascii_char)
			//! Uppercase Characters: A  .. Z
			if(65 to 90)
				output += ascii2text(ascii_char)
				number_of_alphanumeric++
				last_char_group = 4

			//! Lowercase Characters: a  .. z
			if(97 to 122)
				if(last_char_group<2)
					output += ascii2text(ascii_char-32) // Force uppercase first character.
				else
					output += ascii2text(ascii_char)
				number_of_alphanumeric++
				last_char_group = 4

			//! Number Characters: 0  .. 9
			if(48 to 57)
				if(!last_char_group)
					continue // Suppress at start of string.
				output += ascii2text(ascii_char)
				number_of_alphanumeric++
				last_char_group = 3

			//! Symbol Characters: '  -  .
			if(39, 45, 46) // Common name punctuation.
				if(!last_char_group) continue
				output += ascii2text(ascii_char)
				last_char_group = 2

			//! Hardcoded Characters: ~   |   @  :  #  $  %  &  *  +
			if(126, 124, 64, 58, 35, 36, 37, 38, 42, 43) // Other symbols that we'll allow (mainly for AI).
				if(!last_char_group)
					continue // Suppress at start of string.
				output += ascii2text(ascii_char)
				last_char_group = 2

			//! Space Character
			if(32)
				if(last_char_group <= 1)
					continue // Suppress double-spaces and spaces at start of string.
				output += ascii2text(ascii_char)
				last_char_group = 1
			else
				return

	if(number_of_alphanumeric < 2)
		return // Protects against tiny names like "A" and also names like "' ' ' ' ' ' ' '"

	if(last_char_group == 1)
		output = copytext(output,1,length(output)) // Removes the last character (in this case a space).

	//TODO: Make this like a json/yaml file or something.
	for(var/bad_name in list("space","floor","wall","r-wall","monkey","unknown","inactive ai","plating")) // Prevents these common metagamey names.
		if(cmptext(output,bad_name))
			return // Not case sensitive.

	return output

/**
 * Returns null if there is any bad text in the string.
 */
/proc/reject_bad_text(text, max_length = 512, ascii_only = TRUE)
	var/char_count = 0
	var/non_whitespace = FALSE
	var/lenbytes = length(text)
	var/char = ""
	for(var/i = 1, i <= lenbytes, i += length(char))
		char = text[i]
		char_count++
		if(char_count > max_length)
			return
		switch(text2ascii(char))
			if(62, 60, 92, 47) // <, >, \, /
				return
			if(0 to 31)
				return
			if(32)
				continue // Whitespace.
			if(127 to INFINITY)
				if(ascii_only)
					return
			else
				non_whitespace = TRUE
	if(non_whitespace)
		return text // Only accepts the text if it has some non-spaces.

/**
 * Used to get a properly sanitized input, of max_length
 * no_trim is self explanatory but it prevents the input from being trimed if you intend to parse newlines or whitespace.
 */
/proc/stripped_input(mob/user, message = "", title = "", default = "", max_length = MAX_MESSAGE_LEN, no_trim = FALSE)
	var/name = input(user, message, title, default) as text|null
	if(no_trim)
		return copytext(html_encode(name), 1, max_length)
	else
		return trim(html_encode(name), max_length) //trim is "outside" because html_encode can expand single symbols into multiple symbols (such as turning < into &lt;)

/**
 * Used to get a properly sanitized multiline input, of max_length.
 */
/proc/stripped_multiline_input(mob/user, message = "", title = "", default = "", max_length = MAX_MESSAGE_LEN, no_trim = FALSE)
	var/name = input(user, message, title, default) as message|null
	if(isnull(name)) // Return null if canceled.
		return null
	if(no_trim)
		return copytext(html_encode(name), 1, max_length)
	else
		return trim(html_encode(name), max_length)

/**
 * Old variant. Haven't dared to replace in some places.
 */
/proc/sanitize_old(var/t,var/list/repl_chars = list("\n"="#","\t"="#"))
	return html_encode(replace_characters(t,repl_chars))

/**
 *! Text searches
 */

/**
 * Checks the beginning of a string for a specified sub-string.
 * Returns the position of the substring or 0 if it was not found.
 */
/proc/dd_hasprefix(text, prefix)
	var/start = 1
	var/end = length(prefix) + 1
	return findtext(text, prefix, start, end)

/**
 * Checks the beginning of a string for a specified sub-string. This proc is case sensitive.
 * Returns the position of the substring or 0 if it was not found.
 */
/proc/dd_hasprefix_case(text, prefix)
	var/start = 1
	var/end = length(prefix) + 1
	return findtextEx(text, prefix, start, end)

/**
 * Checks the end of a string for a specified substring.
 * Returns the position of the substring or 0 if it was not found.
 */
/proc/dd_hassuffix(text, suffix)
	var/start = length(text) - length(suffix)
	if(start)
		return findtext(text, suffix, start, null)
	return

/**
 * Checks the end of a string for a specified substring. This proc is case sensitive.
 * Returns the position of the substring or 0 if it was not found.
 */
/proc/dd_hassuffix_case(text, suffix)
	var/start = length(text) - length(suffix)
	if(start)
		return findtextEx(text, suffix, start, null)

/**
 *! Text modification
 */
/proc/replace_characters(t, list/repl_chars)
	for(var/char in repl_chars)
		t = replacetext(t, char, repl_chars[char])
	return t

/**
 * Adds 'u' number of zeros ahead of the text 't'.
 */
/proc/add_zero(t, u)
	while (length(t) < u)
		t = "0[t]"
	return t

/**
 * Adds 'u' number of spaces ahead of the text 't'.
 */
/proc/add_lspace(t, u)
	while(length(t) < u)
		t = " [t]"
	return t

/**
 * Adds 'u' number of spaces behind the text 't'.
 */
/proc/add_tspace(t, u)
	while(length(t) < u)
		t = "[t] "
	return t

/**
 * Returns a string with reserved characters and spaces before the first letter removed.
 */
/proc/trim_left(text)
	for (var/i = 1 to length(text))
		if (text2ascii(text, i) > 32)
			return copytext_char(text, i)
	return ""

/**
 * Returns a string with reserved characters and spaces after the last letter removed.
 */
/proc/trim_right(text)
	for (var/i = length(text), i > 0, i--)
		if (text2ascii(text, i) > 32)
			return copytext_char(text, 1, i + 1)
	return ""

/**
 * Returns a string with reserved characters and spaces before the first word and after the last word removed.
 */
/proc/trim(text)
	return trim_left(trim_right(text))

/**
 * Returns a string with the first element of the string capitalized.
 */
/proc/capitalize(t as text)
	return uppertext(copytext_char(t, 1, 2)) + copytext_char(t, 2)

/**
 * Syntax is "stringtoreplace"="stringtoreplacewith".
 */
/proc/autocorrect(input as text)
	return input = replace_characters(input, list(
		" i "      = " I ",
		"i'm"      = "I'm",
		"s's"      = "s'",
		"isnt"     = "isn't",
		"dont"     = "don't",
		"shouldnt" = "shouldn't",
		" ive "    = " I've ",
		"whove"    = "who've",
		"whod"     = "who’d",
		"whats "    = "what’s ",
		"whatd"    = "what’d",
		"thats"    = "that’s",
		"thatll"   = "that’ll",
		"thatd"    = "that’d",
		" nows "   = " now’s ",
		"isnt"     = "isn’t",
		" arent "  = " aren’t ",
		"wasnt"    = "wasn’t",
		"werent"   = "weren’t",
		"havent"   = "haven’t",
		"hasnt"    = "hasn’t",
		"hadnt"    = "hadn’t",
		"doesnt"   = "doesn’t",
		"didnt"    = "didn’t",
		"couldnt"  = "couldn’t",
		"wouldnt"  = "wouldn’t",
		"mustnt"   = "mustn’t",
		"shouldnt" = "shouldn’t",
	))

/**
 * This proc strips html properly, remove < > and all text between
 * for complete text sanitizing should be used sanitize()
 */
/proc/strip_html_properly(input)
	if(!input)
		return
	var/opentag = 1 //These store the position of < and > respectively.
	var/closetag = 1
	while(1)
		opentag = findtext(input, "<")
		closetag = findtext(input, ">")
		if(closetag && opentag)
			if(closetag < opentag)
				input = copytext(input, (closetag + 1))
			else
				input = copytext(input, 1, opentag) + copytext(input, (closetag + 1))
		else if(closetag || opentag)
			if(opentag)
				input = copytext(input, 1, opentag)
			else
				input = copytext(input, (closetag + 1))
		else
			break

	return input

/**
 * This proc fills in all spaces with the "replace" var (* by default) with whatever
 * is in the other string at the same spot (assuming it is not a replace char).
 * This is used for fingerprints.
 */
/proc/stringmerge(text, compare, replace = "*")
	var/newtext = text
	if(length(text) != length(compare))
		return 0
	for(var/i = 1, i < length(text), i++)
		var/a = copytext(text,i,i+1)
		var/b = copytext(compare,i,i+1)
		//if it isn't both the same letter, or if they are both the replacement character
		//(no way to know what it was supposed to be)
		if(a != b)
			if(a == replace) //if A is the replacement char
				newtext = copytext(newtext,1,i) + b + copytext(newtext, i+1)
			else if(b == replace) //if B is the replacement char
				newtext = copytext(newtext,1,i) + a + copytext(newtext, i+1)
			else //The lists disagree, Uh-oh!
				return 0
	return newtext

/**
 * This proc returns the number of chars of the string that is the character.
 * This is used for detective work to determine fingerprint completion.
 */
/proc/stringpercent(text, character = "*")
	if(!text || !character)
		return 0
	var/count = 0
	for(var/i = 1, i <= length(text), i++)
		var/a = copytext(text,i,i+1)
		if(a == character)
			count++
	return count

/proc/reverse_text(text = "")
	var/new_text = ""
	for(var/i = length(text); i > 0; i--)
		new_text += copytext(text, i, i+1)
	return new_text

/proc/text2charlist(text)
	var/char = ""
	var/lentext = length(text)
	. = list()
	for(var/i = 1, i <= lentext, i += length(char))
		char = text[i]
		. += char

/**
 * Used in preferences' SetFlavorText and human's set_flavor verb
 * Previews a string of len or less length
 */
/proc/TextPreview(string, len=40)
	if(length(string) <= len)
		if(!length(string))
			return "\[...\]"
		else
			return string
	else
		return "[copytext_preserve_html(string, 1, 37)]..."

/**
 * Alternative copytext() for encoded text, doesn't break html entities (&#34; and other)
 */
/proc/copytext_preserve_html(text, first, last)
	return html_encode(copytext(html_decode(text), first, last))

/**
 * For generating neat chat tag-images.
 * The icon var could be local in the proc, but it's a waste of resources
 * to always create it and then throw it out.
 */
GLOBAL_VAR_INIT(text_tag_icons, new /icon('./icons/chattags.dmi'))

/proc/create_text_tag(tagname, tagdesc = tagname, client/C)
	if(!(C && C.is_preference_enabled(/datum/client_preference/chat_tags)))
		return tagdesc
	return icon2html(GLOB.text_tag_icons, C, tagname)

/proc/contains_az09(input)
	for(var/i=1, i<=length(input), i++)
		var/ascii_char = text2ascii(input,i)
		switch(ascii_char)
			//! Uppercase Characters: A  .. Z
			if(65 to 90)
				return TRUE

			//! Lowercase Characters:  a  .. z
			if(97 to 122)
				return TRUE

			//! Number Characters: 0  .. 9
			if(48 to 57)
				return TRUE

	return FALSE

/**
 * Strip out the special beyond characters for \proper and \improper
 * from text that will be sent to the browser.
 */
/proc/strip_improper(text)
	return replacetext(replacetext(text, "\proper", ""), "\improper", "")

/proc/pencode2html(t)
	t = replacetext(t, "\n", "<BR>")
	t = replacetext(t, "\[center\]", "<center>")
	t = replacetext(t, "\[/center\]", "</center>")
	t = replacetext(t, "\[br\]", "<BR>")
	t = replacetext(t, "\[b\]", "<B>")
	t = replacetext(t, "\[/b\]", "</B>")
	t = replacetext(t, "\[i\]", "<I>")
	t = replacetext(t, "\[/i\]", "</I>")
	t = replacetext(t, "\[u\]", "<U>")
	t = replacetext(t, "\[/u\]", "</U>")
	t = replacetext(t, "\[time\]", "[stationtime2text()]")
	t = replacetext(t, "\[date\]", "[stationdate2text()]")
	t = replacetext(t, "\[large\]", "<font size=\"4\">")
	t = replacetext(t, "\[/large\]", "</font>")
	t = replacetext(t, "\[field\]", "<span class=\"paper_field\"></span>")
	t = replacetext(t, "\[h1\]", "<H1>")
	t = replacetext(t, "\[/h1\]", "</H1>")
	t = replacetext(t, "\[h2\]", "<H2>")
	t = replacetext(t, "\[/h2\]", "</H2>")
	t = replacetext(t, "\[h3\]", "<H3>")
	t = replacetext(t, "\[/h3\]", "</H3>")
	t = replacetext(t, "\[*\]", "<li>")
	t = replacetext(t, "\[hr\]", "<HR>")
	t = replacetext(t, "\[small\]", "<font size = \"1\">")
	t = replacetext(t, "\[/small\]", "</font>")
	t = replacetext(t, "\[list\]", "<ul>")
	t = replacetext(t, "\[/list\]", "</ul>")
	t = replacetext(t, "\[table\]", "<table border=1 cellspacing=0 cellpadding=3 style='border: 1px solid black;'>")
	t = replacetext(t, "\[/table\]", "</td></tr></table>")
	t = replacetext(t, "\[grid\]", "<table>")
	t = replacetext(t, "\[/grid\]", "</td></tr></table>")
	t = replacetext(t, "\[row\]", "</td><tr>")
	t = replacetext(t, "\[cell\]", "<td>")
	t = replacetext(t, "\[logo\]", "<img src = ntlogo.png>")
	t = replacetext(t, "\[redlogo\]", "<img src = redntlogo.png>")
	t = replacetext(t, "\[sglogo\]", "<img src = sglogo.png>")
	t = replacetext(t, "\[editorbr\]", "")
	return t

/**
 * Random password generator. // Could've just flustered a bottom.
 */
/proc/GenerateKey()
	// Feel free to move to Helpers.
	var/newKey
	newKey += pick("the", "if", "of", "as", "in", "a", "you", "from", "to", "an", "too", "little", "snow", "dead", "drunk", "rosebud", "duck", "al", "le")
	newKey += pick("diamond", "beer", "mushroom", "assistant", "clown", "captain", "twinkie", "security", "nuke", "small", "big", "escape", "yellow", "gloves", "monkey", "engine", "nuclear", "ai")
	newKey += pick("1", "2", "3", "4", "5", "6", "7", "8", "9", "0")
	return newKey

/**
 * Used for applying byonds text macros to strings that are loaded at runtime.
 */
/proc/apply_text_macros(string)
	var/next_backslash = findtext(string, "\\")
	if(!next_backslash)
		return string

	var/leng = length(string)

	var/next_space = findtext(string, " ", next_backslash + 1)
	if(!next_space)
		next_space = leng - next_backslash

	if(!next_space)	//trailing bs
		return string

	var/base = next_backslash == 1 ? "" : copytext(string, 1, next_backslash)
	var/macro = lowertext(copytext(string, next_backslash + 1, next_space))
	var/rest = next_backslash > leng ? "" : copytext(string, next_space + 1)

	//See http://www.byond.com/docs/ref/info.html#/DM/text/macros
	switch(macro)
		//prefixes/agnostic
		if("the")
			rest = "\the [rest]"
		if("a")
			rest = "\a [rest]"
		if("an")
			rest = "\an [rest]"
		if("proper")
			rest = "\proper [rest]"
		if("improper")
			rest = "\improper [rest]"
		if("roman")
			rest = "\roman [rest]"
		//postfixes
		if("th")
			base = "[rest]\th"
		if("s")
			base = "[rest]\s"
		if("he")
			base = "[rest]\he"
		if("she")
			base = "[rest]\she"
		if("his")
			base = "[rest]\his"
		if("himself")
			base = "[rest]\himself"
		if("herself")
			base = "[rest]\herself"
		if("hers")
			base = "[rest]\hers"

	. = base
	if(rest)
		. += .(rest)


#define gender2text(gender) capitalize(gender)

GLOBAL_LIST_INIT(zero_character_only, list("0"))
GLOBAL_LIST_INIT(hex_characters, list("0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"))
GLOBAL_LIST_INIT(alphabet, list("a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"))
GLOBAL_LIST_INIT(binary, list("0","1"))
/proc/random_string(length, list/characters)
	. = ""
	for(var/i in 1 to length)
		. += pick(characters)

/proc/repeat_string(times, string="")
	. = ""
	for(var/i in 1 to times)
		. += string

/proc/random_short_color()
	return random_string(3, GLOB.hex_characters)

/proc/random_color()
	return random_string(6, GLOB.hex_characters)

/**
 * Readds quotes and apostrophes to HTML-encoded strings.
 */
/proc/readd_quotes(t)
	var/list/repl_chars = list("&#34;" = "\"","&#39;" = "'")
	for(var/char in repl_chars)
		var/index = findtext(t, char)
		while(index)
			t = copytext(t, 1, index) + repl_chars[char] + copytext(t, index+5)
			index = findtext(t, char)
	return t

/**
 * Adds 'char' ahead of 'text' until there are 'count' characters total.
 */
/proc/add_leading(text, count, char = " ")
	text = "[text]"
	var/charcount = count - length_char(text)
	var/list/chars_to_add[max(charcount + 1, 0)]
	return jointext(chars_to_add, char) + text

/**
 * Adds 'char' behind 'text' until there are 'count' characters total.
 */
/proc/add_trailing(text, count, char = " ")
	text = "[text]"
	var/charcount = count - length_char(text)
	var/list/chars_to_add[max(charcount + 1, 0)]
	return text + jointext(chars_to_add, char)

/**
 * Removes all non-alphanumerics from the text, keep in mind this can lead to id conflicts.
 */
/proc/sanitize_css_class_name(name)
	var/static/regex/regex = new(@"[^a-zA-Z0-9]","g")
	return replacetext(name, regex, "")
