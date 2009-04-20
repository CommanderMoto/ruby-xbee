require "../serialport.so"

port_str = "/dev/tty.usbserial-A9003Ptt" 

baud_rate = 115200
data_bits = 8
stop_bits = 1
parity = SerialPort::NONE

@sp = SerialPort.new(port_str, baud_rate, data_bits, stop_bits, parity)
@sp.read_timeout = 500

STDIN.sync = 1
STDOUT.sync = 1



def getresults

    while (c = @sp.getc) do
      printf("%c", c )
    end

end

  while 1 do
    @sp.write( "help\r" )
    getresults

    @sp.write( "stats\r" )
    getresults

    @sp.write( "siphon list\r" )
    getresults

    @sp.write( "port list\r" )
    getresults

  end

sp.close
