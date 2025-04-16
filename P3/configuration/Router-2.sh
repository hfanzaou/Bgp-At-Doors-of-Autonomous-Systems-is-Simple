# Create a Linux bridge named "br0"
ip link add br0 type bridge
# activate the bridge interface
ip link set dev br0 up
# Create a VXLAN tunnel interface "vxlan10" with VXLAN ID 10 and destination default VXLAN port
ip link add vxlan10 type vxlan id 10 dstport 4789
# Bring the VXLAN interface "vxlan10" up
ip link set dev vxlan10 up
# Add the VXLAN interface to the bridge "br0"
brctl addif br0 vxlan10
# Add physical interface "eth1" to the bridge "br0"
brctl addif br0 eth1

# Enter vtysh command-line interface for router configuration
vtysh
conf t
                        # configuration         
interface eth0
    ip address 10.1.1.2/30
    # Enable OSPF and assign this interface to OSPF Area 0
    ip ospf area 0
    # Configure loopback interface with IP address 1.1.1.2/32 
interface lo
    ip address 1.1.1.2/32
    ip ospf area 0

# Begin BGP configuration for AS 65002
router bgp 65002
    # Specify the remote AS
    neighbor 1.1.1.1 remote-as 65002
    # Use the loopback interface as the source IP for BGP updates   
    neighbor 1.1.1.1 update-source lo
    # Enter the EVPN address family (Ethernet VPN over BGP for Layer 2 connectivity)
    address-family l2vpn evpn
    # Activate EVPN for the BGP neighbor 1.1.1.1
        neighbor 1.1.1.1 activate
        # Advertise all VNI (Virtual Network Identifier) in the EVPN
        advertise-all-vni    
    exit-address-family
# Configure OSPF
router ospf

end
exit

