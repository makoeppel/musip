
foreach { hw_name } [ get_hardware_names ] {
    puts $hw_name
    set dev_name [ lindex [ get_device_names -hardware_name $hw_name ] 0 ]

    puts "open device: $hw_name :: $dev_name"
    open_device -hardware_name $hw_name -device_name $dev_name
    catch {
        puts [ device_lock -timeout 1000 ]
#        puts [ get_editable_mem_instances -hardware_name $hw_name -device_name $dev_name ]
        puts [ device_unlock ]
    }
    puts $::errorInfo
    close_device
}
