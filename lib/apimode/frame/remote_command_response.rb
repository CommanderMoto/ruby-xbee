require 'at_command_response'

module XBee
  module Frame
    class RemoteCommandResponse < ATCommandResponse
      attr_accessor :destination_address, :destination_network
      def cmd_data=(data_string)
        dest_high = dest_low = 0
        self.frame_id, dest_high, dest_low, self.destination_network, self.at_command, status_byte, self.retrieved_value = data_string.unpack("CNNna2Ca*")
        self.destination_address = dest_high << 32 | dest_low
        self.status = case status_byte
        when 0..3 : command_statuses[status_byte]
        else raise "AT Command Response frame appears to include an invalid status: 0x%x" % status_byte
        end
        #actually assign and move along
        @cmd_data = data_string
      end
    end
  end
end
