BEGIN{
    false = 0;      true = 1;   true2 = 2;

    RS="\034"

    out_format = false

    KEYPATH_SEP = "\034"
    # KEYPATH_SEP = ","

    out_color = true
    if (color != false)     out_color = true

    if (out_color_key == 0)     out_color_key = "\033[0;35m"
    if (out_color_string == 0)  out_color_string = "\033[0;34m"
    if (out_color_number == 0)  out_color_number = "\033[0;32m"
    if (out_color_null == 0)    out_color_null = "\033[0;33m"   # "\033[0;31m"
    if (out_color_true == 0)    out_color_true = "\033[7;32m"
    if (out_color_false == 0)   out_color_false = "\033[7;31m"
    out_color_end = "\033[0m"

    OP_DEL          = 1
    OP_LENGTH       = 2
    OP_PUTVAL       = 3
    OP_PUTKV        = 4
    OP_PREPEND      = 5
    OP_APPEND       = 6
    OP_POP          = 7

    OP_REPLACE      = 60
    OP_EXTRACT      = 61
    OP_FLAT         = 62
    OP_FLAT_LEAF    = 63
}

function warn(msg){
    # if (dbg == false) return
	print "idx[" s_idx "]  WARN:" msg > "/dev/stderr"
}


function debug(msg){
    if (dbg == false) return
	print "idx[" s_idx "," s_newline_idx "]  DEBUG:" msg > "/dev/stderr"
}

function str_wrap(str){
    gsub("\n", "\\n", str)
    gsub("\v", "\\v", str)
    gsub("\b", "\\b", str)
    gsub("\t", "\\t", str)
    return "\"" str "\""
}

function str_unwrap(){
    gsub("\\n", "\n", str)
    gsub("\\v", "\v", str)
    gsub("\\b", "\b", str)
    gsub("\\t", "\t", str)
    return substr(str, 2, length(str) - 2)
}

function yml_single_quote_unwrap(){
    gsub("\\", "\\\\", str)
    gsub("''", "'", str)
    return substr(str, 2, length(str) - 2)
}

function yml_walk_panic(msg,       start){
    start = s_idx - 10
    if (start <= 0) start = 1
    print ("value " _ord_[substr(s, s_idx, 1)]) > "/dev/stderr"
    print (msg " [index=" s_idx "," s_newline_idx "]:\n-------------------\n" substr(text, start, s_idx - start)  "|"  substr(text, s_idx, 1) "|" substr(text, s_idx+1, 30) "\n-------------------") > "/dev/stderr"
    exit 1
}

function json_walk_empty(   sw, o_idx, oo_idx){
    
    return sw
}

function json_walk_comment(     ss, pos){
    
    return false
}

function json_walk_empty0(   o_idx){
    # if (substr(s, s_idx, 1) != " ") return false
    match(substr(s, s_idx, 16), /^[ \n]+/)
    if (RLENGTH <= 0) return false
    o_idx = s_idx
    if (RLENGTH == 16) {   
        s_idx += 16
        match(substr(s, s_idx), /^[ \n]+/)
    }
    if (RLENGTH > 0) s_idx += RLENGTH
    return true
}

function yml_walk_string(){
    # String with double quote: \\ -> \001\001,    \" -> \002\002  
    # TODO: Get rid of leading spaces and tailing spaces
    if (0 != match(substr(s, s_idx), /^"[^"]+"/)) {     #"
        result = substr(s, s_idx, s_idx + RLENGTH)
        VALUE = result
        s_idx += RLENGTH
        s_newline_idx += RLENGTH # meaning less
        return true
    }

    # String with single quote:  
    # TODO: Get rid of leading spaces and tailing spaces
    if (0 != match(substr(s, s_idx), /^('[^']')+/)) {
        result = substr(s, s_idx, s_idx + RLENGTH)
        VALUE = "\"" yml_single_quote_unwrap(result) "\"" # Not sure
        s_idx += RLENGTH
        s_newline_idx += RLENGTH # meaning less
        return true
    }

    return false
}

function yml_walk_array(keypath, least_indent,   
    res, nth, detected_indent, cur_indent, result_value, t1){

    nth = -1
    res = ""

    detected_indent = s_newline_idx - 1
    while (1) {
        if (match(substr(s, s_idx), /^- /) == false) break
        cur_indent = s_newline_idx - 1
        if (cur_indent < least_indent)  break

        s_idx += 2
        s_newline_idx += 2

        if (yml_reach_indent_boundary()) t1 = result

        nth ++
        yml_walk_value(keypath KEYPATH_SEP nth, detected_indent + 1)
        result_value = result

        # if (nth > 0) res = res "\n"
        # res = res sprintf("%-" detected_indent "s", "") "- " result
        res = res "- " t1 result_value
        if (yml_reach_indent_boundary()) res = res result
    }

    if (nth == -1) return false
    result = res
    return true
}

# tmp1, tmp2, tmp3 are for putkv
function yml_walk_dict(keypath, least_indent,
    nth, o_idx, res, detected_indent, cur_keypath, cur_indent, result_key, result_colon, result_value, t0, t1, t2, tmp   ){
    nth = 0
    res = ""

    # Save first item index
    detected_indent = s_newline_idx - 1
    if (detected_indent < least_indent) return false
        
    while (1) {
        # cur_indent?
        cur_indent = s_newline_idx - 1

        if (cur_indent != detected_indent) {
            break
        }

        o_idx = s_idx

        # Extract key
        if (yml_walk_string()) {
            s_idx += RLENGTH
            s_newline_idx += RLENGTH
            if (false == match(substr(s, s_idx), /[ \t\b\v]*:[ \n]/)) {
                # Will not be a string. Because parsing string before parsing dict
                yml_walk_panic("yml_walk_dict")
            }
            
        } else if (match(substr(s, s_idx), /^[^\n]+:[ \n]/)) {
            result = substr(s, s_idx, RLENGTH - 2)
            gsub(/[\v\t\b ]+:[ \n]$/, "", result)
            VALUE = str_wrap(result)
            tmp = length(result)
            s_idx += tmp
            s_newline_idx += tmp
            
        } else {
            break
        }

        nth ++

        # result_key
        result_key = result
        cur_keypath = keypath KEYPATH_SEP VALUE

        # Must following with ": "
        s_idx += 1
        s_newline_idx += 1

        if (yml_reach_indent_boundary())    t1 = result
        if (yml_walk_value(cur_keypath, detected_indent + 1) == true) {
            result_value = result
        } else {
            # Value is null
            result_value = "~"
        }

        t2 = ""
        if (yml_reach_newline())            t2 = result
        if (yml_reach_indent_boundary())    t2 = t2 result  # Make sure s_newline_idx could be done.

        if (out_color) result_key = out_color_key result_key out_color_end
        res = res result_key ":" t1 result_value t2
    }

    if (nth == 0) return false

    result = res
    return true
}

function yml_reach_newline(){
    if (match(substr(s, s_idx), /^[ \t\b\v]*\n/)){
        result = substr(s, s_idx, RLENGTH)
        s_idx += RLENGTH
        s_newline_idx = 1
        return true
    }

    return false
}

function yml_reach_indent_boundary(     res){
    res = ""
    if (yml_reach_newline()){
        res = result
        if (match(substr(s, s_idx), /^[ ]+/)){
            result = res substr(s, s_idx, RLENGTH)
            s_newline_idx += RLENGTH
            s_idx += RLENGTH
            return true
        }
        return true
    }

    if (match(substr(s, s_idx), /^[\t\b\v ]+/)) {
        result = substr(s, s_idx, RLENGTH)
        s_newline_idx += RLENGTH
        s_idx += RLENGTH
        return true
    }

}

# Intercept key value
function yml_walk_value(keypath, indent,       ss, out, s_newline_idx_origin) {
    s_newline_idx_origin = s_newline_idx
    if (false == _yml_walk_value(keypath, indent)) return false

    if (op == OP_EXTRACT) {
        if (match(keypath, opv1)) {
            ss = "\n" sprintf("%-" (s_newline_idx_origin-1) "s", "")
            out = result
            gsub(ss, "\n", out)
            if (opv2 == "kv") { print keypath "\t-->\t" out }
            else if (opv2 == "k") { print keypath }
            else  { print out }
        }
    } else if (op == OP_FLAT) {
        ss = "\n" sprintf("%-" (s_newline_idx_origin-1) "s", "")
        out = result
        gsub(ss, "\n", out)
        print "\034" keypath "\n" out
    } else if (op == OP_REPLACE) {
        if (match(keypath, opv1)){
            # Normally it should be only value.
            result = opv2
            # result = json_walk(opv2, indent)
            return true
        }
    }

    return true
}

# TODO: make it better ... It will slow down the performance ...
function _yml_walk_value(keypath, indent,    o_idx, o_idx_2, res, ss){

    if (s_newline_idx - 1 < indent) yml_walk_panic("Expect a value with accurate indent.\t" s_newline_idx "\t " indent "\t|" substr(s, s_idx, 10))

    # Number
    if (0 != match(substr(s, s_idx), /^[0-9]+/)) {
        result = substr(s, s_idx, RLENGTH)
        if (out_color) result = out_color_number result out_color_end
        if (op == OP_FLAT_LEAF)  print keypath "\t" result
        s_idx += RLENGTH
        s_newline_idx += RLENGTH # meaning less
        return true
    }

    # Primitive
    ss = substr(s, s_idx, 6)
    if (0 != match(ss, /^(true)|(false)|(null)|(~)/)) {
        result = substr(s, s_idx, RLENGTH)
        if (out_color) {
            if (match(ss, /true/)) result = out_color_true result out_color_end
            else if (match(ss, /false/)) result = out_color_true result out_color_end
            else if (match(ss, /(null)|~/)) result = out_color_true result out_color_end
        }
        if (op == OP_FLAT_LEAF)  print keypath "\t" result
        s_idx += RLENGTH
        s_newline_idx += RLENGTH # meaning less
        return true
    }

    # Must before array and dict
    o_idx = s_idx
    if (yml_walk_string()) {
        if (out_color) result = out_color_string result out_color_end
        if (op == OP_FLAT_LEAF)  print keypath "\t" result
        # Make sure it is not a key-value pair.
        if (match(substr(s, s_idx), /^[ \t\b\v]+\n/))   {
            # s_newline_idx is wrong.
            debug("detect a QUOTED STRING. " keypath)
            return true
        }
        s_idx = o_idx
    }

    if (true == yml_walk_array( keypath, indent ))    return true
    if (true == yml_walk_dict(  keypath, indent )) {
        return true
    }

    # String without quote
    # TODO: Get rid of leading spaces and tailing spaces
    if (0 != match(substr(s, s_idx), /^[^\n]+\n/)) {
        result = substr(s, s_idx, RLENGTH - 1)
        if (out_color) result = out_color_string result out_color_end
        if (op == OP_FLAT_LEAF)  print keypath "\t" result
        s_idx += RLENGTH - 1
        s_newline_idx += RLENGTH - 1 # meaning less
        debug("detect a NO-QUOTE STRING. " keypath)
        return true
    }

    return false
}

function yml_walk_hyphen3(     ss){
    if (match(substr(s, s_idx), /^(\n)?---[ ]*\n+/) != 0) {
        ss = substr(s, s_idx, RLENGTH)
        result = substr(s, s_idx, RLENGTH)
        s_idx += RLENGTH
        s_newline_idx = 1
        return true
    }
    return false
}

function yml_walk_dot3(     sss){
    if (match(substr(s, s_idx), /^(\n)?...[ ]*\n+/) != 0) {
        ss = substr(s, s_idx, RLENGTH)
        result = substr(s, s_idx, RLENGTH)
        s_idx += RLENGTH
        s_newline_idx = 1
        return true
    }
    return false
}

function _yml_walk(         final, o_idx, nth, empty1, value_result, empty2){

    final = ""
    nth = 0

    # TODO: hyphen plus spaces
    if (true == yml_walk_hyphen3()) {
        debug("hyphen3")
        final = final result
    }
    
    while (s_idx <= s_len) {
        o_idx = s_idx

        empty1 = ""
        
        if (true == yml_reach_newline())   empty1 = result     # optional

        # yml_reach_indent_boundary()   # Top level, thus unesccesary
        if (yml_walk_value(nth++, 0) == false) {
            # break
            break
        }
        value_result = result
        if (yml_reach_newline() == true) empty2 = result     # optional
            
        if (out_format == true)     final = final           value_result "\n" 
        else                        final = final empty1    value_result empty2
        # consume value: Do some thing in stringify()

        if (true == yml_walk_hyphen3()) final = final result

        if (true == yml_walk_dot3()) {
            final += result     # optional
            if (s_idx <= s_len) 
                warn("_yml_walk() meet ... and expect END OF FILE. But file doesn't end.")
            break
        }

        if (s_idx == o_idx) {
            yml_walk_panic("_yml_walk() doesn't proceed.")
        }
    }

    return final
}

function yml_walk(text_to_parsed,      final){
    
    gsub(/\\\\/,        "\001\001", s)
    gsub(/\\"/,         "\002\002", s)    #"

    s = text_to_parsed
    s_idx = 1
    s_len = length(s)
    s_newline_idx = 1

    final = _yml_walk()

    gsub("\001\001",    /\\\\/,     final)
    gsub("\002\002",    /\\"/,      s)    #"

    return final
}

####### Code from x-bash/json
function _query_(s,       KEYPATH_SEP,    arr, tmp, idx, n, item){
    if (KEYPATH_SEP == 0) KEYPATH_SEP = "\034"

    if (s == ".")  return "0"

    s1 = s

    gsub(/\\\\/, "\001\001", s)
    gsub(/\\"/, "\002\002", s)  # "
    gsub(/\\\./, "\003\003", s)

    # gsub(/\./, "\034", s)
    # gsub(/\./, "|", s) # for debug

    n = split(s, arr, ".")
    if (arr[1] == "") tmp = 0
    else tmp = arr[1]
    for (idx=2; idx<=n; idx ++) {
        item = arr[idx]
        if ( match( item, /\/[^\/]+\// ) ) {
            tmp = tmp KEYPATH_SEP "\"(" substr(item, 2, length(item)-2) ")\""
            # tmp = tmp KEYPATH_SEP substr(item, 2, length(item)-2)
        } else if ( (match( item, /(^\[)|(^")|(^\*$)|(^\*\*$)/ ) == false) ) {   #"
            tmp = tmp KEYPATH_SEP "\"" item "\""
        } else {
            tmp = tmp KEYPATH_SEP item
        }
    }
    s = tmp

    gsub("\003\003", ".", s)
    gsub("\002\002", "\\\"", s)  # "
    gsub("\001\001", "\\\\", s)

    # gsub(/\*/, "[^|]+", s)   # for debug
    # gsub(/\*\*/, "([^|]+|)*[^|]+", s)    # for debug

    gsub(/\*/, "[^" KEYPATH_SEP "]+", s) #gsub(/\*/, "[^\034]+", s)
    gsub(/\*\*/, "([^" KEYPATH_SEP "]+" KEYPATH_SEP ")*[^" KEYPATH_SEP "]+", s) # gsub(/\*\*/, "([^\034]+\034)*[^\034]+", s)

    # gsub(/"[^"]+"/, "([^\034]+\034)*[^\034]+", s)   #"
    return s
}

function query(s,       KEYPATH_SEP) {
    return "^" _query_(s, KEYPATH_SEP) "$"
}

function query_split(formula, KEYPATH_SEP,    arr, len, final){
    formula = _query_(formula, KEYPATH_SEP)
    len = split(formula, arr, KEYPATH_SEP)
    final = arr[1]
    for (idx=2; idx<len; idx ++) {
        final = final KEYPATH_SEP arr[idx]
    }
    QUERY_SPLIT_FA = "^" final "$"
    QUERY_SPLIT_KEY = arr[len]
    return true
}
####### Code from x-bash/json

{
    if (op == "extract") {
        inner_content_generate = false
        debug("op_original_pattern: " opv1)
        opv1 = query(opv1, KEYPATH_SEP)
        debug("op_pattern: " opv1)
        op = OP_EXTRACT
        if (color == false) out_color = false
        yml_walk($0)
        exit 0
    }

    if (op == "flat") {
        op = OP_FLAT
        if (opv1 == false)  KEYPATH_SEP = "\t"
        else                KEYPATH_SEP = opv1
        # out_color = false
        yml_walk($0)
        exit 0
    }

    if (op == "flat-leaf") {
        op = OP_FLAT_LEAF
        if (opv1 == false)      KEYPATH_SEP = "\t"
        else                    KEYPATH_SEP = opv1
        inner_content_generate = false

        yml_walk($0)
        exit 0
    }

    if (op == "replace") {
        op = OP_REPLACE
        opv1 = query(opv1, KEYPATH_SEP)
        # opv2 = json_walk(opv2)
        debug("op_pattern: " opv1)
        print yml_walk($0)
        exit 0
    }

    # If it is done, it will substitute the replace function.
    # TODO: Not support yet.
    if (op == "put") {
        opv3 = opv2
        query_split(opv1, KEYPATH_SEP)
        opv1 = QUERY_SPLIT_FA
        opv2 = QUERY_SPLIT_KEY

        if (match(opv2, /^\[[0-9]+\]/)) {
            opv2=int(substr(opv2, 2, length(opv2)-2))
            op = OP_PUTVAL
        } else {
            op = OP_PUTKV
            if (out_color) opv2bak = out_color_key opv2 "\033[0m"
            else opv2bak = opv2
        }

        debug("op: " op)
        debug("op_pattern: " opv1)
        debug("op_key: " opv2)
        debug("op_value: " opv3)
        inner_content_generate = true
        print yml_walk($0)
        exit 0
    }

    print yml_walk($0)
}
