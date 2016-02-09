#!/usr/bin/env tclsh

# This script is run during an upgrade. It reads the legacy config files stored in /root/.piaware and
# /etc/piaware, and writes an updated /etc/piaware.conf containing those settings in the new format.

package require fa_piaware_config

proc load_config {config} {
	set problems [$config read_config]
	foreach problem $problems {
		puts stderr "warning: $problem"
	}
}

proc main {} {
	puts stderr "Reading legacy config files"
	set oldconfig [::fa_piaware_config::new_legacy_config #auto]
	load_config $oldconfig

	puts stderr "Reading current config files"
	set newconfig [::fa_piaware_config::new_combined_config #auto]
	load_config $newconfig

	set changed 0
	foreach key [$oldconfig metadata all_settings] {
		if {[$oldconfig exists $key]} {
			if {![$newconfig exists $key]} {
				$newconfig set_option $key [$oldconfig get $key]
				puts stderr "Copied $key setting from [$oldconfig origin $key] to [$newconfig origin $key]"
				set changed 1
			} else {
				puts stderr "Ignored $key setting in [$oldconfig origin $key] as it is already present in [$newconfig origin $key]"
			}
		}
	}

	if {$changed} {
		puts stderr "Writing updated config files"
		$newconfig write_config
	} else {
		puts stderr "No changes to write"
	}
}

if {!$tcl_interactive} {
	main
}
