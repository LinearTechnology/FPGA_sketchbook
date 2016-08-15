# determine master index number
proc get_master_index {} {
   global master_index
   set master_list_length [llength [ get_service_paths master ]]
   set master_index [expr {$master_list_length - 1}] 
   return $master_index   
}

proc set_base_address {} {
   global base_address_rx0
   global base_address_tx0 
   
   # base address link0 RX
   set base_address_rx0 0x0400
   # base address link0 TX
   set base_address_tx0 0x0800
   
   return $base_address_rx0
   return $base_address_tx0
}

#Reset JESD
proc reset {} {
  set length [llength [ get_service_paths issp ]]
#  puts "length = $length"
  set service_path [lindex [get_service_paths issp] 0 ]
  set issp_path [claim_service issp $service_path "issp0"]
  set current_value [issp_read_source_data $issp_path]
  array set info [issp_get_instance_info $issp_path]
#  puts "ISSP $info(instance_index) $info(instance_name)"
#  puts "ISSP $issp_path"
#  puts "before $current_value"
  issp_write_source_data $issp_path [expr { $current_value | 0x01}]
  issp_write_source_data $issp_path [expr { $current_value & 0xFE}]
#  puts "after $current_value"
  puts "Reset Done!"
  close_service issp $issp_path
}

proc config_adc_222 {} {
global master_index
get_master_index
set m [lindex [get_service_paths master] $master_index]
puts "$m"	
open_service master $m
# #AD9517
master_write_32 $m 0x4 0x8400107C;  #write 0x7C to PLL operating mode register 0x010 to enable PLL	
master_write_32 $m 0x4 0x84001405;  #write 0x05 to B counter register 0x14 for B=5
master_write_32 $m 0x4 0x84001605;  #write 0x05 to prescaler P register 0x16 for P = divide by 16
master_write_32 $m 0x4 0x84001C02;  #write 0x02 to refclk select register 0x1C for selecting REF1
master_write_32 $m 0x4 0x8400F108;  #write 0x08 to OUT1 register 0xF1 for turning on LVPECL output
master_write_32 $m 0x4 0x84014042;  #write 0x42 to OUT4 register 0x140 for turning on LVDS output	
master_write_32 $m 0x4 0x84014142;  #write 0x42 to OUT5 register 0x141 for turning on LVDS output
master_write_32 $m 0x4 0x84014242;  #write 0x42 to OUT6 register 0x142 for turning on LVDS output
master_write_32 $m 0x4 0x84019000;  #write 0x00 to divider 0 register 0x190 for divider ratio=2
master_write_32 $m 0x4 0x84019100;  #write 0x00 to divider 0 register 0x191 for turning on divider 0
master_write_32 $m 0x4 0x84019911;  #write 0x11 to divider 2.1 register 0x199 for divider ratio=4
master_write_32 $m 0x4 0x84019C20;  #write 0x20 to divider 2 register 0x19C for bypassing divider 2.2
master_write_32 $m 0x4 0x84019E00;  #write 0x00 to divider 3.1 register 0x19E for divider ratio=2
master_write_32 $m 0x4 0x8401A120;  #write 0x20 to divider 3 register 0x1A1 for bypassing divider 3.2
master_write_32 $m 0x4 0x84001806;  #write 0x06 to VCO cal register 0x018 to reset VCO calibration
master_write_32 $m 0x4 0x84023201;  #write 0x01 to update all register 0x232 to update the register settings
master_write_32 $m 0x4 0x8401E003;  #write 0x03 to VCO divider register 0x1E0 for divider ratio=5
master_write_32 $m 0x4 0x8401E102;  #write 0x02 to VCO divider register 0x1E1 for selecting VCO as input
master_write_32 $m 0x4 0x84001807;  #write 0x07 to VCO cal register 0x018 to initiate VCO calibration
master_write_32 $m 0x4 0x84023201;  #write 0x01 to update all register 0x232 to update the register settings	

# #AD9250 #1
master_write_32 $m 0x4 0x80005F15;  #1, write 0x15 to link control 1 register 0x5F to disable the lane
master_write_32 $m 0x4 0x800064B9;  #1, write 0xB9 to DID register 0x64; 0xB9 is AD9250 chip ID
master_write_32 $m 0x4 0x80006E81;  #1, write 0x81 to parameter SCR/L register 0x6E to enable scrambler
master_write_32 $m 0x4 0x8000701F;  #1, write 0x1F to parameter K register 0x70 for K=32	
master_write_32 $m 0x4 0x80005E22;  #1, write 0x22 to quick config register 0x5E for L=2, M=2 	
master_write_32 $m 0x4 0x8000732F;  #1, write 0x2F to parameter subclass/Np register 0x73 for subclass 1
master_write_32 $m 0x4 0x80003A07;  #1, write 0x07 to sysref control register 0x3A to enable sysref
master_write_32 $m 0x4 0x80008B08;  #1, write 0x08 to LMFC offset register 0x8B to configure reset value for LMFC counter 
master_write_32 $m 0x4 0x80000D06;  #1, write 0x06 to test mode register 0x0D for PN sequence short test pattern	
master_write_32 $m 0x4 0x8000FF01;  #1, write 0x01 to device update register 0xFF to update the settings	
master_write_32 $m 0x4 0x80005F14;  #1, write 0x14 to link control 1 register 0x5F to enable the lane	

# #AD9250 #2
master_write_32 $m 0x4 0x81005F15;  #2, write 0x15 to link control 1 register 0x5F to disable the lane
master_write_32 $m 0x4 0x810064B9;  #2, write 0xB9 to DID register 0x64; 0xB9 is AD9250 chip ID
master_write_32 $m 0x4 0x81006E81;  #2, write 0x81 to parameter SCR/L register 0x6E to enable scrambler
master_write_32 $m 0x4 0x8100701F;  #2, write 0x1F to parameter K register 0x70 for K=32	
master_write_32 $m 0x4 0x81005E22;  #2, write 0x22 to quick config register 0x5E for L=2, M=2 	
master_write_32 $m 0x4 0x8100732F;  #2, write 0x2F to parameter subclass/Np register 0x73 for subclass 1
master_write_32 $m 0x4 0x81003A07;  #2, write 0x07 to sysref control register 0x3A to enable sysref
master_write_32 $m 0x4 0x81008B08;  #2, write 0x08 to LMFC offset register 0x8B to configure reset value for LMFC counter 
master_write_32 $m 0x4 0x81000D06;  #2, write 0x06 to test mode register 0x0D for PN sequence short test pattern	
master_write_32 $m 0x4 0x8100FF01;  #2, write 0x01 to device update register 0xFF to update the settings	
master_write_32 $m 0x4 0x81005F14;  #2, write 0x14 to link control 1 register 0x5F to enable the lane

puts "Clock & ADC SPI programming is done!"
close_service master $m
}

proc read_rxstatus3 {} {
	global base_address_rx0
	puts "Performing a read on rxstatus3 register..."
	set master_path [ lindex [ get_service_paths master ] 1 ]
	open_service master $master_path
	set rxstatus3 [master_read_32 $master_path [expr $base_address_rx0 + 0x8C] 1]
	puts "The rxstatus3 is $rxstatus3"
	close_service master $master_path
}

proc read_rxstatus4 {} {
	global base_address_rx0
	puts "Performing a read on rxstatus4 register..."
	set master_path [ lindex [ get_service_paths master ] 1 ]
	open_service master $master_path
	set rxstatus4 [master_read_32 $master_path [expr $base_address_rx0 + 0xF0] 1]
	puts "The rxstatus4 is $rxstatus4"
	close_service master $master_path
	puts "Info: Closed JTAG Master Service\n\n";
}

proc read_rxstatus5 {} {
	global base_address_rx0
	puts "Performing a read on rxstatus5 register..."
	set master_path [ lindex [ get_service_paths master ] 1 ]
	open_service master $master_path
	set rxstatus5 [master_read_32 $master_path [expr $base_address_rx0 + 0xF4] 1]
	puts "The rxstatus5 is ...$rxstatus5"
	close_service master $master_path
	puts "Info: Closed JTAG Master Service\n\n";
}

proc read_rxstatus7 {} {
	global base_address_rx0
	puts "Performing a read on rxstatus5 register..."
	set master_path [ lindex [ get_service_paths master ] 1 ]
	open_service master $master_path
	set rxstatus7 [master_read_32 $master_path [expr $base_address_rx0 + 0xFC] 1]
	puts "The rxstatus7 is ...$rxstatus7"
	close_service master $master_path
	puts "Info: Closed JTAG Master Service\n\n";
}


proc read_ilas_octet0 {} {
	global base_address_rx0
	puts "Performing a read on ilas_octet0 register..."
	set master_path [ lindex [ get_service_paths master ] 1 ]
	open_service master $master_path
	set ilas_octet0 [master_read_32 $master_path [expr $base_address_rx0 + 0xA0] 1]
	puts "The ilas_octet0 is ...$ilas_octet0"
	close_service master $master_path
	puts "Info: Closed JTAG Master Service\n\n";
}

proc read_ilas_octet1 {} {
	global base_address_rx0
	puts "Performing a read on ilas_octet1 register..."
	set master_path [ lindex [ get_service_paths master ] 1 ]
	open_service master $master_path
	set ilas_octet1 [master_read_32 $master_path [expr $base_address_rx0 + 0xA4] 1]
	puts "The ilas_octet1 is ...$ilas_octet1"
	close_service master $master_path
	puts "Info: Closed JTAG Master Service\n\n";
}

proc read_ilas_octet2 {} {
	global base_address_rx0
	puts "Performing a read on ilas_octet2 register..."
	set master_path [ lindex [ get_service_paths master ] 1 ]
	open_service master $master_path
	set ilas_octet2 [master_read_32 $master_path [expr $base_address_rx0 + 0xA8] 1]
	puts "The ilas_octet2 is ...$ilas_octet2"
	close_service master $master_path
	puts "Info: Closed JTAG Master Service\n\n";
}

proc read_ilas_octet3 {} {
	global base_address_rx0
	puts "Performing a read on ilas_octet3 register..."
	set master_path [ lindex [ get_service_paths master ] 1 ]
	open_service master $master_path
	set ilas_octet3 [master_read_32 $master_path [expr $base_address_rx0 + 0xAC] 1]
	puts "The ilas_octet3 is ...$ilas_octet3"
	close_service master $master_path
	puts "Info: Closed JTAG Master Service\n\n";
}

proc read_rx_err0 {} {
	global base_address_rx0
	puts "Performing a read on rx_err0 register..."
	set master_path [ lindex [ get_service_paths master ] 1 ]
	open_service master $master_path
	set rx_err0 [master_read_32 $master_path [expr $base_address_rx0 + 0x60] 1]
	puts "The rx_err0 is ...$rx_err0"
	close_service master $master_path
	puts "Info: Closed JTAG Master Service\n\n";	
}

proc read_rx_err1 {} {
	global base_address_rx0
	puts "Performing a read on rx_err1 register..."
	set master_path [ lindex [ get_service_paths master ] 1 ]
	open_service master $master_path
	set rx_err1 [master_read_32 $master_path [expr $base_address_rx0 + 0x64] 1]
	puts "The rx_err1 is ...$rx_err1"
	close_service master $master_path
	puts "Info: Closed JTAG Master Service\n\n";
}

# split 32-bit word into 8 nibbles
proc word_split {word} {
   global nibble0
   global nibble1
   global nibble2
   global nibble3
   global nibble4
   global nibble5
   global nibble6
   global nibble7   
   set nibble0 [lindex [split $word {}] 9]
   set nibble1 [lindex [split $word {}] 8]
   set nibble2 [lindex [split $word {}] 7]
   set nibble3 [lindex [split $word {}] 6]
   set nibble4 [lindex [split $word {}] 5]
   set nibble5 [lindex [split $word {}] 4]
   set nibble6 [lindex [split $word {}] 3]
   set nibble7 [lindex [split $word {}] 2]
   return $nibble0
   return $nibble1
   return $nibble2
   return $nibble3
   return $nibble4
   return $nibble5
   return $nibble6
   return $nibble7
}

# split a byte into 8 bits
proc byte_split {byte} {
   global bit0
   global bit1
   global bit2
   global bit3
   global bit4
   global bit5
   global bit6
   global bit7
   set bit0 [lindex [split $byte {}] 7]
   set bit1 [lindex [split $byte {}] 6]
   set bit2 [lindex [split $byte {}] 5]
   set bit3 [lindex [split $byte {}] 4]
   set bit4 [lindex [split $byte {}] 3]
   set bit5 [lindex [split $byte {}] 2]
   set bit6 [lindex [split $byte {}] 1]
   set bit7 [lindex [split $byte {}] 0]
   return $bit0
   return $bit1
   return $bit2
   return $bit3
   return $bit4
   return $bit5
   return $bit6
   return $bit7
}

# convert hexadecimal nibble to binary
proc hex2bin {hex} {
   global bin
   set number [expr $hex]
   set bin ""
   for {set i 0} {$i<4} {incr i} {
      set digit [expr $number & 1]
	  set bin "$digit$bin"
      set number [expr $number >> 1]
   }
   return $bin
}

# convert binary to decimal
proc bin2dec {bit_7 bit_6 bit_5 bit_4 bit_3 bit_2 bit_1 bit_0} {
   global dec0
   global dec1
   global dec2
   global dec3
   global dec4
   global dec5
   global dec6
   global dec7
   set dec0 [expr {$bit_0 * 1}]
   set dec1 [expr {$bit_1 * 2}]
   set dec2 [expr {$bit_2 * 4}]
   set dec3 [expr {$bit_3 * 8}]
   set dec4 [expr {$bit_4 * 16}]
   set dec5 [expr {$bit_5 * 32}]
   set dec6 [expr {$bit_6 * 64}]
   set dec7 [expr {$bit_7 * 128}]   
   return $dec0
   return $dec1
   return $dec2
   return $dec3
   return $dec4
   return $dec5
   return $dec6
   return $dec7
}

# read ILAS configuration data
proc read_ilas_config {} {
    global master_index
	global nibble0
	global nibble1
	global nibble2
	global nibble3
    global nibble4
    global nibble5
    global nibble6
    global nibble7
	global bin
	global bit0
	global bit1
	global bit2
	global bit3
	global bit4
	global bit5
	global bit6
	global bit7
	global dec0
	global dec1
	global dec2
	global dec3
	global dec4
	global dec5
	global dec6
	global dec7
	global base_address_rx0
	
    get_master_index
    puts "Reading JESD204B configuration data..."
    set base_address $base_address_rx0
	set master_path [ lindex [ get_service_paths master ] $master_index ]
	open_service master $master_path

	# Lane 0
	master_write_32 $master_path [expr $base_address + 0x50] 0x00000001
	set ilas_octet0 [master_read_32 $master_path [expr $base_address + 0xA0] 1]
	set ilas_octet1 [master_read_32 $master_path [expr $base_address + 0xA4] 1]
	set ilas_octet2 [master_read_32 $master_path [expr $base_address + 0xA8] 1]
	set ilas_octet3 [master_read_32 $master_path [expr $base_address + 0xAC] 1]
	
	# Generic
	# Processing ilas_octet0 register content
	word_split $ilas_octet0
	set did [concat $nibble1$nibble0]
	set bid $nibble2
	set adjcnt $nibble3
	set octet2 [concat [hex2bin 0x$nibble5][hex2bin 0x$nibble4]]
	byte_split $octet2
	set lid_lane0 [format "%02X" $bit4$bit3$bit2$bit1$bit0]
	set phadj $bit5
	set adjdir $bit6
	set octet3 [concat [hex2bin 0x$nibble7][hex2bin 0x$nibble6]]
	byte_split $octet3
    bin2dec $bit7 $bit6 $bit5 $bit4 $bit3 $bit2 $bit1 $bit0
	set l [expr {$dec4 + $dec3 + $dec2 + $dec1 + $dec0 + 1}]
    set scr $bit7	

	# Processing ilas_octet1 register content
	word_split $ilas_octet1
    set octet0 [concat [hex2bin 0x$nibble1][hex2bin 0x$nibble0]]
	byte_split $octet0
	bin2dec $bit7 $bit6 $bit5 $bit4 $bit3 $bit2 $bit1 $bit0
	set f [expr {$dec7 + $dec6 + $dec5 + $dec4 + $dec3 + $dec2 + $dec1 + $dec0 + 1}]	
	set octet1 [concat [hex2bin 0x$nibble3][hex2bin 0x$nibble2]]
	byte_split $octet1
	bin2dec $bit7 $bit6 $bit5 $bit4 $bit3 $bit2 $bit1 $bit0
	set k [expr {$dec4 + $dec3 + $dec2 + $dec1 + $dec0 + 1}]
	set octet2 [concat [hex2bin 0x$nibble5][hex2bin 0x$nibble4]]
	byte_split $octet2
	bin2dec $bit7 $bit6 $bit5 $bit4 $bit3 $bit2 $bit1 $bit0
	set m [expr {$dec7 + $dec6 + $dec5 + $dec4 + $dec3 + $dec2 + $dec1 + $dec0 + 1}]
    set octet3 [concat [hex2bin 0x$nibble7][hex2bin 0x$nibble6]]
	byte_split $octet3
	bin2dec $bit7 $bit6 $bit5 $bit4 $bit3 $bit2 $bit1 $bit0
	set n [expr {$dec4 + $dec3 + $dec2 + $dec1 + $dec0 + 1}]
	bin2dec $bit7 $bit6 $bit5 $bit4 $bit3 $bit2 $bit7 $bit6
	set cs [expr {$dec1 + $dec0}]
	
	# Processing ilas_octet2 register content
	word_split $ilas_octet2
    set octet0 [concat [hex2bin 0x$nibble1][hex2bin 0x$nibble0]]
	byte_split $octet0
	bin2dec $bit7 $bit6 $bit5 $bit4 $bit3 $bit2 $bit1 $bit0
	set n_prime [expr {$dec4 + $dec3 + $dec2 + $dec1 + $dec0 + 1}]
	if {$bit5 == 1} {
	   set subclass 1
	} elseif {$bit6 == 1} {
	   set subclass 2
	} else {
	   set subclass 0   
	}
	set octet1 [concat [hex2bin 0x$nibble3][hex2bin 0x$nibble2]]
	byte_split $octet1
	bin2dec $bit7 $bit6 $bit5 $bit4 $bit3 $bit2 $bit1 $bit0
	set s [expr {$dec4 + $dec3 + $dec2 + $dec1 + $dec0 + 1}]
    if {$bit5 == 1} {
	   set jesdv JESD204B
	} else {
	   set jesdv JESD204A
	}	
	set octet2 [concat [hex2bin 0x$nibble5][hex2bin 0x$nibble4]]
	byte_split $octet2
	bin2dec $bit7 $bit6 $bit5 $bit4 $bit3 $bit2 $bit1 $bit0
	set cf [expr {$dec4 + $dec3 + $dec2 + $dec1 + $dec0}]
    set hd $bit7

	# Processing ilas_octet3 register content
	word_split $ilas_octet3
	set fchk_lane0 [concat $nibble3$nibble2]
	
	# Lane 1
	master_write_32 $master_path [expr $base_address + 0x50] 0x00000081
	set ilas_octet0 [master_read_32 $master_path [expr $base_address + 0xA0] 1]
	set ilas_octet1 [master_read_32 $master_path [expr $base_address + 0xA4] 1]
	set ilas_octet2 [master_read_32 $master_path [expr $base_address + 0xA8] 1]
	set ilas_octet3 [master_read_32 $master_path [expr $base_address + 0xAC] 1]
	word_split $ilas_octet0
	set octet2 [concat [hex2bin 0x$nibble5][hex2bin 0x$nibble4]]
	byte_split $octet2
	set lid_lane1 [format "%02X" $bit4$bit3$bit2$bit1$bit0]
	word_split $ilas_octet3
	set fchk_lane1 [concat $nibble3$nibble2]
	
	# Display ILAS config data	
	puts "ILAS Configuration for lane0 & lane1"
    puts "Values are in decimal unless specified"	
    puts "DID      = 0x$did"
	puts "BID      = 0x$bid" 
    puts "ADJCNT   = 0x$adjcnt"
    puts "PHADJ    = $phadj"
	puts "ADJDIR   = $adjdir"
    puts [format "L        = %d" $l]
	puts "SCR      = $scr"
	puts [format "F        = %d" $f]
    puts [format "K        = %d" $k]
    puts [format "M        = %d" $m]
	puts [format "N        = %d" $n]
	puts [format "CS       = %d" $cs]
	puts [format "N'       = %d" $n_prime]
	puts [format "SUBCLASS = %d" $subclass]
	puts [format "S        = %d" $s]
	puts "JESDV    = $jesdv"
	puts "HD       = $hd"
	
	puts "\nLane 0 specific ILAS configuration data"
	puts "Lane 0 LID    = 0x$lid_lane0"
	puts "Lane 0 CHKSUM = 0x$fchk_lane0"

	puts "\nLane 1 specific ILAS configuration data"
	puts "Lane 1 LID    = 0x$lid_lane1"
	puts "Lane 1 CHKSUM = 0x$fchk_lane1"

	close_service master $master_path
	puts "\nInfo: Closed JTAG Master Service\n";	
}

#read RBD count of RX IP core
proc read_rbd_count {} {
	global nibble0
	global nibble1
	global nibble2
	global nibble3
    global nibble4
    global nibble5
    global nibble6
    global nibble7
	global bin
	global bit0
	global bit1
	global bit2
	global bit3
	global bit4
	global bit5
	global bit6
	global bit7
	global dec0
	global dec1
	global dec2
	global dec3
	global dec4
	global dec5
	global dec6
	global dec7
    global base_address_rx0
    global master_index
	
    get_master_index
	#puts "Performing a read on rx_status0 register..."
    set base_address $base_address_rx0
	set master_path [ lindex [ get_service_paths master ] $master_index ]
	open_service master $master_path
	set rx_status0 [master_read_32 $master_path [expr $base_address + 0x80] 1]
	#puts "The ADC RX Status0 register = $rx_status0"
	word_split $rx_status0
	set octet0 [concat [hex2bin 0x$nibble1][hex2bin 0x$nibble0]]
	set octet1 [concat [hex2bin 0x$nibble3][hex2bin 0x$nibble2]]
	byte_split $octet0	
	set rbd_count0 $bit3
	set rbd_count1 $bit4
	set rbd_count2 $bit5
	set rbd_count3 $bit6
	set rbd_count4 $bit7
    byte_split $octet1
	set rbd_count5 $bit0
	set rbd_count6 $bit1
	set rbd_count7 $bit3
	bin2dec $rbd_count7 $rbd_count6 $rbd_count5 $rbd_count4 $rbd_count3 $rbd_count2 $rbd_count1 $rbd_count0
	set rbd_count [expr {$dec7 + $dec6 + $dec5 + $dec4 + $dec3 + $dec2 + $dec1 + $dec0}]
	
	puts "RBD count: $rbd_count"
	close_service master $master_path
	puts "Info: Closed JTAG Master Service\n";
}

# initialization
get_master_index
set_base_address
set master_path [ lindex [ get_service_paths master ] $master_index ]
open_service master $master_path
puts "--- Initialization ---"
puts $master_path
close_service master $master_path