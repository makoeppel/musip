#!/usr/bin/env tclsh

set ::opq_script_root [file normalize [file dirname [info script]]]
set ::opq_repo_root [file normalize [file join $::opq_script_root .. ..]]
set ::opq_default_svd [file join $::opq_repo_root firmware a10_board a10 merger qsys opq_upstream_4lane_native_sv opq_upstream_4lane.svd]
set ::opq_default_sopcinfo [file join $::opq_repo_root firmware a10_board a10 merger qsys opq_upstream_4lane_native_sv opq_upstream_4lane.sopcinfo]

proc usage {} {
    puts "Usage:"
    puts "  opq_jtag_csr.tcl probe   ?--sopcinfo PATH? ?--master PATTERN? ?--log PATH? ?--require-live?"
    puts "  opq_jtag_csr.tcl dump    --svd PATH ?--base 0x0? ?--master PATTERN? ?--log PATH? ?--dry-run?"
    puts "  opq_jtag_csr.tcl write   --svd PATH --register NAME --value VALUE ?--field NAME? ?--base 0x0? ?--master PATTERN? ?--log PATH? ?--dry-run?"
    puts "  opq_jtag_csr.tcl monitor --svd PATH --register NAME ?--field NAME|--mask MASK? --equals VALUE ?--samples N? ?--period-ms N? ?--log PATH?"
}

proc fail {message} {
    puts stderr "ERROR: $message"
    exit 1
}

proc parse_int {value} {
    if {[catch {expr {$value + 0}} parsed]} {
        fail "invalid integer: $value"
    }
    return $parsed
}

proc hex32 {value} {
    return [format "0x%08X" [expr {$value & 0xFFFFFFFF}]]
}

proc timestamp {} {
    return [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S%z"]
}

proc read_text {path} {
    set fd [open $path r]
    fconfigure $fd -encoding utf-8
    set text [read $fd]
    close $fd
    return $text
}

proc log_open {path} {
    if {$path eq ""} {
        return ""
    }
    file mkdir [file dirname $path]
    set fd [open $path w]
    fconfigure $fd -encoding utf-8
    return $fd
}

proc log_line {fd message} {
    puts $message
    if {$fd ne ""} {
        puts $fd $message
        flush $fd
    }
}

proc tag_value {block tag {default ""}} {
    set pattern "<${tag}>(.*?)</${tag}>"
    if {[regexp -nocase $pattern $block -> value]} {
        return [string trim $value]
    }
    return $default
}

proc parse_svd {path} {
    if {![file exists $path]} {
        fail "missing SVD: $path"
    }
    set text [read_text $path]
    set regs {}
    set register_blocks [regexp -all -inline -nocase {<register>.*?</register>} $text]
    foreach block $register_blocks {
        set name [tag_value $block name]
        if {$name eq ""} {
            continue
        }
        set offset [parse_int [tag_value $block addressOffset 0]]
        set access [tag_value $block access "read-only"]
        set reset [parse_int [tag_value $block resetValue 0]]
        set desc [tag_value $block description ""]
        set fields {}
        foreach fblock [regexp -all -inline -nocase {<field>.*?</field>} $block] {
            set fname [tag_value $fblock name]
            if {$fname eq ""} {
                continue
            }
            lappend fields [dict create \
                name $fname \
                bit_offset [parse_int [tag_value $fblock bitOffset 0]] \
                bit_width [parse_int [tag_value $fblock bitWidth 1]] \
                access [tag_value $fblock access $access] \
                desc [tag_value $fblock description ""]]
        }
        lappend regs [list $offset $name $access $reset $desc $fields]
    }
    return [lsort -integer -index 0 $regs]
}

proc find_register {regs name} {
    foreach reg $regs {
        if {[string equal -nocase [lindex $reg 1] $name]} {
            return $reg
        }
    }
    fail "register not found in SVD: $name"
}

proc find_field {reg field_name} {
    foreach field [lindex $reg 5] {
        if {[string equal -nocase [dict get $field name] $field_name]} {
            return $field
        }
    }
    fail "field not found in [lindex $reg 1]: $field_name"
}

proc extract_field {value field} {
    set width [dict get $field bit_width]
    set offset [dict get $field bit_offset]
    if {$width >= 32} {
        set mask 0xFFFFFFFF
    } else {
        set mask [expr {(1 << $width) - 1}]
    }
    return [expr {($value >> $offset) & $mask}]
}

proc field_mask {field} {
    set width [dict get $field bit_width]
    set offset [dict get $field bit_offset]
    if {$width >= 32} {
        set mask 0xFFFFFFFF
    } else {
        set mask [expr {(1 << $width) - 1}]
    }
    return [expr {($mask << $offset) & 0xFFFFFFFF}]
}

proc update_field {value field field_value} {
    set width [dict get $field bit_width]
    set offset [dict get $field bit_offset]
    if {$width < 32 && $field_value >= (1 << $width)} {
        fail "field value [hex32 $field_value] does not fit in $width bits"
    }
    set mask [field_mask $field]
    return [expr {(($value & (~$mask)) | (($field_value << $offset) & $mask)) & 0xFFFFFFFF}]
}

proc describe_fields {reg value} {
    set parts {}
    foreach field [lindex $reg 5] {
        set fname [dict get $field name]
        set fval [extract_field $value $field]
        lappend parts "${fname}=[hex32 $fval]"
    }
    return [join $parts ", "]
}

proc parse_options {argv defaults} {
    array set opts $defaults
    set i 0
    while {$i < [llength $argv]} {
        set arg [lindex $argv $i]
        switch -- $arg {
            --svd - --sopcinfo - --master - --log - --base - --register - --field - --value - --mask - --equals - --samples - --period-ms {
                incr i
                if {$i >= [llength $argv]} {
                    fail "missing value for $arg"
                }
                set opts([string range $arg 2 end]) [lindex $argv $i]
            }
            --require-live {
                set opts(require-live) 1
            }
            --dry-run {
                set opts(dry-run) 1
            }
            --force {
                set opts(force) 1
            }
            --no-readback {
                set opts(readback) 0
            }
            --no-meta-pages {
                set opts(no-meta-pages) 1
            }
            --help - -h {
                usage
                exit 0
            }
            default {
                fail "unknown option: $arg"
            }
        }
        incr i
    }
    return [array get opts]
}

proc reg_can_read {access} {
    return [expr {![string equal -nocase $access "write-only"]}]
}

proc reg_can_write {access} {
    return [expr {[string match -nocase "*write*" $access]}]
}

proc has_live_system_console {} {
    return [expr {[llength [info commands get_service_paths]] > 0}]
}

proc candidate_masters {} {
    if {![has_live_system_console]} {
        return {}
    }
    if {[catch {get_service_paths master} paths]} {
        return {}
    }
    return $paths
}

proc choose_master {paths pattern} {
    if {$pattern ne ""} {
        foreach path $paths {
            if {[string match -nocase "*${pattern}*" $path]} {
                return $path
            }
        }
        fail "no JTAG master service matches pattern: $pattern"
    }
    foreach needle {csr_jtag_master opq_upstream_4lane jtag_master} {
        foreach path $paths {
            if {[string match -nocase "*${needle}*" $path]} {
                return $path
            }
        }
    }
    if {[llength $paths] == 1} {
        return [lindex $paths 0]
    }
    return ""
}

proc claim_master {pattern require_live log_fd} {
    set paths [candidate_masters]
    if {[llength $paths] == 0} {
        if {$require_live} {
            fail "no live System Console master services visible"
        }
        log_line $log_fd "live_master_services=none"
        return ""
    }
    log_line $log_fd "live_master_services=[llength $paths]"
    foreach path $paths {
        log_line $log_fd "  service=$path"
    }
    set selected [choose_master $paths $pattern]
    if {$selected eq ""} {
        log_line $log_fd "claim_service=not_selected"
        log_line $log_fd "claim_hint=provide --master PATTERN or OPQ_CSR_MASTER when multiple generic JTAG master services are present"
        if {$require_live} {
            fail "no unambiguous live System Console master service selected"
        }
        return ""
    }
    log_line $log_fd "claim_service=$selected"
    if {[catch {claim_service master $selected opq_jtag_csr ""} ticket]} {
        if {$require_live} {
            fail "claim_service failed for $selected: $ticket"
        }
        log_line $log_fd "claim_failed=$ticket"
        return ""
    }
    return $ticket
}

proc rd32 {ticket addr} {
    set raw [master_read_32 $ticket $addr 1]
    return [parse_int [lindex $raw 0]]
}

proc wr32 {ticket addr value} {
    master_write_32 $ticket $addr $value
}

proc close_master {ticket} {
    if {$ticket ne "" && [has_live_system_console]} {
        catch {close_service master $ticket}
    }
}

proc sopcinfo_summary {path log_fd} {
    if {$path eq "" || ![file exists $path]} {
        log_line $log_fd "sopcinfo=missing"
        return
    }
    set text [read_text $path]
    set has_master [expr {[string first "csr_jtag_master" $text] >= 0}]
    set has_opq [expr {[string first "opq_0" $text] >= 0}]
    set has_csr [expr {[string first "opq_0.csr" $text] >= 0 || [string first "name=\"csr\"" $text] >= 0}]
    log_line $log_fd "sopcinfo=$path"
    log_line $log_fd "sopcinfo_csr_jtag_master=[expr {$has_master ? "present" : "missing"}]"
    log_line $log_fd "sopcinfo_opq_instance=[expr {$has_opq ? "present" : "missing"}]"
    log_line $log_fd "sopcinfo_opq_csr=[expr {$has_csr ? "present" : "missing"}]"
}

proc run_probe {argv} {
    array set opts [parse_options $argv [list sopcinfo $::opq_default_sopcinfo master "" log "build/ip/opq_jtag_probe.log" require-live 0]]
    set log_fd [log_open $opts(log)]
    log_line $log_fd "opq_jtag_csr probe timestamp=[timestamp]"
    sopcinfo_summary $opts(sopcinfo) $log_fd
    set ticket [claim_master $opts(master) $opts(require-live) $log_fd]
    if {$ticket ne ""} {
        if {[catch {rd32 $ticket 0x0} uid]} {
            log_line $log_fd "uid_read=failed error=$uid"
            if {$opts(require-live)} {
                close_master $ticket
                fail "UID read failed: $uid"
            }
        } else {
            log_line $log_fd "uid_read=[hex32 $uid]"
        }
    }
    close_master $ticket
    if {$log_fd ne ""} {
        close $log_fd
    }
}

proc run_dump {argv} {
    array set opts [parse_options $argv [list svd $::opq_default_svd base 0x0 master "" log "build/ip/opq_jtag_dump.log" dry-run 0 no-meta-pages 0]]
    set log_fd [log_open $opts(log)]
    set regs [parse_svd $opts(svd)]
    set base [parse_int $opts(base)]
    log_line $log_fd "opq_jtag_csr dump timestamp=[timestamp]"
    log_line $log_fd "svd=$opts(svd)"
    log_line $log_fd "register_count=[llength $regs]"
    if {$opts(dry-run)} {
        foreach reg $regs {
            log_line $log_fd [format "dry %-24s offset=%s access=%s reset=%s" [lindex $reg 1] [hex32 [lindex $reg 0]] [lindex $reg 2] [hex32 [lindex $reg 3]]]
        }
        close $log_fd
        return
    }
    set ticket [claim_master $opts(master) 1 $log_fd]
    foreach reg $regs {
        set offset [lindex $reg 0]
        set name [lindex $reg 1]
        set access [lindex $reg 2]
        set addr [expr {$base + $offset}]
        if {[string equal -nocase $name "META"] && !$opts(no-meta-pages)} {
            foreach {sel label} {0 VERSION 1 VERSION_DATE 2 VERSION_GIT 3 INSTANCE_ID} {
                wr32 $ticket $addr $sel
                set value [rd32 $ticket $addr]
                log_line $log_fd [format "%-24s page=%-12s addr=%s value=%s" $name $label [hex32 $addr] [hex32 $value]]
            }
            wr32 $ticket $addr 0
            continue
        }
        if {[string equal -nocase $access "write-only"]} {
            log_line $log_fd [format "%-24s addr=%s access=%s value=<write-only>" $name [hex32 $addr] $access]
            continue
        }
        set value [rd32 $ticket $addr]
        set fields [describe_fields $reg $value]
        if {$fields eq ""} {
            log_line $log_fd [format "%-24s addr=%s value=%s" $name [hex32 $addr] [hex32 $value]]
        } else {
            log_line $log_fd [format "%-24s addr=%s value=%s fields={%s}" $name [hex32 $addr] [hex32 $value] $fields]
        }
    }
    close_master $ticket
    if {$log_fd ne ""} {
        close $log_fd
    }
}

proc run_write {argv} {
    array set opts [parse_options $argv [list svd $::opq_default_svd base 0x0 master "" log "build/ip/opq_jtag_write.log" register "" field "" value "" dry-run 0 force 0 readback 1]]
    if {$opts(register) eq ""} {
        fail "write requires --register NAME"
    }
    if {$opts(value) eq ""} {
        fail "write requires --value VALUE"
    }
    set regs [parse_svd $opts(svd)]
    set reg [find_register $regs $opts(register)]
    set reg_name [lindex $reg 1]
    set access [lindex $reg 2]
    if {![reg_can_write $access] && !$opts(force)} {
        fail "register $reg_name is not writable in SVD access=$access"
    }
    set base [parse_int $opts(base)]
    set addr [expr {$base + [lindex $reg 0]}]
    set requested [parse_int $opts(value)]
    set log_fd [log_open $opts(log)]
    log_line $log_fd "opq_jtag_csr write timestamp=[timestamp]"
    log_line $log_fd "svd=$opts(svd)"
    log_line $log_fd "register=$reg_name addr=[hex32 $addr] access=$access requested=[hex32 $requested]"

    set field ""
    if {$opts(field) ne ""} {
        if {![reg_can_read $access] && !$opts(force)} {
            close $log_fd
            fail "field write for $reg_name needs read-modify-write, but SVD access=$access"
        }
        set field [find_field $reg $opts(field)]
        log_line $log_fd "field=[dict get $field name] bit_offset=[dict get $field bit_offset] bit_width=[dict get $field bit_width]"
    }

    if {$opts(dry-run)} {
        if {$field ne ""} {
            set before [lindex $reg 3]
            set write_value [update_field $before $field $requested]
            log_line $log_fd "dry_run=1 before_reset=[hex32 $before] write_value=[hex32 $write_value]"
        } else {
            log_line $log_fd "dry_run=1 write_value=[hex32 $requested]"
        }
        close $log_fd
        return
    }

    set ticket [claim_master $opts(master) 1 $log_fd]
    set before ""
    if {[reg_can_read $access]} {
        set before [rd32 $ticket $addr]
        log_line $log_fd "before=[hex32 $before]"
    }
    if {$field ne ""} {
        set write_value [update_field $before $field $requested]
    } else {
        set write_value $requested
    }
    wr32 $ticket $addr $write_value
    log_line $log_fd "write_value=[hex32 $write_value]"
    if {$opts(readback) && [reg_can_read $access]} {
        set after [rd32 $ticket $addr]
        log_line $log_fd "readback=[hex32 $after] match=[expr {$after == $write_value}]"
        set fields [describe_fields $reg $after]
        if {$fields ne ""} {
            log_line $log_fd "readback_fields={$fields}"
        }
    }
    close_master $ticket
    close $log_fd
}

proc run_monitor {argv} {
    array set opts [parse_options $argv [list svd $::opq_default_svd base 0x0 master "" log "build/ip/opq_jtag_monitor.log" register STATUS field "" mask "" equals "" samples 50 period-ms 100 dry-run 0]]
    if {$opts(equals) eq ""} {
        fail "monitor requires --equals VALUE"
    }
    set regs [parse_svd $opts(svd)]
    set reg [find_register $regs $opts(register)]
    set reg_name [lindex $reg 1]
    set addr [expr {[parse_int $opts(base)] + [lindex $reg 0]}]
    set expected [parse_int $opts(equals)]
    set mask ""
    set field ""
    if {$opts(field) ne ""} {
        set field [find_field $reg $opts(field)]
    } elseif {$opts(mask) ne ""} {
        set mask [parse_int $opts(mask)]
    } else {
        set mask 0xFFFFFFFF
    }
    set log_fd [log_open $opts(log)]
    log_line $log_fd "opq_jtag_csr monitor timestamp=[timestamp]"
    log_line $log_fd "register=$reg_name addr=[hex32 $addr] expected=[hex32 $expected] samples=$opts(samples) period_ms=$opts(period-ms)"
    if {$opts(dry-run)} {
        log_line $log_fd "dry_run=1"
        close $log_fd
        return
    }
    set ticket [claim_master $opts(master) 1 $log_fd]
    set triggered 0
    for {set i 0} {$i < [parse_int $opts(samples)]} {incr i} {
        set value [rd32 $ticket $addr]
        if {$field ne ""} {
            set observed [extract_field $value $field]
            set label [dict get $field name]
        } else {
            set observed [expr {$value & $mask}]
            set label "mask_[hex32 $mask]"
        }
        set match [expr {$observed == $expected}]
        log_line $log_fd [format "sample=%04d raw=%s %s=%s match=%d" $i [hex32 $value] $label [hex32 $observed] $match]
        if {$match} {
            log_line $log_fd "trigger=matched sample=$i"
            set triggered 1
            break
        }
        after [parse_int $opts(period-ms)]
    }
    if {!$triggered} {
        log_line $log_fd "trigger=not_matched"
    }
    close_master $ticket
    if {$log_fd ne ""} {
        close $log_fd
    }
}

if {[llength $argv] > 0 && [lindex $argv 0] eq "--"} {
    set argv [lrange $argv 1 end]
}
if {[llength $argv] == 0 && [info exists ::env(OPQ_CSR_CMD)]} {
    set argv [concat [list $::env(OPQ_CSR_CMD)] [expr {[info exists ::env(OPQ_CSR_ARGS)] ? $::env(OPQ_CSR_ARGS) : ""}]]
}
if {[llength $argv] == 0} {
    usage
    exit 1
}

set command [lindex $argv 0]
set rest [lrange $argv 1 end]
switch -- $command {
    probe {
        run_probe $rest
    }
    dump {
        run_dump $rest
    }
    write {
        run_write $rest
    }
    monitor {
        run_monitor $rest
    }
    --help - -h - help {
        usage
    }
    default {
        usage
        fail "unknown command: $command"
    }
}
