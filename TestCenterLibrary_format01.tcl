package require SpirentTestCenter

set streamblocknum 0

proc connect_testcenter {stc_ip stc_slot stc_port} {
    global port Ethernet10GigCopper Project system1 
    set stc_port_list [split $stc_port ","]
    stc::connect $stc_ip
    foreach i $stc_port_list {
        stc::reserve "$stc_ip/$stc_slot/$i"
        stc::sleep 1
    }
    #Set the port default value when add port to reservation.
    set system1 system1
    stc::config system1 \
        -InSimulationMode "FALSE" \
        -UseSmbMessaging "FALSE" \
        -Active "TRUE" \
        -Name "StcSystem 1"\
        
    #Create an project
    set Project [stc::create "Project" \
        -TableViewData "" \
        -TestMode "L2L3" \
        -SelectedTechnologyProfiles "" \
        -ConfigurationFileName "STCresult.tcl" \
        -Active "TRUE" \
        -Name "Project 2" \
    ]
    foreach i $stc_port_list {
        #Create physical port
        set port($i) [stc::create "Port" \
            -under $Project \
            -Location //$stc_ip/$stc_slot/$i \
            -UseDefaultHost "TRUE" \
            -AppendLocationToPortName "TRUE" \
            -Layer3Type "IPV4" \
            -Active "TRUE" \
            -Name "Port //$stc_slot/$i" \
        ]
        #Create 10G logical port
        set Ethernet10GigCopper($i) [stc::create "Ethernet10GigCopper" \
            -under $port($i) \
            -DeficitIdleCount "TRUE" \
            -ClockOutputFreq "FREQ_156_25_MHZ" \
            -PriorityFlowControlArray "FALSE FALSE FALSE FALSE FALSE FALSE FALSE FALSE" \
            -IsPfcNegotiated "FALSE" \
            -AutoMdix "FALSE" \
            -TestMode "NORMAL_OPERATION" \
            -LineSpeed "SPEED_10G" \
            -AlternateSpeeds "" \
            -AdvertiseIEEE "TRUE" \
            -AdvertiseNBASET "TRUE" \
            -AutoNegotiation "TRUE" \
            -AutoNegotiationMasterSlave "MASTER" \
            -AutoNegotiationMasterSlaveEnable "TRUE" \
            -DownshiftEnable "FALSE" \
            -FlowControl "FALSE" \
            -OptimizedXon "DISABLE" \
            -Duplex "FULL" \
            -CollisionExponent "10" \
            -InternalPpmAdjust "0" \
            -TransmitClockSource "INTERNAL" \
            -ManagementRegistersTemplate {Templates/Mdio/ieee802_3ae45_1g10gCopper.xml} \
            -IgnoreLinkStatus "FALSE" \
            -DataPathMode "NORMAL" \
            -Mtu "1500" \
            -EnforceMtuOnRx "FALSE" \
            -PortSetupMode "PORTCONFIG_ONLY" \
            -ForwardErrorCorrection "TRUE" \
            -CustomFecChange "0" \
            -CustomFecMode "KR_FEC" \
            -Active "TRUE" \
            -LocalActive "TRUE" \
            -Name {1G Ethernet Copper Phy $i} \
        ]
    }
}




proc streamblock_ipv4 {port_id pkt_len d_mac s_mac s_ip d_ip gw_ip}  {
    global port streamblocknum Project
    set streamblocknum [expr $streamblocknum +1] 
    set streamblock($port_id$streamblocknum) [stc::create "StreamBlock" \
        -under $port($port_id) \
        -InsertSig "FALSE" \
        -FixedFrameLength "$pkt_len" \
        -FrameConfig "" \
        -Active "TRUE" \
        -Name "StreamBlock $streamblocknum" \
    ]
    #Create ethernetII container
    set ethernet($port_id$streamblocknum) [stc::create Ethernet:EthernetII \
        -under $streamblock($port_id$streamblocknum) \
        -srcMAC "$s_mac" \
        -dstMac "$d_mac" \
        -name "EthernetII_$port_id$streamblocknum" \
        -Active "TRUE" \
    ]
    
    #Create IPv4 container
    set ipv4($port_id$streamblocknum) [stc::create ipv4:IPv4 \
        -under $streamblock($port_id$streamblocknum) \
        -name "ipv4 $port_id$streamblocknum" \
        -sourceAddr "$s_ip" \
        -destAddr "$d_ip" \
        -gateway "$gw_ip" \
    ]
    stc::perform attachPorts -autoConnect true -portList [ stc::get $Project -children-Port ]
    stc::apply
}

proc streamblock_ipv4_vlan {port_id pkt_len d_mac s_mac vid pri_val s_ip d_ip gw_ip}  {
    global port streamblocknum Project
    set streamblocknum [expr $streamblocknum +1] 
    set streamblock($port_id$streamblocknum) [stc::create "StreamBlock" \
        -under $port($port_id) \
        -InsertSig "FALSE" \
        -FixedFrameLength "$pkt_len" \
        -FrameConfig "" \
        -Active "TRUE" \
        -Name "StreamBlock $streamblocknum" \
    ]
    #Create ethernetII container
    set ethernet($port_id$streamblocknum) [stc::create Ethernet:EthernetII \
        -under $streamblock($port_id$streamblocknum) \
        -srcMAC "$s_mac" \
        -dstMac "$d_mac" \
        -name "EthernetII_$port_id$streamblocknum" \
        -Active "TRUE" \
    ]
    #Create VLAN continer 
    set vlancontainer($port_id$streamblocknum) [stc::create vlans \
        -under $ethernet($port_id$streamblocknum) \
    ]
    array set priValue_array [list 0 "000" 1 "001" 2 "010" 3 "011" 4 "100" 5 "101" 6 "110" 7 "111"]
    set priority_value "$priValue_array($pri_val)"
    
    set vlanid($port_id$streamblocknum) [stc::create Vlan \
        -under $vlancontainer($port_id$streamblocknum) \
        -pri $priority_value \
        -cfi "0" \
        -id $vid \
        -name "vlan $vid" \
    ]
    #Create IPv4 container
    set ipv4($port_id$streamblocknum) [stc::create ipv4:IPv4 \
        -under $streamblock($port_id$streamblocknum) \
        -name "ipv4 $port_id$streamblocknum" \
        -sourceAddr "$s_ip" \
        -destAddr "$d_ip" \
        -gateway "$gw_ip" \
    ]
    stc::perform attachPorts -autoConnect true -portList [ stc::get $Project -children-Port ]
    stc::apply
}

proc burst_count {port_id count} {
    global port Project
    set generator [stc::get $port($port_id) -children-generator]
    set generatorconfig [lindex [stc::get $generator -children-generatorconfig] 0]
    stc::config $generatorconfig -DurationMode "BURSTS"
    stc::config $generatorconfig -Duration $count
    stc::perform attachPorts -autoConnect true -portList [ stc::get $Project -children-Port ]
    stc::apply  
}

proc continue_rate {port_id rate} {
    global port Project
    set generator [stc::get $port($port_id) -children-generator]
    set generatorconfig [lindex [stc::get $generator -children-generatorconfig] 0]
    stc::config $generatorconfig -DurationMode "CONTINUOUS"
    stc::config $generatorconfig -FixedLoad $rate
    stc::perform attachPorts -autoConnect true -portList [ stc::get $Project -children-Port ]
    stc::apply  
}

proc start_traffic {port_id} {
    global port Project
    set generator [stc::get $port($port_id) -children-generator]
    set start [stc::perform generatorstart -generatorlist $generator]
}

proc stop_traffic {port_id} {
    global port Project
    set generator [stc::get $port($port_id) -children-generator]
    set stop [stc::perform generatorstop -generatorlist $generator]

}

proc tx_PPS {port_id} {
    global port Project
    set tx_result [stc::subscribe -parent $Project \
        -resultParent "$Project" \
        -configType generator \
        -resultType generatorportresults \
    ]
    after 3000
    set get_generator [stc::get $port($port_id) -children-generator]
    set get_generatorportresults [lindex [stc::get $get_generator -children-generatorportresults] 0]
    set get_totalframerate [stc::get $get_generatorportresults -TotalFrameRate]
    stc::unsubscribe $tx_result
    stc::delete $tx_result 
    return $get_totalframerate
}

proc tx_counter {port_id} {
    global port Project
    set tx_result [stc::subscribe -parent $Project \
        -resultParent "$Project" \
        -configType generator \
        -resultType generatorportresults \
    ]
    after 3000
    set get_generator [stc::get $port($port_id) -children-generator]
    set get_generatorportresults [lindex [stc::get $get_generator -children-generatorportresults] 0]
    set get_totalframecount [stc::get $get_generatorportresults -TotalFrameCount]
    stc::unsubscribe $tx_result
    stc::delete $tx_result 
    return $get_totalframecount
}



proc rx_PPS {port_id} {
    global port Project
    set rx_result [stc::subscribe -parent $Project \
        -resultParent "$Project" \
        -configType analyzer \
        -resultType analyzerportresults \
    ]
    after 3000
    set get_analyzer [stc::get $port($port_id) -children-analyzer]
    set get_analyzerportresults [lindex [stc::get $get_analyzer -children-analyzerportresults] 0]
    set get_totalframerate [stc::get $get_analyzerportresults -TotalFrameRate]
    stc::unsubscribe $rx_result
    stc::delete $rx_result
    return $get_totalframerate
}

proc rx_counter {port_id} {
    global port Project
    set rx_result [stc::subscribe -parent $Project \
        -resultParent "$Project" \
        -configType analyzer \
        -resultType analyzerportresults \
    ]
    after 3000
    set get_analyzer [stc::get $port($port_id) -children-analyzer]
    set get_analyzerportresults [lindex [stc::get $get_analyzer -children-analyzerportresults] 0]
    set get_totalframecount [stc::get $get_analyzerportresults -TotalFrameCount]
    stc::unsubscribe $rx_result
    stc::delete $rx_result
    return $get_totalframecount
}

proc counter_reset {port_id} {
    global port Project
    stc::perform ResultClearAllTraffic -PortList "$port($port_id)"
}

proc streamblock_reset {port_id} {
    global port Project
    set delete_streamblock [stc::get $port($port_id) -children-streamblock]
    set delete_streamblock_list [split $delete_streamblock " "]
    foreach k $delete_streamblock_list {
        stc::delete $k
    }
}


proc capture_setup {port_id timer count} {
    global port Project sequencer system1
    set sequencer [stc::get $system1 -children-sequencer]
    file delete -force "C:/capture_$port_id.pcap" 
    set CaptureStartCommand [stc::create "CaptureStartCommand" \
        -under $sequencer \
        -AutoDestroy "FALSE" \
        -ExecuteSynchronous "FALSE" \
        -Active "TRUE" \
        -LocalActive "TRUE" \
        -Name "Start Capture $port_id" \
    ]
    stc::config $CaptureStartCommand -CaptureProxyId "$port($port_id)"
    stc::config $sequencer -CommandList "$CaptureStartCommand"
    stc::perform sequencerStart
    stc::waituntilcomplete
    #Timer.
    after [expr $timer *1000]
    
    #Stop to capture.
    set CaptureStopCommand [stc::create "CaptureStopCommand" \
        -under $sequencer \
        -Name "Stop Capture $port_id" \
    ]

    stc::config $CaptureStopCommand -CaptureProxyId "$port($port_id)"
    stc::config $sequencer -CommandList "$CaptureStopCommand"
    stc::perform sequencerStart
    stc::waituntilcomplete
    
    #Save to file.
    set count [expr $count -1]
    set CaptureDataSaveCommand [stc::create "CaptureDataSaveCommand" \
        -under $sequencer \
        -FileNamePath "C:\\" \
        -FileName "capture1.pcap" \
        -StartFrameIndex "0" \
        -EndFrameIndex "$count" \
    ]

    stc::config $CaptureDataSaveCommand -CaptureProxyId "$port($port_id)"
    stc::config $sequencer -CommandList "$CaptureDataSaveCommand"
    stc::perform sequencerStart
    stc::waituntilcomplete
}

