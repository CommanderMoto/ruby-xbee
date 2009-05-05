$: << File.dirname(__FILE__)
require 'frame/frame'
require File.dirname(File.dirname(__FILE__)) + '/ruby_xbee'

module XBee
  class BaseAPIModeInterface < RFModule
    def initialize(xbee_usbdev_str, uart_config = XBeeUARTConfig.new)
      super(xbee_usbdev_str, uart_config)
      @frame_id = 1
      start_apimode_communication
    end

    def next_frame_id
      @frame_id += 1
    end

    def start_apimode_communication
      in_command_mode do
        puts "Entering api mode"
        # Reset module parameters to factory defaults ...
        self.xbee_serialport.write("ATRE\r")
        self.xbee_serialport.read(3)
        # Set API Mode 2 (include escaped characters)
        self.xbee_serialport.write("ATAP2\r")
        self.xbee_serialport.read(3)
      end
      #@frames ||= []
      #@read_thread = Thread.new {  loop {  @frames << XBee::Frame.new(self.xbee_serialport) } rescue retry }
    end

    def get_param(at_param_name, at_param_unpack_string = nil)
      frame_id = self.next_frame_id
      at_command_frame = XBee::Frame::ATCommand.new(at_param_name,frame_id,nil,at_param_unpack_string)
      # puts "Sending ... [#{at_command_frame._dump.unpack("C*").join(", ")}]"
      self.xbee_serialport.write(at_command_frame._dump)
      r = XBee::Frame.new(self.xbee_serialport)
      if r.kind_of?(XBee::Frame::ATCommandResponse) && r.status == :OK && r.frame_id == frame_id
        if block_given?
          yield r
        else
          at_param_unpack_string.nil? ? r.retrieved_value : r.retrieved_value.unpack(at_param_unpack_string).first
        end
      else
        raise "Response did not indicate successful retrieval of that parameter: #{r.inspect}"
      end
    end

    def set_param(at_param_name, param_value, at_param_unpack_string = nil)
      frame_id = self.next_frame_id
      at_command_frame = XBee::Frame::ATCommand.new(at_param_name,frame_id,param_value,at_param_unpack_string)
      # puts "Sending ... [#{at_command_frame._dump.unpack("C*").join(", ")}]"
      self.xbee_serialport.write(at_command_frame._dump)
      r = XBee::Frame.new(self.xbee_serialport)
      if r.kind_of?(XBee::Frame::ATCommandResponse) && r.status == :OK && r.frame_id == frame_id
        if block_given?
          yield r
        else
          at_param_unpack_string.nil? ? r.retrieved_value : r.retrieved_value.unpack(at_param_unpack_string).first
        end
      else
        raise "Response did not indicate successful retrieval of that parameter: #{r.inspect}"
      end
    end

    def get_remote_param(at_param_name, remote_address = 0x000000000000ffff, remote_network_address = 0xfffe, at_param_unpack_string = nil)
      frame_id = self.next_frame_id
      at_command_frame = XBee::Frame::RemoteCommandRequest.new(at_param_name, remote_address, remote_network_address, frame_id, nil, at_param_unpack_string)
      puts "Sending ... [#{at_command_frame._dump.unpack("C*").join(", ")}]"
      self.xbee_serialport.write(at_command_frame._dump)
      r = XBee::Frame.new(self.xbee_serialport)
      if r.kind_of?(XBee::Frame::RemoteCommandResponse) && r.status == :OK && r.frame_id == frame_id
        if block_given?
          yield r
        else
          at_param_unpack_string.nil? ? r.retrieved_value : r.retrieved_value.unpack(at_param_unpack_string).first
        end
      else
        raise "Response did not indicate successful retrieval of that parameter: #{r.inspect}"
      end
    end

    def set_remote_param(at_param_name, param_value, remote_address = 0x000000000000ffff, remote_network_address = 0xfffe, at_param_unpack_string = nil)
      frame_id = self.next_frame_id
      at_command_frame = XBee::Frame::RemoteCommandRequest.new(at_param_name, remote_address, remote_network_address, frame_id, param_value, at_param_unpack_string)
      puts "Sending ... [#{at_command_frame._dump.unpack("C*").join(", ")}]"
      self.xbee_serialport.write(at_command_frame._dump)
      r = XBee::Frame.new(self.xbee_serialport)
      if r.kind_of?(XBee::Frame::RemoteCommandResponse) && r.status == :OK && r.frame_id == frame_id
        if block_given?
          yield r
        else
          at_param_unpack_string.nil? ? r.retrieved_value : r.retrieved_value.unpack(at_param_unpack_string).first
        end
      else
        raise "Response did not indicate successful retrieval of that parameter: #{r.inspect}"
      end
    end

    def version_long
      @version_long ||= get_param("VL","a*")
    end

=begin rdoc
  Retrieve XBee firmware version
=end
    def fw_rev
      @fw_rev ||= get_param("VR","n")
    end

=begin rdoc
  Retrieve XBee hardware version
=end
    def hw_rev
      @hw_rev ||= get_param("HV","n")
    end

    ##
    # Neighbor node discovery. Returns an array of hashes each element of the array contains a hash
    # each hash contains keys:  :MY, :SH, :SL, :DB, :NI
    # representing addresses source address, Serial High, Serial Low, Received signal strength,
    # node identifier respectively.  Aan example of the results returned (hash as seen by pp):
    #
    #   [{:NI=>" ", :MY=>"0", :SH=>"13A200", :SL=>"4008A642", :DB=>-24},
    #    {:NI=>" ", :MY=>"0", :SH=>"13A200", :SL=>"4008A697", :DB=>-33},
    #    {:NI=>" ", :MY=>"0", :SH=>"13A200", :SL=>"40085AD5", :DB=>-52}]
    #
    # Signal strength (:DB) is reported in units of -dBM.
    def neighbors
      frame_id = self.next_frame_id
      # neighbors often takes more than 1000ms to return data
      node_discover_cmd = XBee::Frame::ATCommand.new("ND",frame_id,nil)
      #puts "Node discover command dump: #{node_discover_cmd._dump.unpack("C*").join(", ")}"
      tmp = @xbee_serialport.read_timeout
      @xbee_serialport.read_timeout = Integer(self.node_discover_timeout.in_seconds * 1050)
      @xbee_serialport.write(node_discover_cmd._dump)
      responses = []
      #read_thread = Thread.new do
      begin
        loop do
          r = XBee::Frame.new(self.xbee_serialport)
          # puts "Got a response! Frame ID: #{r.frame_id}, Command: #{r.at_command}, Status: #{r.status}, Value: #{r.retrieved_value}"
          if r.kind_of?(XBee::Frame::ATCommandResponse) && r.status == :OK && r.frame_id == frame_id
            if r.retrieved_value.empty?
              # w00t - the module is telling us it's done with the discovery process.
              break
            else
            responses << r
            end
          else
            raise "Unexpected response to ATND command: #{r.inspect}"
          end
        end
      rescue Exception => e
        puts "Okay, must have finally timed out on the serial read: #{e}."
      end
      #end
      @xbee_serialport.read_timeout = tmp
      #read_thread.join
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
  returns the low portion of the XBee device's current destination address
=end
    def destination_low
      @destination_low ||= get_param("DL")
    end

=begin rdoc
  sets the low portion of the XBee device's destination address
=end
    def destination_low!(low_addr)
      @xbee_serialport.write("ATDL#{low_addr}\r")
      getresponse
    end

=begin rdoc
  returns the high portion of the XBee device's current destination address
=end
    def destination_high
      @destination_high ||= get_param("DH")
    end

=begin rdoc
  sets the high portion of the XBee device's current destination address
=end
    def destination_high!(high_addr)
      self.xbee_serialport.write("ATDH#{high_addr}\r")
      getresponse
    end

    ##
    # returns the low portion of the XBee device's serial number. this value is factory set.
    def serial_num_low
      @serial_low ||= get_param("SL","N")
    end

    ##
    # returns the high portion of the XBee device's serial number. this value is factory set.
    def serial_num_high
      @serial_high ||= get_param("SH","N")
    end

    def serial_num
      self.serial_num_high() << 32 | self.serial_num_low
    end

    ##
    # returns the channel number of the XBee device.  this value, along with the PAN ID,
    # and MY address determines the addressability of the device and what it can listen to
    def channel
      # channel often takes more than 1000ms to return data
      tmp = @xbee_serialport.read_timeout
      @xbee_serialport.read_timeout = read_timeout(:long)
      @xbee_serialport.write("ATCH\r")
      response = getresponse
      @xbee_serialport.read_timeout = tmp
      response.strip.chomp
    end

    ##
    # sets the channel number of the device.  The valid channel numbers are those of the 802.15.4 standard.
    def channel!(new_channel)
      # channel takes more than 1000ms to return data
      tmp = @xbee_serialport.read_timeout
      @xbee_serialport.read_timeout = read_timeout(:long)
      @xbee_serialport.write("ATCH#{new_channel}\r")
      response = getresponse
      @xbee_serialport.read_timeout = tmp
      response.strip.chomp
    end

    ##
    # returns the node ID of the device.  Node ID is typically a human-meaningful name
    # to give to the XBee device, much like a hostname.
    def node_id
      @node_id ||= get_param("NI")
      #tmp = @xbee_serialport.read_timeout
      #@xbee_serialport.read_timeout = read_timeout(:long)
      #@xbee_serialport.write("ATNI\r")
      #response = getresponse
      #@xbee_serialport.read_timeout = tmp
      #if ( response.nil? )
      #  return ""
      #else
      #  response.strip.chomp
      #end
    end

    ##
    # sets the node ID to a user-definable text string to make it easier to
    # identify the device with "human" names.  This node id is reported to
    # neighboring XBees so consider it "public".
    def node_id!(new_id)
      tmp = @xbee_serialport.read_timeout
      @xbee_serialport.read_timeout = read_timeout(:long)
      @xbee_serialport.write("ATNI#{new_id}\r")
      response = getresponse
      @xbee_serialport.read_timeout = tmp
      if ( response.nil? )
        return ""
      else
        response.strip.chomp
      end
    end

    ##
    # returns the PAN ID of the device.  PAN ID is one of the 3 main identifiers used to
    # communicate with the device from other XBees.  All XBees which are meant to communicate
    # must have the same PAN ID and channel number.  The 3rd identifier is the address of the
    # device itself represented by its serial number (High and Low) and/or it's 16-bit MY
    # source address.
    def pan_id
      @pan_id ||= get_param("ID").unpack("n")
    end

    ##
    # sets the PAN ID of the device.  Modules must have the same PAN ID in order to communicate
    # with each other.  The PAN ID value can range from 0 - 0xffff.  The default from the factory
    # is set to 0x3332.
    def pan_id!(new_id)
      @xbee_serialport.write("ATID#{new_id}\r")
      getresponse
    end

    ##
    # returns the signal strength in dBm units of the last received packet.  Expect a negative integer
    # or 0 to be returned.  If the XBee device has not received any neighboring packet data, the signal strength
    # value will be 0
    def received_signal_strength
      -(get_param("DB").hex)
    end

    ##
    # retrieves the baud rate of the device.  Generally, this will be the same as the
    # rate you're currently using to talk to the device unless you've changed the device's
    # baud rate and are still in the AT command mode and/or have not exited command mode explicitly for
    # the new baud rate to take effect.
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
      @xbee_serialport.read_timeout = read_timeout(:long)

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

  class Series1APIModeInterface < BaseAPIModeInterface
    ##
    # returns the source address of the XBee device - the MY address value
    def my_src_address
      @my_src_address ||= get_param("MY")
    end
  end  # class Series1APIModeInterface

  class Series2APIModeInterface < BaseAPIModeInterface

  end # class Series2APIModeInterface
end
