require 'at_command'

module XBee
  module Frame
    class RemoteCommandRequest < ATCommand
      def api_identifier ; 0x17 ; end

      attr_accessor :destination_address, :destination_network

      def initialize(at_command, destination_address = 0x000000000000ffff, destination_network = 0x0000fffe, frame_id = nil, parameter_value = nil, parameter_pack_string = "a*")
        self.destination_address = destination_address
        self.destination_network = destination_network
        super(at_command, frame_id, parameter_value, parameter_pack_string)
        yield self if block_given?
      end

      def cmd_data=(data_string)
        dest_high = dest_low = 0
        self.frame_id, dest_high, dest_low, self.destination_network, self.at_command, self.parameter_value = data_string.unpack("CNNnxa2#{parameter_pack_string}")
        self.destination_address = dest_high << 32 | dest_low
      end

      def cmd_data
        dest_high = (self.destination_address >> 32) & 0xFFFFFFFF
        dest_low = self.destination_address & 0xFFFFFFFF
        if parameter_value.nil?
          [self.frame_id, dest_high, dest_low, self.destination_network, 0x00, self.at_command].pack("CNNnCa2")
        else
          [self.frame_id, dest_high, dest_low, self.destination_network, 0x02, self.at_command, self.parameter_value].pack("CNNnCa2#{parameter_pack_string}")
        end
      end
    end
  end
end
