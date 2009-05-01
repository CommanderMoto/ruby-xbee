module XBee
  module Frame
    class ModemStatus < ReceivedFrame
      attr_accessor :status

      def initialize(data = nil)
        super(data) && (yield self if block_given?)
      end

      def modem_statuses
        [
          [1, :Hardware_Reset],
          [2, :Watchdog_Timer_Reset],
          [3, :Associated],
        ]
      end

      def cmd_data=(data_string)
        status_byte = data_string.unpack("c")
        # update status ivar for later use
        self.status = case status_byte
        when 1..3 : modem_statuses.assoc(status_byte)
        else raise "ModemStatus frame appears to include an invalid status value: #{data_string}"
        end
        #actually assign and move along
        @cmd_data = data_string
      end
    end
  end
end
