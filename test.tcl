puts $::auto_path

package require invoke

puts hello
invoke::callToNative
puts called
