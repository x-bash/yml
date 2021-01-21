BEGIN{
    false = 0;      true = 1;   true2 = 2;

    RS="\034"

    out_format = false
    dbg = false

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
}

function warn(msg){
    # if (dbg == false) return
	print "idx[" s_idx "]  WARN:" msg > "/dev/stderr"
}


function debug(msg){
    if (dbg == false) return
	print "idx[" s_idx "," s_newline_idx "]  DEBUG:" msg > "/dev/stderr"
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

function yml_walk_string_idx(){
    # String with double quote: \\ -> \001\001,    \" -> \002\002  
    # TODO: Get rid of leading spaces and tailing spaces
    if (0 != match(substr(s, s_idx), /^"[^"]+"/)) {     #"
        result = substr(s, s_idx, s_idx + RLENGTH)
        s_idx += RLENGTH
        s_newline_idx += RLENGTH # meaning less
        return true
    }

    # String with single quote:  
    # TODO: Get rid of leading spaces and tailing spaces
    if (0 != match(substr(s, s_idx), /^('[^']')+/)) {
        result = substr(s, s_idx, s_idx + RLENGTH)
        s_idx += RLENGTH
        s_newline_idx += RLENGTH # meaning less
        return true
    }

}

function yml_walk_array(keypath, least_indent,   
    res, nth, detected_indent, cur_indent, result_value){

    nth = 0
    res = ""

    detected_indent = s_newline_idx - 1
    while (1) {
        if (match(substr(s, s_idx), /^- /) == false) break
        cur_indent = s_newline_idx - 1
        if (cur_indent < least_indent)  break

        s_idx += 2
        s_newline_idx += 2

        nth ++
        yml_walk_value(keypath KEYPATH_SEP nth, detected_indent + 1)
        result_value = result

        # if (nth > 0) res = res "\n"
        # res = res sprintf("%-" detected_indent "s", "") "- " result
        res = res "- " result_value
        if (yml_reach_indent_boundary()) res = res result
    }

    if (nth == 0) return false
    result = res
    return true
}

# tmp1, tmp2, tmp3 are for putkv
function yml_walk_dict(keypath, least_indent,
    nth, o_idx, res, detected_indent, cur_indent, result_key, result_colon, result_value, t0, t1, t2   ){
    nth = 0
    res = ""

    # Save first item index
    detected_indent = s_newline_idx - 1
        
    while (1) {
        # cur_indent?
        cur_indent = s_newline_idx - 1

        if (cur_indent != detected_indent) {
            break
        }

        o_idx = s_idx
        if (yml_walk_string_idx()) {
            s_idx += RLENGTH
            s_newline_idx += RLENGTH
            if (false == match(substr(s, s_idx), /[ \t\b\v]*:[ \n]/)) {
                # Will not be a string. Because parsing string before parsing dict
                yml_walk_panic("yml_walk_dict")
            }
        } else if (match(substr(s, s_idx), /^[^\n]+:[ \n]/)) {
            # Extract key
            s_idx += RLENGTH - 2
            s_newline_idx += RLENGTH - 2
        } else {
            break
        }

        # result_key
        result_key = substr(s, o_idx, s_idx - o_idx)

        # Must following with ": "
        s_idx += 1
        s_newline_idx += 1

        nth ++
        if (yml_reach_indent_boundary())    t1 = result
        if (yml_walk_value(keypath KEYPATH_SEP result_key, detected_indent + 1) == true) {
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

# TODO: make it better ... It will slow down the performance ...
function yml_walk_value(keypath, indent,    o_idx, o_idx_2, res, ss){

    if (s_newline_idx - 1 < indent) yml_walk_panic("Expect a value with accurate indent.\t" s_newline_idx "\t " indent "\t|" substr(s, s_idx, 10))

    # Number
    if (0 != match(substr(s, s_idx), /^[0-9]+/)) {
        result = substr(s, s_idx, RLENGTH)
        if (out_color) result = out_color_number result out_color_end
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
        s_idx += RLENGTH
        s_newline_idx += RLENGTH # meaning less
        return true
    }

    # Must before array and dict
    o_idx = s_idx
    if (yml_walk_string_idx()) {
        if (out_color) result = out_color_string result out_color_end
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

{
    print yml_walk($0)
}
