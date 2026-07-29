################################################################################
# Timing gate - shared by every red_pitaya_vivado_<MODEL>.tcl script.
#
# WHY THIS EXISTS
#   A build released bitstreams for PRJ=v0.94 (WNS=-8.915 ns, TNS=-9318 ns) and
#   PRJ=logic (WNS=-2.873 ns, TNS=-14992 ns).  Vivado printed
#
#       CRITICAL WARNING: [Timing 38-282] The design failed to meet the timing
#                         requirements.
#
#   and write_bitstream ran anyway, because nothing in the flow looked at the
#   result.  The images appeared fine and then misbehaved on hardware: CH3/CH4
#   configuration registers changed value on their own, because the sys-bus
#   crossing into the pll_adc_clk_1 domain was left unconstrained.
#
#   A bitstream that does not meet timing must never leave the build.
#
# USAGE - in each model script, immediately before write_bitstream:
#
#       source [file join $::RP_ROOT_DIR red_pitaya_vivado_timing_gate.tcl]
#       rp_check_timing $path_out
#
#   $::RP_ROOT_DIR must be captured near the top of the model script, BEFORE
#   "cd prj/$prj_name" changes the working directory.  Using
#   [file dirname [info script]] at the call site does not work: by then the cwd
#   is the project directory and the path resolves to ./ inside it.
#
# ESCAPE HATCH
#   For a deliberate experimental build:
#
#       make PRJ=v0.94 MODEL=Z20_4 DEFINES=ALLOW_TIMING_FAIL
#
#   DEFINES is forwarded to -tclargs, so it arrives in argv.  The gate then
#   downgrades to a loud warning.  Never use it for a release.
################################################################################

proc rp_check_timing {{report_dir ""}} {

    # -----------------------------------------------------------------------
    # Step 1: does this design have any timed paths at all?
    #
    # This has to be asked first.  PRJ=barebones reported STATS.WNS, STATS.TNS,
    # STATS.WHS and STATS.THS all as exactly 0.000000 - not because it met
    # timing, but because the run statistics were never populated.  Zero is a
    # valid double and is not < 0, so a naive gate passes it, and that is
    # indistinguishable from a genuinely clean design.  Measure the open design
    # instead, and treat "nothing to measure" as its own labelled outcome.
    # -----------------------------------------------------------------------
    set npaths 0
    catch {set npaths [llength [get_timing_paths -delay_type min_max -max_paths 1]]}

    if {$npaths == 0} {
        puts ""
        puts "################################################################################"
        puts "# TIMING GATE: NOT VERIFIED"
        puts "#   The design reports no timed paths, so timing could not be checked."
        puts "#   Expected for a design without user clock constraints.  If this project is"
        puts "#   supposed to have constrained clocks, they are missing or failed to apply -"
        puts "#   look for Vivado 12-627 / 12-4739 / Common 17-165 earlier in the log."
        puts "################################################################################"
        return
    }

    # -----------------------------------------------------------------------
    # Step 2: authoritative slack comes from the open design.  Run statistics
    # are only used to enrich the report with the totals.
    # -----------------------------------------------------------------------
    set wns ""
    set whs ""
    set tns "n/a"
    set ths "n/a"

    catch {set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]}
    catch {set whs [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]}

    if {![catch {get_runs impl_1} r] && $r ne ""} {
        catch {set tns [get_property STATS.TNS $r]}
        catch {set ths [get_property STATS.THS $r]}
        if {![string is double -strict $wns]} { catch {set wns [get_property STATS.WNS $r]} }
        if {![string is double -strict $whs]} { catch {set whs [get_property STATS.WHS $r]} }
    }

    puts ""
    puts "################################################################################"
    puts "# TIMING GATE"
    puts "#   WNS (setup worst) = $wns ns"
    puts "#   TNS (setup total) = $tns ns"
    puts "#   WHS (hold  worst) = $whs ns"
    puts "#   THS (hold  total) = $ths ns"
    puts "################################################################################"

    # A design that has timed paths but yields no slack number cannot be
    # certified, so it must not be shipped.
    if {![string is double -strict $wns] && ![string is double -strict $whs]} {
        error "TIMING GATE: design has timed paths but slack could not be read. Refusing to write a bitstream that cannot be verified."
    }

    # -----------------------------------------------------------------------
    # Step 3: verdict.  Hold is checked as well as setup - an earlier build
    # reached WHS -0.474 ns / THS -342.782 ns mid-flow, which a setup-only gate
    # would have waved through.
    # -----------------------------------------------------------------------
    set failed [list]
    if {[string is double -strict $wns] && $wns < 0} { lappend failed "setup (WNS=$wns ns, TNS=$tns ns)" }
    if {[string is double -strict $whs] && $whs < 0} { lappend failed "hold (WHS=$whs ns, THS=$ths ns)"  }

    if {[llength $failed] == 0} {
        puts "TIMING GATE: PASS - all constraints met."
        return
    }

    # -----------------------------------------------------------------------
    # On failure, dump the offending paths next to the other reports so the
    # cause is visible in the build artefacts without reopening the design.
    # -----------------------------------------------------------------------
    if {$report_dir ne ""} {
        catch {
            report_timing_summary -delay_type min_max -max_paths 20 \
                -report_unconstrained -file [file join $report_dir timing_gate_FAILED.rpt]
            puts "TIMING GATE: details written to [file join $report_dir timing_gate_FAILED.rpt]"
        }
    }
    catch {
        foreach pth [get_timing_paths -delay_type min_max -max_paths 10 -nworst 1] {
            puts [format "  %8.3f ns  %s -> %s" \
                [get_property SLACK $pth] \
                [get_property STARTPOINT_PIN $pth] \
                [get_property ENDPOINT_PIN $pth]]
        }
    }

    set msg "TIMING NOT MET: [join $failed {, }]. Bitstream generation aborted."

    global argv
    if {[info exists argv] && [lsearch -exact $argv "ALLOW_TIMING_FAIL"] >= 0} {
        puts "################################################################################"
        puts "# WARNING: $msg"
        puts "# Overridden by ALLOW_TIMING_FAIL - DO NOT SHIP THIS BITSTREAM."
        puts "################################################################################"
        return
    }

    error $msg
}
