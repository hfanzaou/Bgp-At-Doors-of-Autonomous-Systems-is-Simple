# Enter vtysh command-line interface for router configuration
vtysh
conf t
                                    # configuration
interface eth0
    ip address 10.1.1.1/30

interface eth1
    ip address 10.1.1.5/30

interface eth2
    ip address 10.1.1.9/30

interface lo
    ip address 1.1.1.1/32

# BGP configuration starts here
router bgp 65002
    # Define a peer-group named 'ibgp' for easier neighbor management
    neighbor ibgp peer-group
    # Set remote AS for the peer group (same as ours since it's iBGP)
    neighbor ibgp remote-as 65002
    # Use the loopback interface as the source for BGP sessions
    neighbor ibgp update-source lo
    # Dynamically listen for neighbors in the 1.1.1.0/29 subnet and assign them to the 'ibgp' peer-group
    bgp listen range 1.1.1.0/29 peer-group ibgp
    # Enter the address-family for EVPN (used for Layer 2 VPN over BGP)
    address-family l2vpn evpn
        # Activate the 'ibgp' peer-group in this address-family
        neighbor ibgp activate
        # This router acts as a Route Reflector for all 'ibgp' clients
        neighbor ibgp route-reflector-client
    exit-address-family
#  Enable OSPF and include all interfaces in Area 0
router ospf
    network 0.0.0.0/0 area 0

end
exit
