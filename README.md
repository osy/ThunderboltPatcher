#  Thunderbolt Patcher
This utility allows you to patch the Thunderbolt NVM firmware using the 
TPS65982 controller (which shares the same SPI chip) interface. **You can 
permanently brick your Ridge device if you break the firmware. If so,you must 
use an external flasher to recover!**

This tool comes in two flavours, a GUI (WIP) and a command line interface.

## Command Line

You must run the tool as root. First, run list to get all the TPS controllers 
in the system.

```
$ sudo tbpatch list
```

This will show a list of all HPM controllers. Please note only TPS65982 is 
supported. TPS65983 is NOT supported because it does not have a flashing 
interface.

Example output:

```
/AppleACPIPlatformExpert/PCI0@0/AppleACPIPCI/I2C2@15,2/AppleIntelLpssI2C@2/AppleIntelLpssI2CController@2/HPM1@0/AppleHPMLPSS/AppleHPMDevice@70
  Address : 0x00000070
  PID     : 0x2831454341
  UID     : 073B7251-2C50-42D8-A9D5-F6440E5456BF
  Version : 
  Build   : 708ef7fef06b3a126fd0e433f097fed7975c3730_09112017
  Device  : TPS65982 HW0011 FW0001.12.06 ZTBT1

/AppleACPIPlatformExpert/PCI0@0/AppleACPIPCI/RP05@1C,4/IOPP/UPSB@0/IOPP/DSB0@0/IOPP/NHI0@0/AppleThunderboltHAL/AppleThunderboltNHIType3/IOThunderboltController/IOThunderboltPort@5/IOThunderboltSwitchType3/IOThunderboltIECSNub/AppleHPMIECS/AppleHPMDevice@1
  Address : 0x00000001
  PID     : 0x2831454341
  UID     : 6E97747A-77C4-4058-A60D-379D14F60250
  Version : 
  Build   : 708ef7fef06b3a126fd0e433f097fed7975c3730_09112017
  Device  : TPS65982 HW0011 FW0001.12.06 ZTBT1

/AppleACPIPlatformExpert/PCI0@0/AppleACPIPCI/I2C2@15,2/AppleIntelLpssI2C@2/AppleIntelLpssI2CController@2/HPM1@0/AppleHPMLPSS/AppleHPMDevice@4E
  Address : 0x0000004E
  PID     : 0x2831454341
  UID     : 6E97747A-77C4-4058-A60D-379D14F60250
  Version : 
  Build   : 708ef7fef06b3a126fd0e433f097fed7975c3730_09112017
  Device  : TPS65982 HW0011 FW0001.12.06 ZTBT1

/AppleACPIPlatformExpert/PCI0@0/AppleACPIPCI/RP05@1C,4/IOPP/UPSB@0/IOPP/DSB0@0/IOPP/NHI0@0/AppleThunderboltHAL/AppleThunderboltNHIType3/IOThunderboltController/IOThunderboltPort@5/IOThunderboltSwitchType3/IOThunderboltIECSNub/AppleHPMIECS/AppleHPMDevice@0
  Address : 0x00000000
  PID     : 0x2831454341
  UID     : 073B7251-2C50-42D8-A9D5-F6440E5456BF
  Version : 
  Build   : 708ef7fef06b3a126fd0e433f097fed7975c3730_09112017
  Device  : TPS65982 HW0011 FW0001.12.06 ZTBT1
```

Note here we have four controllers but only two unique UUIDs. That is because 
the same controller appears on two different interfaces: once on the host I2C 
interface and again on the Thunderbolt interface. Either one can be used for 
flashing, however, if you "semi-brick" the Thunderbolt controller but the HPM 
controller is still powered on (and you have the right ACPI device installed), 
then you can use the host I2C to recover by un-doing a patch.

To select a single device for use in dumping or flashing operations, we use 
either `-p PATH_SUBSTRING` or `-u UUID_STRING` or both (or neither). This will 
first filter out all the devices that does NOT have `PATH_SUBSTRING` in the 
path (the first line in a list output). Next it will filter out all devices 
that does NOT have the exact UUID matching `UUID_STRING`. Finally, if there are 
multiple devices remaining, one will be used in no defined order. Note that if 
neither `-p` nor `-u` are passed, the first controller (in no defined order) 
will be used. This is useful if you only have two controllers both connected to 
the same SPI chip as the Thunderbolt controller and you do not care which one 
to use for flashing.

You can use the list command again to test out the filter and see which device 
will be selected for the dump/flash operation.

```
$ sudo tbpatch list -p RP05 -u 073B7251-2C50-42D8-A9D5-F6440E5456BF
/AppleACPIPlatformExpert/PCI0@0/AppleACPIPCI/RP05@1C,4/IOPP/UPSB@0/IOPP/DSB0@0/IOPP/NHI0@0/AppleThunderboltHAL/AppleThunderboltNHIType3/IOThunderboltController/IOThunderboltPort@5/IOThunderboltSwitchType3/IOThunderboltIECSNub/AppleHPMIECS/AppleHPMDevice@0
  Address : 0x00000000
  PID     : 0x2831454341
  UID     : 073B7251-2C50-42D8-A9D5-F6440E5456BF
  Version : 
  Build   : 708ef7fef06b3a126fd0e433f097fed7975c3730_09112017
  Device  : TPS65982 HW0011 FW0001.12.06 ZTBT1
```

The dump command can be used to dump data from the SPI chip. It is recommended 
that you do this first in order to have a backup handy for external flashing if 
the worst happens.

```
$ sudo tbpatch dump -p RP05 -u 073B7251-2C50-42D8-A9D5-F6440E5456BF -o 0x0 -s 0x100000 -f backup.bin
```

The patch command applies a patch file (format specified below) to the current 
active firmware. The inactive firmware will not be touched. The patch file 
defines a set of offsets from the active firmware, the original bytes and the 
patched bytes. No patching will be done if ANY of the patches do not match the 
original bytes.

```
$ sudo tbpatch patch -p RP05 -u 073B7251-2C50-42D8-A9D5-F6440E5456BF -f patch.plist
```

Note that a bad patch can brick your controller! Also note that currently it is 
not possible to bypass the signature check in Windows so TB mode will not work 
in Windows. If you change your mind, you can undo the patches by passing in the 
**same patch file** with the recover command. Because of this, it is important 
that you keep the patch file you used. Using multiple patch files is not 
supported.

```
$ sudo tbpatch restore -p RP05 -u 073B7251-2C50-42D8-A9D5-F6440E5456BF -f patch.plist
```

## GUI

WIP

## Patch File

The patch file is in a PLIST format. Please refer to the existing patches in 
`/Patches` for examples on the format.

### Messages

`Messages` is a dictionary of messages to show the user for certain events.
Regardless of the UI, the messages will be displayed. It is not required that 
that user "confirm" seeing the message before the process continues.

Each message must contain a string value.

#### Welcome

Shown before flashing.

#### Complete

Shown after a successful flash. Not shown if the flash terminated in error.

### Patches

`Patches` is an array of dictionaries. Each dictionary defines a patch with an 
offset from the active firmware, the original data, and the replacement data. 
Note that a `patch` operation will not continue if ANY of the original data at 
the offset does not match. Similarly, a `restore` operation will not continue 
if ANY of the data does not match the "replacement" data.

Patches are performed in 4KiB chunks. Therefore it is currently NOT possible 
to perform a patch that starts in one 4KiB page and extends to another 4KiB 
page. You should instead make that two different patches.

Because of the checks done, it is possible to perform assertion checks on data 
that is presumed to be at certain offsets without actually changing the data 
at that offset. Just make sure "original" and "replacement" match. This is 
useful for making sure certain headers and offsets are correct before patching 
fields at those offsets. Be aware if an assertion check is the ONLY patch in a 
particular 4KiB page, then that page will still get flashed with the same data 
unmodified.

#### Offset

Byte offset from the current active partition. (NOT the beginning of the chip)

#### Original

Original data at that offset. Flashed in "restore" operations. Checked in 
"patch" operations.

#### Replace

Replacement data at that offset. Flashed in "patch" operations. Checked in 
"restore" operations.
