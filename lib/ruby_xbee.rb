# == Synopsis
# xbee.rb - A Ruby class for manipulating an XBee via the serial communication port of the host
#
# this code is designed for the following XBee modules:
#   IEEE¬Æ 802.15.4 OEM RF Modules by Digi International
#   Series 1 XBee and XBee Pro modules
#
# :title: xbee.rb - A Ruby class for manipulating an XBee via the serial communication port of the host
#
# == Copyright
#
# Copyright (C) 2008-2009 360VL, Inc. and Landon Cox
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License version 3 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License version 3 for more details.
#
# You should have received a copy of the GNU Affero General Public License along with this program.
# If not, see http://www.gnu.org/licenses/
#
# You can learn more about Ruby::XBee and other projects at http://sawdust.see-do.org
#
# see Digi product manual: "Product Manual v1.xCx - 802.15.4 Protocol"
# for details on the operation of XBee series 1 modules.

require 'date'
require 'pp'
require 'scanf'
require 'xbee_api'

begin
  gem 'ruby-serialport'
  require 'serialport'
  STDIN.sync = 1
  STDOUT.sync = 1
  $stdin.sync = true
  $stdout.sync = true
rescue LoadError => e
  puts "LoadError?! => #{e}"
  if require 'rubygems'
    puts "Okay, required rubygems. retrying now ..."
    retry
  end
end

module XBee
=begin rdoc
  a class method for getting results from any Ruby SerialPort object
=end
  def getresults( sp, echo = true )
    results = ""
    while (c = sp.getc) do
      if ( !echo.nil? && echo )
        putc c
      end
      results += "#{c.chr}"
    end

    # deal with multiple lines
    results.gsub!( "\r", "\n")
  end

  class Base
    include XBee
    attr_accessor :xbee_serialport, :guard_time

    # XBee response times vary based on both hardware and firmware versions.  These
    # constants may need to be adjusted for your devices, but these will
    # work fine for most cases.  The unit of time for a timeout constant is ms

    TYPICAL_READ_TIMEOUT = 1200
    LONG_READ_TIMEOUT    = 3000

    VERSION = "1.0"                 # version of this class

=begin rdoc
  Sends an AT command to the XBee device and returns any output collected as a result of that command
=end
    def send_command_and_get_result(at_command, echo = false)
      @xbee_serialport.write("#{at_command}\r")
      @xbee_serialport.flush
      @xbee_serialport.gets("\r")
    end

=begin rdoc
  initializes the communication link with the XBee device.  These parameters must match those which
  are configured in the XBee in order to establish communication.

  xbee_usbdev_str is a path to the device used to communicate with the XBee.  Typically it may
  look like:  /dev/tty.usbserial-A80081sF if you're using a USB to serial converter or a device such
  as http://www.sparkfun.com/commerce/product_info.php?products_id=8687
=end
    def initialize( xbee_usbdev_str, baud, data_bits, stop_bits, parity )
      # open serial port device to XBee
      @xbee_serialport = SerialPort.new( xbee_usbdev_str, baud.to_i, data_bits.to_i, stop_bits.to_i, parity )
      #@xbee_serialport.flow_control = (SerialPort::HARD)
      @xbee_serialport.read_timeout = TYPICAL_READ_TIMEOUT
      @baudcodes = { 1200 => 0, 2400 => 1, 4800 => 2, 9600 => 3, 19200 => 4, 38400 => 5, 57600 => 6, 115200 => 7 }
      @paritycodes = { :None => 0, :Even => 1, :Odd => 2, :Mark => 3, :Space => 4 }
      @iotypes = { :Disabled => 0, :ADC => 2, :DI => 3, :DO_Low => 4, :DO_High => 5,
                   :Associated_Indicator => 1, :RTS => 1, :CTS => 1, :RS485_Low => 6, :RS485_High => 7 }
    end

    def guard_time(command_mode=false)
      @guard_time_configuration_read ||= false
      if command_mode && !@guard_time_configuration_read then
        gt = send_command_and_get_result("ATGT")
        @guard_time = Integer("0x#{gt}")
        @guard_time_configuration_read = true
      end
      @guard_time ||= 1000.0
    end

=begin rdoc
  Guard time (ATGT / @guard_time) is defined in milliseconds; this routine returns the equivalent time in seconds
=end
    def guard_time_secs
      guard_time / 1000.0
    end

=begin rdoc
  Puts the XBee into AT command mode and insures that we can bring it to attention.
  The expected return value is "OK"
=end
    def attention
      sleep guard_time_secs + 0.1
      @xbee_serialport.write("+++")
      sleep guard_time_secs + 0.1
      getresponse   # flush up to +++ response if needed
      guard_time(true)
      # if XBee is already in command mode, there will be no response, so make an explicit
      # AT call to insure an OK response
      send_command_and_get_result("AT")
    end

=begin rdoc
  Retrieve XBee firmware version
=end
    def fw_rev
      send_command_and_get_result("ATVR")
    end

=begin rdoc
  Retrieve XBee hardware version
=end
    def hw_rev
      send_command_and_get_result("ATHV")
    end

=begin rdoc
  returns the source address of the XBee device - the MY address value
=end
    def my_src_address
      send_command_and_get_result("ATMY")
    end

=begin rdoc
  sets the 16-bit source address of the XBee device.  The parameter should be a 16-bit hex value.
  The factory default is 0.  By setting the MY src address to 0xffff, 16-bit addressing is disabled
  and the XBee will not listen for packets with 16-bit address fields
=end
    def my_src_address!(new_addr)
      send_command_and_get_result("ATMY#{new_addr}")
    end

=begin rdoc
  returns the low portion of the XBee device's current destination address
=end
    def destination_low
      send_command_and_get_result("ATDL")
    end

=begin rdoc
  sets the low portion of the XBee device's destination address
=end
    def destination_low!(low_addr)
      send_command_and_get_result("ATDL#{low_addr}")
    end

=begin rdoc
  returns the high portion of the XBee device's current destination address
=end
    def destination_high
      send_command_and_get_result("ATDH")
    end

=begin rdoc
  sets the high portion of the XBee device's current destination address
=end
    def destination_high!(high_addr)
      send_command_and_get_result("ATDH#{high_addr}")
    end

=begin rdoc
  returns the low portion of the XBee device's serial number. this value is factory set.
=end
    def serial_num_low
      send_command_and_get_result("ATSL")
    end

=begin rdoc
  returns the high portion of the XBee devices serial number. this value is factory set.
=end
    def serial_num_high
      send_command_and_get_result("ATSH")
    end

=begin rdoc
  sets the channel number of the device.  The valid channel numbers are those of the 802.15.4 standard.
=end
    def channel!(new_channel)
      # channel takes more than 1000ms to return data
      tmp = @xbee_serialport.read_timeout
      @xbee_serialport.read_timeout = LONG_READ_TIMEOUT
      @xbee_serialport.write("ATCH#{new_channel}\r")
      response = getresponse
      @xbee_serialport.read_timeout = tmp
      response.strip.chomp
    end

=begin rdoc
  returns the node ID of the device.  Node ID is typically a human-meaningful name
  to give to the XBee device, much like a hostname.
=end
    def node_id
      tmp = @xbee_serialport.read_timeout
      @xbee_serialport.read_timeout = LONG_READ_TIMEOUT
      @xbee_serialport.write("ATNI\r")
      response = getresponse
      @xbee_serialport.read_timeout = tmp
      if ( response.nil? )
        return ""
      else
        response.strip.chomp
      end
    end

=begin rdoc
  sets the node ID to a user-definable text string to make it easier to
  identify the device with "human" names.  This node id is reported to
  neighboring XBees so consider it "public".
=end
    def node_id!(new_id)
      tmp = @xbee_serialport.read_timeout
      @xbee_serialport.read_timeout = LONG_READ_TIMEOUT
      @xbee_serialport.write("ATNI#{new_id}\r")
      response = getresponse
      @xbee_serialport.read_timeout = tmp
      if ( response.nil? )
        return ""
      else
        response.strip.chomp
      end
    end
=begin rdoc
  returns the PAN ID of the device.  PAN ID is one of the 3 main identifiers used to
  communicate with the device from other XBees.  All XBees which are meant to communicate
  must have the same PAN ID and channel number.  The 3rd identifier is the address of the
  device itself represented by its serial number (High and Low) and/or it's 16-bit MY
  source address.
=end
    def pan_id
      @xbee_serialport.write("ATID\r")
      getresponse
    end

=begin rdoc
  sets the PAN ID of the device.  Modules must have the same PAN ID in order to communicate
  with each other.  The PAN ID value can range from 0 - 0xffff.  The default from the factory
  is set to 0x3332.
=end
    def pan_id!(new_id)
      @xbee_serialport.write("ATID#{new_id}\r")
      getresponse
    end

=begin rdoc
  returns the signal strength in dBm units of the last received packet.  Expect a negative integer
  or 0 to be returned.  If the XBee device has not received any neighboring packet data, the signal strength
  value will be 0
=end
    def received_signal_strength
      @xbee_serialport.write("ATDB\r")
      response = getresponse().strip.chomp
      # this response is an absolute hex value which is in -dBm
      # modify this so it returns actual - dBm value
      dbm = -(response.hex)
    end

=begin rdoc
  retrieves the baud rate of the device.  Generally, this will be the same as the
  rate you're currently using to talk to the device unless you've changed the device's
  baud rate and are still in the AT command mode and/or have not exited command mode explicitly for
  the new baud rate to take effect.
=end
    def baud
      @xbee_serialport.write("ATBD\r")
      baudcode = getresponse
      @baudcodes.index( baudcode.to_i )
    end

=begin rdoc
  sets the given baud rate into the XBee device.  The baud change will not take
  effect until the AT command mode times out or the exit command mode command is given.
  acceptable baud rates are: 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200
  end
=end
   def baud!( baud_rate )
      @xbee_serialport.write("ATBD#{@baudcodes[baud_rate]}\r")
      getresponse
   end

=begin rdoc
  returns the parity of the device as represented by a symbol:
  :None - for 8-bit none
  :Even - for 8-bit even
  :Odd  - for 8-bit odd
  :Mark - for 8-bit mark
  :Space - for 8-bit space
=end
   def parity
     @xbee_serialport.write("ATNB\r")
     response = getresponse().strip.chomp
     @paritycodes.index( response.to_i )
   end

=begin rdoc
 sets the parity of the device to one represented by a symbol contained in the parity_type parameter
  :None - for 8-bit none
  :Even - for 8-bit even
  :Odd  - for 8-bit odd
  :Mark - for 8-bit mark
  :Space - for 8-bit space
=end
   def parity!( parity_type )
     # validate symbol before writing parity param
     if !@paritycodes.include?(parity_type)
       return false
     end
     @xbee_serialport.write("ATNB#{@paritycodes[parity_type]}\r")
     getresponse
   end

=begin rdoc
  reads an i/o port configuration on the XBee for analog to digital or digital input or output (GPIO)

  this method returns an I/O type symbol of:

    :Disabled
    :ADC
    :DI
    :DO_Low
    :DO_High
    :Associated_Indicator
    :RTS
    :CTS
    :RS485_Low
    :RS485_High

  Not all DIO ports are capable of every configuration listed above.  This method will properly translate
  the XBee's response value to the symbol above when the same value has different meanings from port to port.

  The port parameter may be any symbol :D0 through :D8 representing the 8 I/O ports on an XBee
=end

    def dio( port )
      at = "AT#{port.to_s}\r"
      @xbee_serialport.write( at )
      response = getresponse.to_i

      if response == 1  # the value of 1 is overloaded based on port number
        case port
        when :D5
          return :Associated_Indicator
        when :D6
          return :RTS
        when :D7
          return :CTS
        end
      else
        @iotypes.index(response)
      end

    end

=begin rdoc
  configures an i/o port on the XBee for analog to digital or digital input or output (GPIO)

  port parameter valid values are the symbols :D0 through :D8

  iotype parameter valid values are symbols:
    :Disabled
    :ADC
    :DI
    :DO_Low
    :DO_High
    :Associated_Indicator
    :RTS
    :CTS
    :RS485_Low
    :RS485_High

  note: not all iotypes are compatible with every port type, see the XBee manual for exceptions and semantics

  note: it is critical you have upgraded firmware in your XBee or DIO ports 0-4 cannot be read
        (ie: ATD0 will return ERROR - this is an XBee firmware bug that's fixed in revs later than 1083)

  note: tested with rev 10CD, fails with rev 1083
=end

    def dio!( port, iotype )
      at = "AT#{port.to_s}#{@iotypes[iotype]}\r"
      @xbee_serialport.write( at )
      getresponse
    end

=begin rdoc
  reads the bitfield values for change detect monitoring.  returns a bitmask indicating
  which DIO lines, 0-7 are enabled or disabled for change detect monitoring
=end
    def dio_change_detect
      @xbee_serialport.write("ATIC\r")
      getresponse
    end

=begin rdoc
  sets the bitfield values for change detect monitoring.  The hexbitmap parameter is a bitmap
  which enables or disables the change detect monitoring for any of the DIO ports 0-7
=end
    def dio_change_detect!( hexbitmap )
      @xbee_serialport.write("ATIC#{hexbitmask}\r")
      getresponse
    end

=begin rdoc
  Sets the digital output levels of any DIO lines which were configured for output using the dio! method.
  The parameter, hexbitmap, is a hex value which represents the 8-bit bitmap of the i/o lines on the
  XBee.
=end
    def io_output!( hexbitmap )
      @xbee_serialport.write("ATIO#{hexbitmap}\r")
      getresponse
    end

=begin rdoc
  Forces a sampling of all DIO pins configured for input via dio!
  Returns a hash with the following key/value pairs:
  :NUM => number of samples
  :CM => channel mask
  :DIO => dio data if DIO lines are enabled
  :ADCn => adc sample data (one for each ADC channel enabled)
=end
    def io_input

      tmp = @xbee_serialport.read_timeout
      @xbee_serialport.read_timeout = LONG_READ_TIMEOUT

      @xbee_serialport.write("ATIS\r")
      response = getresponse
      linenum = 1
      adc_sample = 1
      samples = Hash.new

      if response.match("ERROR")
        samples[:ERROR] = "ERROR"
        return samples
      end

      # otherwise parse input data
      response.each_line do | line |
        case linenum
        when 1
          samples[:NUM] = line.to_i
        when 2
          samples[:CM] = line.strip.chomp
        when 3
          samples[:DIO] = line.strip.chomp
        else
          sample = line.strip.chomp
          if ( !sample.nil? && sample.size > 0 )
            samples["ADC#{adc_sample}".to_sym] = line.strip.chomp
            adc_sample += 1
          end
        end

        linenum += 1
      end

      @xbee_serialport.read_timeout = tmp
      samples
    end

=begin rdoc
  writes the current XBee configuration to the XBee device's flash.   There
  is no undo for this operation
=end
    def save!
      @xbee_serialport.write("ATWR\r")
      getresponse
    end

=begin rdoc
  resets the XBee module through software and simulates a power off/on.   Any configuration
  changes that have not been saved with the save! method will be lost during reset.
=end
    def reset!
      @xbee_serialport.write("ATFR\r")
    end

=begin rdoc
  Restores all the module parameters to factory defaults
=end
    def restore!
      @xbee_serialport.write("ATRE\r")
    end

=begin rdoc
  just a straight pass through of data to the XBee.  This can be used to send
  data when not in AT command mode, or if you want to control the XBee with raw
  commands, you can send them this way.
=end
    def send!(message)
      @xbee_serialport.write( message )
    end


=begin rdoc
  exits the AT command mode - all changed parameters will take effect such as baud rate changes
  after the exit is complete.   exit_command_mode does not permanently save the parameter changes
  when it exits AT command mode.  In order to permanently change parameters, use the save! method
=end
    def exit_command_mode
      @xbee_serialport.write("ATCN\r")
    end

=begin rdoc
  returns the version of this class
=end
    def version
      VERSION
    end

=begin rdoc
  returns results from the XBee
  echo is disabled by default
=end
    def getresponse( echo = false )
      getresults( @xbee_serialport, echo )
    end

  end

  class V1 < Base

=begin rdoc
  returns the channel number of the XBee device.  this value, along with the PAN ID,
  and MY address determines the addressability of the device and what it can listen to
=end
    def channel
      # channel often takes more than 1000ms to return data
      tmp = @xbee_serialport.read_timeout
      @xbee_serialport.read_timeout = LONG_READ_TIMEOUT
      @xbee_serialport.write("ATCH\r")
      response = getresponse
      @xbee_serialport.read_timeout = tmp
      response && response.strip.chomp
    end

=begin rdoc
   Neighbor node discovery. Returns an array of hashes each element of the array contains a hash
   each hash contains keys:  :MY, :SH, :SL, :DB, :NI
   representing addresses source address, Serial High, Serial Low, Received signal strength,
   node identifier respectively.  Aan example of the results returned (hash as seen by pp):

     [{:NI=>" ", :MY=>"0", :SH=>"13A200", :SL=>"4008A642", :DB=>-24},
      {:NI=>" ", :MY=>"0", :SH=>"13A200", :SL=>"4008A697", :DB=>-33},
      {:NI=>" ", :MY=>"0", :SH=>"13A200", :SL=>"40085AD5", :DB=>-52}]

   Signal strength (:DB) is reported in units of -dBM.
=end rdoc
    def neighbors
      # neighbors often takes more than 1000ms to return data
      tmp = @xbee_serialport.read_timeout
      @xbee_serialport.read_timeout = LONG_READ_TIMEOUT
      @xbee_serialport.write("ATND\r")
      response = getresponse

      # parse nodes and stuff an array of hashes
      @neighbors = Array.new
      linetype = 0
      neighbor = 0

      if response.nil?
        return @neighbors   # return an empty array
      end

      response.each_line do | line |

        line.chomp!

        if line.size > 0
          case linetype
          when 0    # MY
              @neighbors[ neighbor ] = Hash.new
              @neighbors[ neighbor ].store( :MY, line )

          when 1    # SH
              @neighbors[ neighbor ].store( :SH, line )

          when 2    # SL
              @neighbors[ neighbor ].store( :SL, line )

          when 3    # DB
              @neighbors[ neighbor ].store( :DB, -(line.hex) )

          when 4    # NI
              @neighbors[ neighbor ].store( :NI, line )

              neighbor += 1
          end

          if linetype < 4
            linetype += 1
          else
            linetype = 0
          end
        end
      end

      @xbee_serialport.read_timeout = tmp
      @neighbors
    end
  end  # class V1


  class V2 < Base
    attr_accessor :node_discovery_timeout

    def initialize(*args)
      super(*args)
      @node_discovery_timeout = 0x82
    end

=begin rdoc
   Node discovery timeout (ATNT / @node_discovery_timeout) is defined in 100 msec increments; this routine returns the
   equivalent time in seconds
=end
    def node_discovery_timeout_secs
      return node_discovery_timeout / 10.0
    end

=begin rdoc
   Neighbor node discovery. Returns an array of hashes each element of the array contains a hash
   each hash contains keys:  :MY, :SH, :SL, :DB, :NI
   representing addresses source address, Serial High, Serial Low, Received signal strength,
   node identifier respectively.  Aan example of the results returned (hash as seen by pp):

     [{:NI=>" ", :MY=>"0", :SH=>"13A200", :SL=>"4008A642", :DB=>-24},
      {:NI=>" ", :MY=>"0", :SH=>"13A200", :SL=>"4008A697", :DB=>-33},
      {:NI=>" ", :MY=>"0", :SH=>"13A200", :SL=>"40085AD5", :DB=>-52}]

   Signal strength (:DB) is reported in units of -dBM.
=end rdoc
    def neighbors
      # neighbors often takes more than 1000ms to return data
      tmp = @xbee_serialport.read_timeout
      @xbee_serialport.read_timeout = (node_discovery_timeout * 100) + 1000
      @xbee_serialport.write("ATND\r")
      @xbee_serialport.flush
      sleep node_discovery_timeout_secs + 0.5

      # parse nodes and stuff an array of hashes
      neighbors = []
      #states = [:SH, :SL, :NI, :PARENT_NETWORK_ADDRESS, :DEVICE_TYPE, :STATUS, :PROFILE_ID, :MANUFACTURER_ID]
      #response = getresponse
      # puts response
      #response.scan(/FFFE\n(.*)\s(.*)\s(.*)\s(.*)\s(.*)\s(.*)\s(.*)\s(.*)\s\n/) do |sh, sl, ni, parent_network_address, device_type, status, profile_id, manufacturer_id|
      @xbee_serialport.scanf("FFFE\r%x\r%x\r%s\r%x\r%x\r%x\r%x\r%x\r\r") do |sh, sl, ni, parent_network_address, device_type, status, profile_id, manufacturer_id|
        puts "scanf returned something! sh=#{sh}, sl=#{sl}, ni=#{ni}, parent_network_address=#{parent_network_address}, device_type=#{device_type}, status=#{status}, profile_id=#{profile_id}, mfr_id=#{manufacturer_id}"
        neighbors << {
                :SH => sh,
                :SL => sl,
                :NI => ni,
                :PARENT_NETWORK_ADDRESS => parent_network_address,
                :DEVICE_TYPE => device_type,
                :STATUS => status,
                :PROFILE_ID => profile_id,
                :MANUFACTURER_ID => manufacturer_id,
        }
      end
      #response.each_line do | line |
      #  unless line.empty?
      #    if current_state == 0
      #      neighbors << current_neighbor unless current_neighbor.nil?
      #      current_neighbor = {}
      #    end
      #    current_neighbor[states[current_state]] = line.chomp
      #  end
      #  current_state = (current_state >= (states.length - 1)) ? 0 : current_state + 1
      #end
      @xbee_serialport.read_timeout = tmp
      neighbors
    end

=begin rdoc
  reads an i/o port configuration on the XBee for analog to digital or digital input or output (GPIO)

  this method returns an I/O type symbol of:

    :Disabled
    :ADC
    :DI
    :DO_Low
    :DO_High
    :Associated_Indicator
    :RTS
    :CTS
    :RS485_Low
    :RS485_High

  Not all DIO ports are capable of every configuration listed above.  This method will properly translate
  the XBee's response value to the symbol above when the same value has different meanings from port to port.

  The port parameter may be any symbol :D0 - :D7, :P0-:P2
=end

    def dio( port )
      at = "AT#{port.to_s}\r"
      @xbee_serialport.write( at )
      response = getresponse.to_i

      if response == 1  # the value of 1 is overloaded based on port number
        case port
        when :D5
          return :Associated_Indicator
        when :D6
          return :RTS
        when :D7
          return :CTS
        end
      else
        @iotypes.index(response)
      end

    end

=begin rdoc
  configures an i/o port on the XBee for analog to digital or digital input or output (GPIO)

  port parameter valid values are the symbols :D0 through :D8

  iotype parameter valid values are symbols:
    :Disabled
    :ADC
    :DI
    :DO_Low
    :DO_High
    :Associated_Indicator
    :RTS
    :CTS
    :RS485_Low
    :RS485_High

  note: not all iotypes are compatible with every port type, see the XBee manual for exceptions and semantics

  note: it is critical you have upgraded firmware in your XBee or DIO ports 0-4 cannot be read
        (ie: ATD0 will return ERROR - this is an XBee firmware bug that's fixed in revs later than 1083)

  note: tested with rev 10CD, fails with rev 1083
=end

    def dio!( port, iotype )
      at = "AT#{port.to_s}#{@iotypes[iotype]}\r"
      @xbee_serialport.write( at )
      getresponse
    end

=begin rdoc
  Retrieve XBee firmware version
=end
    def version_long
      @xbee_serialport.write("ATVL\r")
      response = getresponse
      response && response.strip.chomp
    end

    def enter_api_mode(noisy = false)
      attention
      if noisy
        print "Requesting API mode ... "
        puts send_command_and_get_result("ATAP1")
        print "Exiting from command mode ... "
        puts send_command_and_get_result("ATCN")
      else
        send_command_and_get_result("ATAP1")
        send_command_and_get_result("ATCN")
      end
    end

    def test_api
      version_cmd = XBee::Frame::ATCommand.new("VL",69,nil)
      #puts "Main thread still printing to screen ..."
      #dumped_cmd = version_cmd._dump
      #print "Sending the following bytes out on the serial port: #{dumped_cmd.unpack("c*").map {|c| "%x" % c } .join(",")} ..."
      @xbee_serialport.write(version_cmd._dump)
      @xbee_serialport.flush
      Thread.new do
        begin
          while rcv_frame = XBee::Frame.factory(@xbee_serialport)
            pp rcv_frame
          end
        rescue EOFError
          retry
        end
      end
      sleep 30
    end
  end
end  # module XBee

=begin rdoc
  reads lines from a given serial port object until there are no more lines left to read (timesout with @xbee.serial_timeout value)
=end

