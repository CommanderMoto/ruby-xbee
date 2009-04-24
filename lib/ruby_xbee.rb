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
require 'timeout'

begin
  gem 'ruby-serialport'
  require 'serialport'
rescue LoadError => e
  puts "LoadError?! => #{e}"
  if require 'rubygems'
    puts "Okay, required rubygems. retrying now ..."
    retry
  end
end

module XBee
  class RFModule
    attr_accessor :xbee_serialport, :node_discovery_timeout

    # XBee response times vary based on both hardware and firmware versions.  These
    # constants may need to be adjusted for your devices, but these will
    # work fine for most cases.  The unit of time for a timeout constant is ms

    TYPICAL_READ_TIMEOUT = 1200
    LONG_READ_TIMEOUT    = 3000

    VERSION = "1.0"                 # version of this class

    def baudcodes
      { 1200 => 0, 2400 => 1, 4800 => 2, 9600 => 3, 19200 => 4, 38400 => 5, 57600 => 6, 115200 => 7 }
    end

    def paritycodes
      { :None => 0, :Even => 1, :Odd => 2, :Mark => 3, :Space => 4 }
    end

    def iotypes
      { :Disabled => 0, :ADC => 2, :DI => 3, :DO_Low => 4, :DO_High => 5, :Associated_Indicator => 1,
              :RTS => 1, :CTS => 1, :RS485_Low => 6, :RS485_High => 7 }
    end

=begin rdoc
  initializes the communication link with the XBee device.  These parameters must match those which
  are configured in the XBee in order to establish communication.

  xbee_usbdev_str is a path to the device used to communicate with the XBee.  Typically it may
  look like:  /dev/tty.usbserial-A80081sF if you're using a USB to serial converter or a device such
  as http://www.sparkfun.com/commerce/product_info.php?products_id=8687
=end
    def initialize( xbee_usbdev_str = "/dev/tty.usbserial-A7004nmf", baud = 9600, data_bits = 8, stop_bits = 1,
            parity = 0, skip_apimode_init = false)
      # open serial port device to XBee
      @xbee_serialport = SerialPort.new( xbee_usbdev_str, Integer(baud), Integer(data_bits), Integer(stop_bits), Integer(parity))
      @xbee_serialport.read_timeout = TYPICAL_READ_TIMEOUT
      @api_read_frames ||= []
      start_apimode_communication unless skip_apimode_init
      #@api_read_thread = Thread.new { loop { puts "read thread still going" && @api_read_frames << XBee::Frame.factory(@xbee_serialport) rescue retry } }
      @node_discovery_timeout = 0x82
    end

    def start_apimode_communication
      sleep guard_time_secs
      @xbee_serialport.write("+++")
      sleep guard_time_secs
      puts @xbee_serialport.read(3)
      # Reset module parameters to factory defaults ...
      @xbee_serialport.write("ATRE\r")
      puts @xbee_serialport.read(3)
      # Set API Mode 2 (include escaped characters)
      @xbee_serialport.write("ATAP2\r")
      puts @xbee_serialport.read(3)
      # Exit command mode
      @xbee_serialport.write("ATCN\r")
      puts @xbee_serialport.read(3)
    end

=begin rdoc
  TODO: Rather than counting on the default, this should probably actually query the ATGT parameter at some point
=end
    def guard_time
      @guard_time ||= 1000.0
    end

=begin rdoc
  Guard time (ATGT / @guard_time) is defined in milliseconds; this routine returns the equivalent time in seconds
=end
    def guard_time_secs
      guard_time / 1000.0
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
      node_discover_cmd = XBee::Frame::ATCommand.new("ND",69,nil)
      #puts "Node discover command dump: #{node_discover_cmd._dump.unpack("C*").join(", ")}"
      @xbee_serialport.read_timeout = Integer(node_discovery_timeout_secs * 1050)
      @xbee_serialport.write(node_discover_cmd._dump)
      @xbee_serialport.flush
      responses = []
      begin
        loop do
          r = XBee::Frame.factory(@xbee_serialport)
          # puts "Got a response! Frame ID: #{r.frame_id}, Command: #{r.at_command}, Status: #{r.status}, Value: #{r.retrieved_value}"
          if r.retrieved_value.length > 10
            responses << r
          elsif r.cmd_data =~ /ND/
            break
          else
            puts "Unexpected response to ATND command: #{r.inspect}"
          end
        end
      rescue Exception => e
        puts "Okay, must have finally timed out on the serial read: #{e}."
      end

      responses.map do |r|
        unpacked_fields = r.retrieved_value.unpack("nNNZxnCCnn")
        return_fields = [:SH, :SL, :NI, :PARENT_NETWORK_ADDRESS, :DEVICE_TYPE, :STATUS, :PROFILE_ID, :MANUFACTURER_ID]
        unpacked_fields.shift #Throw out the junk at the start of the discover packet
        return_fields.inject(Hash.new) do |return_hash, field_name|
          return_hash[field_name] = unpacked_fields.shift
          return_hash
        end
      end
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

