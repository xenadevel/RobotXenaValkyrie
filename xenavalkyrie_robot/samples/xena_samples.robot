*** Settings ***
Library    OperatingSystem
Library    Collections
Library    xenavalkyrie.xena_robot.XenaRobot    socket    robot    localhost

*** Variables ***
${WS_DIR}       /usr/bin
${CAP_FILE}     /tmp/robot_cap_file.pcap
${CHASSIS}      192.168.1.197
${PORT1}        0/0
${PORT2}        0/1
@{PORTS}        ${CHASSIS}/${PORT1}    ${CHASSIS}/${PORT2}
${CONFIG_FILE}	${CURDIR}/test_config.xpc

*** Keywords ***
Reserve All Ports
    [Documentation]    Reserve ports and load same configuration on all ports.
    Log List           ${PORTS}
    Reserve Ports      @{PORTS}
    :FOR    ${PORT}    IN    @{PORTS}
    \    Load Config        ${PORT}    ${CONFIG_FILE}

*** Test Cases ***
Connect
    [Documentation]    Open session, connect to Xena Chassis and reserve ports
    Add Chassis        ${CHASSIS}
    Reserve All Ports

Investigate Configuration
    [Documentation]        Investigate laded configuration for port 0
    ${p_txmode} =          Get Port Attribute    @{PORTS}[0]    p_txmode 
    Log                    p_config = ${p_txmode}
    ${ps_packetlimit} =    Get Stream Attribute     @{PORTS}[0]    0    ps_packetlimit
    Log                    ps_packetlimit = ${ps_packetlimit}
    ${headers} =           Get Packet    @{PORTS}[0]    1
    Log                    headers = ${headers}
    &{header} =            Get Packet Header    @{PORTS}[0]    1    Ethernet
    Log Dictionary         ${header}
    &{header} =            Get Packet Header    @{PORTS}[0]    1    VLAN[0]
    Log Dictionary         ${header}
    &{header} =            Get Packet Header    @{PORTS}[0]    1    IP6
    Log Dictionary         ${header}
    &{modifier} =          Get Modifier    @{PORTS}[0]    0    0
    Log Dictionary         ${modifier}

Build Configuration
    [Documentation]        Build new configuration for port 1
    Reset Port             @{PORTS}[1]
    Set Port Attributes    @{PORTS}[1]    p_txmode=NORMAL
    Add Stream             @{PORTS}[1]    stream 0
    # Call stream commands with stream ID
    Set Stream Attributes  @{PORTS}[1]    0    ps_packetlimit=80    ps_ratepps=10
    Add Stream             @{PORTS}[1]    stream 1
    # Call stream commands with stream name
    Set Stream Attributes  @{PORTS}[1]    stream 1   ps_packetlimit=80    ps_ratepps=10
    # Order matters - add segments by their order. But case does not...
    Add Packet Headers     @{PORTS}[1]    0    ip    udp
    Set Packet Header Fields     @{PORTS}[1]    0    ethernet    src_s=11:11:11:11:11:11
    Set Packet Header Fields     @{PORTS}[1]    0    ip    src_s=1.1.1.1
    Set Packet Header Fields     @{PORTS}[1]    0    ip    dst_s=2.2.2.2
    Add Packet Headers     @{PORTS}[1]    1    VLAN    IP6    TCP
    Set Packet Header Fields     @{PORTS}[1]    1    VLAN[0]    vid=17
    Set Packet Header Fields     @{PORTS}[1]    1    IP6    src_s=11::11    dst_s=22::22
    Add Modifier           @{PORTS}[1]    0    4 
    Set Modifier Attributes      @{PORTS}[1]    0    0    min_val=10    max_val=20    action=decrement

Miscelenious Operations
    [Documentation]        Run miscelenious commands
    ${p_comment} =         Send Command Return    ${CHASSIS}    ${PORT1} p_comment ?
    Log                    p_comment = ${p_comment}
    Send Command           ${CHASSIS}    ${PORT1} p_comment "new comment"
    ${p_config} =          Send Command Return Multilines    ${CHASSIS}    ${PORT1} p_config ?
    Log                    p_config = ${p_config}

Run Traffic
    [Documentation]    Run traffic and get statistics
    Start Capture      0
    Clear Statistics   0    1
    Run Traffic Blocking
    Stop Capture       0
    &{stats} =         Get Statistics    Port
    ${keys} =          Get Dictionary Keys    ${stats}
    ${port}            Set Variable    @{PORTS}[1]
    &{port_stats}      Set Variable    &{stats}[${port}]
    Log Dictionary     ${port_stats}
    &{pt_total_stats}  Set Variable    &{port_stats}[pt_total]
    Log Dictionary     ${pt_total_stats}
    Should Be Equal As Numbers    &{pt_total_stats}[packets]    160
    Create Tshark      ${WS_DIR}
    Save Capture To File    0    ${CAP_FILE}    pcap
    ${num_packets} =   Analyze Packets    ${CAP_FILE}    ip.src    ip.dst
    Log                num_packets = ${num_packets}

Disonnect
    [Documentation]    Release all ports
    Release Ports      @{PORTS}
