#! /usr/bin/python
# -*- coding: UTF-8 -*-
"""
Network Manager Telekinesis - Interdicts connections to unwanted networks

This program controls NetworkManager via DBUS
in order to prevent it from connecting to certain networks.

(Copyleft) 2012 Mmoebius/ALUG
License: GPLv3 http://www.gnu.org/licenses/gpl.html

Version 1.0a - Fragt nicht nach dem Abschalten des Mops-Netz-Killers
"""

###
### Configuration 
###
#now: Cmdline Parameter
#IPv4unwanted = [
#  '134.61.32.0/21'       # MoPS range
#]
IPv4unwantedRng=[]
DoDisableUnwanted=True   # set to false to stop turning off the network

###
### /Configuration
###

SessionBusListener=None  # gets set if waiting for the user to dismiss the action

from pprint import pformat,pprint
import logging
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

import dbus, sys
from time import sleep

# Need a Mainloop for signals
from dbus.mainloop.glib import DBusGMainLoop
import gobject
DBusGMainLoop(set_as_default=True)

# Need struct for network byte order handling
from struct import pack,unpack

#Parse comdline options
import argparse

parser = argparse.ArgumentParser(description='Control NetworkManager to stay off some networks')
parser.add_argument('ipranges', metavar='IPv4range', type=str, nargs='+',
                   help='IPv4 range/mask to disconnect automatically. e.g. "10.11.12.0/24"')
parser.add_argument('-v', '--verbose', dest='verbose', action='store_true',
                   help='Set debug level to DEBUG (default INFO)')

parser.description="""Network Manager Telekinesis - Interdicts connections to unwanted networks"""
parser.epilog="""(Copyleft) 2012 Mmoebius/ALUG
License: GPLv3 http://www.gnu.org/licenses/gpl.html"""

args = parser.parse_args()

if args.verbose:
  logger.level=logging.DEBUG
  logger.debug('Verbose debug messages')

IPv4unwanted=args.ipranges

NMdevtype = { 1: "Ethernet",
             2: "Wi-Fi",
             5: "Bluetooth",
             6: "OLPC",
             7: "WiMAX",
             8: "Modem",
             9: "InfiniBand",
             10: "Bond",
             11: "VLAN",
             12: "ADSL" }

NMstate = { 0: "Unknown",
           10: "Unmanaged",
           20: "Unavailable",
           30: "Disconnected",
           40: "Prepare",
           50: "Config",
           60: "Need Auth",
           70: "IP Config",
           80: "IP Check",
           90: "Secondaries",
           100: "Activated",
           110: "Deactivating",
           120: "Failed" }

bus = dbus.SystemBus()

# Get a proxy for the base NetworkManager object
proxy = bus.get_object("org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager")
manager = dbus.Interface(proxy, "org.freedesktop.NetworkManager")

def handle_Carrier(sender=None,**kwargs):
  logger.debug("handle_Carrier from %s with %s",sender,pformat(kwargs))

def handle_PropertiesChanged(sender=None,**kwargs):
  logger.debug("handle_PropertiesChanged from %s with %s",sender,pformat(kwargs))

def getProp(oPath,propIface,propName):
  """Gets a 'org.freedesktop.DBus.Properties' from any interface on any object path 'org.freedesktop.NetworkManager' serves """
  proxy    = bus.get_object("org.freedesktop.NetworkManager", oPath)
  proxy_if = dbus.Interface(proxy, "org.freedesktop.DBus.Properties")
  props    = proxy_if.Get(propIface, propName)
  return props

def getAllProps(oPath,propIface):
  """Gets all 'org.freedesktop.DBus.Properties' from any interface on any object path 'org.freedesktop.NetworkManager' serves """
  proxy    = bus.get_object("org.freedesktop.NetworkManager", oPath)
  proxy_if = dbus.Interface(proxy, "org.freedesktop.DBus.Properties")
  props    = proxy_if.GetAll(propIface)
  return props

#IP Address format conversions:
def IpDbus2Tuple(IpDbus):
  return unpack('>BBBB',pack('>L',IpDbus)) #dbus order to tuple

def IpDbus2Int(IpDbus):
  return unpack('=L',pack('>L',IpDbus))[0] #dbus order to and'able int

def IpInt2Tuple(IpInt):
  return unpack('>BBBB',pack('=L',IpInt))

def IpStr2Tuple(IpStr):
  return map(int,IpStr.split('.',3))

def IpTuple2String(IpTuple):
  return ".".join(map(str,IpTuple[::-1]))

def IpTuple2Int(IpTuple):
  ipa=0
  for i in [0,1,2,3]:
    ipa+=int(IpTuple[i])<<(24-8*i)
  return ipa

def IpMaskStr2StrA(IpMaskStr):
  return IpMaskStr.rsplit('/',1)

def IpStr2Tuple(IpStr):
  tupl=map(int,IpStr.split('.',3))
  for i in tupl:
    if (0>i) or (255<i):
      raise ValueError("Ip address quad not in range 0..255: %d"%i)
  return tupl

def IpGetMasked(adr,mask):
  # mask two IP addresses in 'int' - style. All host-specific bits cleared
  return adr&(2**32-2**(32-mask)) #cutting at the right end

def IpGetAntiMasked(adr,mask):
  # return all nonmasked bits set '1'. All host-specific bits set
  return adr|(2**(32-mask)-1) #cutting at the right end

def handle_NotifyUserAction(replaces_id,ActionStrA):
  global SessionBusListener
  global DoDisableUnwanted
  logger.debug('handle_NotifyUserAction: got %s %s',str(replaces_id),str(ActionStrA))
  if 'Mops-off-wantMops' in ActionStrA:
    DoDisableUnwanted=False
    logger.warn('User stops disabling networks.')
  
def NotifyUser():
  global SessionBusListener
  global DoDisableUnwanted
  sbus = dbus.SessionBus()
  oNotifier = sbus.get_object("org.freedesktop.Notifications", "/org/freedesktop/Notifications")
  iNotifier=dbus.Interface(oNotifier, "org.freedesktop.Notifications")
  
  
  if SessionBusListener is None:
    SessionBusListener = sbus.add_signal_receiver(handle_NotifyUserAction, signal_name="ActionInvoked", 
                        dbus_interface="org.freedesktop.Notifications" )
    logger.debug('Added Dbus listener for session bus: %s',str(SessionBusListener)) 

  NotifyOptionsArray=[]  
# Uncomment these 4 Lines if you want to be able to turn off disconnecting MoPS Networks
#  if DoDisableUnwanted:
#    NotifyOptionsArray=[
#        'Mops-off-Ok', 'Ok',
#        'Mops-off-wantMops','MoPS nicht mehr trennen'
#      ]

  sleep(3) # Wait until nm-dispatcher sends it smessage, do not overflood the NotifyOS, try not to get buried.

  iNotifier.Notify(
    "nmtelekinesis", # Applicateion Identifier
    0,               # replaces_id (hardcoded)
                     # Note: if replaces_id is 0, the return value is a UINT32 that represent the notification. 
    "network-error", # "notification-network-disconnected",
    "Forced MoPS disconnect",
    u"""Das MoPS Netzwerk ist während der Installation
unerwuenscht. Es wurde automatisch getrennt.

Bitte aktiviere das Eduroam-Netzwerk gemäß 
Anleitung mit 802.1X Authentifikation.

Frage ein Installhelferhörnchen, 
falls Du dabei Hilfe brauchst.""",
    NotifyOptionsArray,
    {}, #Application specific hint parameter
    30000 # OSD Notifier will not take long times
  )

def WarnUser():
  sbus = dbus.SessionBus()
  oNotifier = sbus.get_object("org.freedesktop.Notifications", "/org/freedesktop/Notifications")
  iNotifier=dbus.Interface(oNotifier, "org.freedesktop.Notifications")
  sleep(3)
  iNotifier.Notify(
    "nmtelekinesis", # Applicateion Identifier
    0,               # replaces_id (hardcoded)
                     # Note: if replaces_id is 0, the return value is a UINT32 that represent the notification. 
    "network", # "notification-network-disconnected",
    "MoPS discovered",
    u"""Das MoPS Netzwerk ist während der Installation
unerwuenscht. Du bist gewarnt.

Bitte aktiviere das Eduroam-Netzwerk gemäß 
Anleitung mit 802.1X Authentifikation.

Frage ein Installhelferhörnchen, 
falls Du dabei Hilfe brauchst.""",
    [],
    {}, #Application specific hint parameter
    30000 # OSD Notifier will not take long times
  )

def DisableAutoConnect(oConn):
  """Disable AutoConnect for the currently active setting object in oConn"""
  try:
    Psetting=getProp(oConn,"org.freedesktop.NetworkManager.Connection.Active",'Connection')
    proxy    = bus.get_object("org.freedesktop.NetworkManager", Psetting)
    proxy_if = dbus.Interface(proxy, "org.freedesktop.NetworkManager.Settings.Connection")
    props    = proxy_if.GetSettings()    # read
    logger.debug('DisableAutoConnect: Got settings %s',pformat(props))
    props['connection']['autoconnect']=0 # modify
    proxy_if.Update(props)               # write. Simple.
  except Exception as err:
    logger.warn('Error setting Autocconnect false for %s: (%s)',oConn,str(err))
  

def DisconnectDevice(oPath, oConn):
  global DoDisableUnwanted
  if DoDisableUnwanted:
    logger.debug('Disconnecting %s',str(oPath))
    proxy    = bus.get_object("org.freedesktop.NetworkManager", oPath)
    proxy_if = dbus.Interface(proxy, "org.freedesktop.NetworkManager.Device")
    # about to disconnect something.
    # See if there is a setting that can be set to "autoconnect=false" along with this
    DisableAutoConnect(oConn)
    #result = "Demo-NoDisconnect"
    result = "failed"
    result    = proxy_if.Disconnect()
    logger.info('Disconnected %s result %s',str(oPath),result)
    NotifyUser()
  else:
    WarnUser()
    logger.info('Not disconnecting %s (DoDisableUnwanted is false)',str(oPath))

def ScanIp4Config2(oIp4Config, oDevice, oConn):
  try:
    Pip4 = getProp(oIp4Config,"org.freedesktop.NetworkManager.IP4Config",'Addresses')
  except dbus.exceptions.DBusException:
    logger.debug("ScanIp4Config2(oDevice %s, oIp4Config %s, oConn %s): no IP4Config",oIp4Config, oDevice, oConn)
    return

  CanDisconnect=False
  for addr in Pip4:
    logger.debug(
      'IP Address: %s/%d gw:%s',
      IpTuple2String(IpDbus2Tuple(addr[0])),
      addr[1],
      IpTuple2String(IpDbus2Tuple(addr[2]))
    )
    # check ip range against known unwanted range
    ipa=IpDbus2Int(addr[0])
    if (0>ipa) or (2**32<ipa):
      logger.warn('IPv4 address exceeds range: %d',ipa)
      return
    
    for (iplo,iphi) in IPv4unwantedRng:
      if (ipa>=iplo) and (ipa<=iphi):
        logger.info('Detected ip in unwanted range: %s <= %s <= %s on %s',
          IpTuple2String(IpInt2Tuple(iplo)),
          IpTuple2String(IpInt2Tuple(ipa)),
          IpTuple2String(IpInt2Tuple(iphi)),
          str(oDevice)
          )
        CanDisconnect=True
  if CanDisconnect:
    DisconnectDevice(oDevice, oConn)
  return CanDisconnect

def ScanActiveDevice2(adev,aconn):
  logger.debug("Examining device: %s", str(adev))
  # IPv4Config may not be available instantly
  pDev = getAllProps(adev,"org.freedesktop.NetworkManager.Device")
  logger.debug('dev props %s',pDev)
  if pDev.has_key('Ip4Config'):
    oIPv4=pDev['Ip4Config']
    logger.debug('dev props ipv4config %s',oIPv4)      
    ScanIp4Config2(oIPv4,adev,aconn)

def ScanActiveConnections2(ActiveConnections):
  """Scans an array of connection objects for unwanted IP addresses"""
  for aconn in ActiveConnections:
    try:
      logger.debug("Examining connection: %s", str(aconn))
      # read props from the Active Connection
      Pconn = getProp(aconn,"org.freedesktop.NetworkManager.Connection.Active",'Devices')
      Pmaster = getProp(aconn,"org.freedesktop.NetworkManager.Connection.Active",'Master')
      if str(Pmaster) in map(str,ActiveConnections):    
        logger.debug("connection: %s has a master device %s that is examined elsewhere. Stop.", 
          str(aconn),
          str(Pmaster)
        )
        logger.debug("other location is %s in %s",sAconn,str(map(str,aconn)))
        Pconn=[]
        break
      
      for adev in Pconn:
	ScanActiveDevice2(adev,aconn)
              
    except Exception as err:
      logger.warn('Exception while examining connection %s: >>>%s<<<',
        str(aconn),
        str(err),
      )

def handle_NmPropertiesChanged(sender=None,*args,**kwargs):
  logger.debug("handle_NmPropertiesChanged with %s and %s and %s",str(sender),str(args),str(kwargs))
  logger.debug("handle_NmPropertiesChanged keys %s",str(sender.keys()))
  # check if new connection active
  if sender.has_key('ActiveConnections'):
    conn=sender['ActiveConnections']
    logger.info("Scanning ActiveConnections: %s",str(conn))
    ScanActiveConnections2(conn)
  if sender.has_key('Ip4Config'):
    ipv4cfg=sender['Ip4Config']
    logger.info("Scanning Ip4Config: %s",str(ipv4cfg))
    ScanIp4Config2(ipv4cfg)
  if sender.has_key('State'):
    try:
      StateHint=NMstate[sender['State']]
    except KeyError:
      StateHint='<unknown>'
    logger.debug('State Change to >>>%s<<< (%s)',str(sender['State']),StateHint)
    
def NmStateStr(iState):
  try:
    return NMstate[iState]
  except KeyError:
    return '<unknown>'

def handle_NmDeviceStateChanged(sNew,sOld,sReason,**kwargs):
  logger.debug("handle_NmDeviceStateChanged with %s",str(kwargs))
  logger.debug("handle_NmDeviceStateChanged %s (%d) -> %s (%d) Reason: %d",
               NmStateStr(sOld), sOld,   NmStateStr(sNew), sNew, sReason  )
  if kwargs.has_key('oPath'):
    oPath=kwargs['oPath']
    if 100 == sNew:
      logger.info("Scanning Activated Device: %s",str(oPath))
      # need aconn so scan.
      oAConn=getProp(oPath,'org.freedesktop.NetworkManager.Device','ActiveConnection')
      ScanActiveDevice2(oPath,oAConn)

#Device-Add is not yet required to be watch for
#def handle_addDevice(oDev,*args):
#  logger.debug("handle_addDevice from %s with %s",str(oDev),str(args))

def ParseIPv4unwantedRng(IpStrList):
  """filling IPv4unwantedRng from IPv4unwanted"""
  global IPv4unwantedRng
  for s in IpStrList:
    try:
      logger.debug('Unwanted IP: parsing >>>%s<<<',s)
      [ips,masks]=IpMaskStr2StrA(s)
      mask=int(masks)
      ip=IpTuple2Int(IpStr2Tuple(ips))
      #logger.debug('Unwanted IP %s / %d',str(ip),mask)
      if (0>mask) or (32<mask):
        raise ValueError('Mask range 0..32 error')
      if (0>ip) or (2**32<ip):
        raise ValueError('ip range 0..2^32 error')
      iplow=IpGetMasked(ip,mask)
      iphigh=IpGetAntiMasked(ip,mask)
      logger.info('Unwanted IP range %s - %s',IpTuple2String(IpInt2Tuple(iplow)),IpTuple2String(IpInt2Tuple(iphigh)))
      IPv4unwantedRng.append((iplow,iphigh))
    except ValueError as err:
      logger.warn('That is not a valid ip/mask: >>>%s<<< (%s)',str(s),err.message)

logger.debug("Startup - preparing unwanted address ranges")
ParseIPv4unwantedRng(IPv4unwanted)

if len(IPv4unwantedRng)<1:
  logger.warn('No unwanted IP range given. Quit.')
  quit(1)

# Adding bus signal receivers
# See interface spec at http://projects.gnome.org/NetworkManager/developers/api/09/spec.html#org.freedesktop.NetworkManager
# Chapter "Signal" -> defines "DeviceAdded" on the interface "org.freedesktop.NetworkManager"

#Device-Add is not yet required to be watch for 
#bus.add_signal_receiver(handle_addDevice, signal_name="DeviceAdded", 
#                        dbus_interface="org.freedesktop.NetworkManager" )

bus.add_signal_receiver(handle_NmPropertiesChanged, signal_name="PropertiesChanged", 
                        dbus_interface="org.freedesktop.NetworkManager" )

# see path_keyword etc. in http://dbus.freedesktop.org/doc/dbus-python/api/dbus.service-module.html
bus.add_signal_receiver(handle_NmDeviceStateChanged, signal_name="StateChanged", 
                        dbus_interface="org.freedesktop.NetworkManager.Device",
                        path_keyword='oPath')

#Device-Add is not yet required to be watch for 
## Adding all devices via the DeviceAdded callback
#Devices=manager.GetDevices()
#logger.debug("Startup - getting Devices: %s",str(Devices))
#for oDev in Devices:
#  handle_addDevice(oDev) 

ConnAct=getProp('/org/freedesktop/NetworkManager','org.freedesktop.NetworkManager','ActiveConnections')
logger.debug("Startup - getting active Connections: %s",str(ConnAct))
# plug that into the active connection changed handler
ScanActiveConnections2(ConnAct)

loop = gobject.MainLoop()
logger.debug("Entering MainLoop")
loop.run() # To stop, call loop.quit().

#end;
