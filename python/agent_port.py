import checks.system
import logging
import sys
log = logging.getLogger()
config = {}

from erlport import Port, Protocol, String

cpu = checks.system.Cpu()

# Inherit custom protocol from erlport.Protocol
class AgentProtocol(Protocol):

    # Function handle_NAME will be called for incoming tuple {NAME, ...}
    def handle_check(self):
    	data = cpu.check(log, config)
    	#print >> sys.stderr, "agent_port: {0}".format(data)
    	return data


if __name__ == "__main__":
    proto = AgentProtocol()
    # Run protocol with port open on STDIO
    proto.run(Port(use_stdio=True))

