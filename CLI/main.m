//
// Copyright © 2019 osy86. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <stdio.h>
#import <getopt.h>
#import <unistd.h>
#import <Foundation/Foundation.h>
#import "TBPLogger.h"
#import "TBPManager.h"
#import "TPS6598XDevice.h"

void printHelp(const char *name) {
    fprintf(stderr, "usage: tbpatch operation arguments\n");
    fprintf(stderr, "operations:\n");
    fprintf(stderr, "  list        list all devices\n");
    fprintf(stderr, "  patch       patch EEPROM with patch file\n");
    fprintf(stderr, "  restore     undo EEPROM patch with same patch file\n");
    fprintf(stderr, "  dump        dump EEPROM\n");
    fprintf(stderr, "arguments:\n");
    fprintf(stderr, "  -p|--path   filter devices by IORegistry path substring\n");
    fprintf(stderr, "  -u|--uuid   filter devices by device UUID\n");
    fprintf(stderr, "  -o|--offset for dump, starting offset byte, default 0\n");
    fprintf(stderr, "  -s|--size   for dump, bytes to dump\n");
    fprintf(stderr, "  -f|--file   input patch or output dump file\n");
    fprintf(stderr, "filters:\n\n");
    fprintf(stderr, "For operations that require a device, you can specify filters to select the \n");
    fprintf(stderr, "device to operate on. The 'path' filter allows you to specify a substring \n");
    fprintf(stderr, "of the IOService IORegistry plane to match on. For example if the device is:\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "/AppleACPIPlatformExpert/PCI0@0/AppleACPIPCI/PEG1@1,1/IOPP/UPSB@0/IOPP\n");
    fprintf(stderr, "  /DSB0@0/IOPP/NHI0@0/AppleThunderboltHAL/AppleThunderboltNHIType3/\n");
    fprintf(stderr, "  IOThunderboltController/IOThunderboltPort@7/IOThunderboltSwitchType3/\n");
    fprintf(stderr, "  IOThunderboltIECSNub/AppleHPMIECS/AppleHPMDevice@0\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "You can match it with any of the following:\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "  -p IOThunderboltPort@7/IOThunderboltSwitchType3\n");
    fprintf(stderr, "  -p AppleHPMDevice@0\n");
    fprintf(stderr, "  -p PEG1@1,1\n");
    fprintf(stderr, "  ...\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "Any substring of the full path works. Use 'list' to see the full paths and \n");
    fprintf(stderr, "UUID of all detected devices. The 'UUID' filter is applied after the 'path' \n");
    fprintf(stderr, "filter if both are used. If no filter is applied, the first device seen will \n");
    fprintf(stderr, "be used (no order is guaranteed). If after applying all filters, multiple \n");
    fprintf(stderr, "devices still remain, the first device that satisfies all filters will be \n");
    fprintf(stderr, "used.\n");
}

int listDevices(TBPManager *manager, NSString *devPath, NSString *uuid) {
    bool search = devPath || uuid;
    TPS6598XDevice *found = [manager findDeviceWithPath:devPath uuid:uuid];
    if (search) {
        fprintf(stderr, "Will only print out the first matched device!\n");
    }
    for (NSString *key in manager.devices) {
        TPS6598XDevice *dev = manager.devices[key];
        if (!search || dev == found) {
            fprintf(stderr, "%s\n", [key cStringUsingEncoding:NSASCIIStringEncoding]);
            fprintf(stderr, "  Address : 0x%08llX\n", dev.address);
            fprintf(stderr, "  PID     : 0x%08llX\n", dev.deviceId);
            fprintf(stderr, "  UID     : %s\n", [dev.uuid cStringUsingEncoding:NSASCIIStringEncoding]);
            fprintf(stderr, "  Version : %s\n", [dev.version cStringUsingEncoding:NSASCIIStringEncoding]);
            fprintf(stderr, "  Build   : %s\n", [dev.build cStringUsingEncoding:NSASCIIStringEncoding]);
            fprintf(stderr, "  Device  : %s\n\n", [dev.device cStringUsingEncoding:NSASCIIStringEncoding]);
        }
    }
    return 0;
}

int patchEeprom(TBPManager *manager, NSString *filePath, NSString *devPath, NSString *uuid, bool reverse) {
    TPS6598XDevice *dev = [manager findDeviceWithPath:devPath uuid:uuid];
    if (!dev) {
        TBPLog(@"Failed to find device with filter path='%@' and UUID='%@'", devPath, uuid);
        return 1;
    }
    NSURL *file = [NSURL fileURLWithPath:filePath isDirectory:NO];
    NSDictionary *data = [NSDictionary dictionaryWithContentsOfURL:file];
    if (!data) {
        TBPLog(@"Failed to read patches from %@", filePath);
        return 1;
    }
    
    NSDictionary *msgs = data[@"Messages"];
    if (msgs[@"Welcome"]) {
        fprintf(stderr, "%s\n\n", [msgs[@"Welcome"] cStringUsingEncoding:NSASCIIStringEncoding]);
    }
    
    NSArray *rawPatches = data[@"Patches"];
    NSArray<TBPPatchSet *> *patches = [manager generatePatchSets:rawPatches];
    if (!patches) {
        TBPLog(@"No patches found!");
        return 1;
    }
    
    if ([manager eepromPatch:dev patches:patches reverse:reverse] != kIOReturnSuccess) {
        TBPLog(@"Patch failed!");
        return 1;
    }
    
    if (msgs[@"Complete"]) {
        fprintf(stderr, "%s\n", [msgs[@"Complete"] cStringUsingEncoding:NSASCIIStringEncoding]);
    }
    
    return 0;
}

int dumpEeprom(TBPManager *manager, NSString *filePath, NSString *devPath, NSString *uuid, uint32_t offset, uint32_t size) {
    TPS6598XDevice *dev = [manager findDeviceWithPath:devPath uuid:uuid];
    if (!dev) {
        TBPLog(@"Failed to find device with filter path='%@' and UUID='%@'", devPath, uuid);
        return 1;
    }
    NSData *data = [manager eepromDump:dev at:offset size:size];
    if (!data) {
        return 1;
    }
    if (![data writeToFile:filePath atomically:NO]) {
        TBPLog(@"Failed to write dump to %@", filePath);
        return 1;
    }
    return 0;
}

int main(int argc, const char * argv[]) {
    int c;
    const char *devPath = NULL;
    const char *uuid = NULL;
    const char *filePath = NULL;
    uint64_t offset = 0;
    uint64_t size = 0;
    bool reverse = NO;
    enum {
        MODE_INVALID,
        MODE_LIST,
        MODE_PATCH,
        MODE_DUMP
    } mode = MODE_INVALID;
    
    if (argc < 2) {
        printHelp(argv[0]);
        return 1;
    }
    
    if (strcmp(argv[1], "list") == 0) {
        mode = MODE_LIST;
    } else if (strcmp(argv[1], "patch") == 0) {
        mode = MODE_PATCH;
    } else if (strcmp(argv[1], "dump") == 0) {
        mode = MODE_DUMP;
    } else if (strcmp(argv[1], "restore") == 0) {
        mode = MODE_PATCH;
        reverse = YES;
    }
    
    if (mode == MODE_INVALID) {
        fprintf(stderr, "invalid mode\n");
        printHelp(argv[0]);
        return 1;
    }
    optind++;
    
    while (1) {
        int option_index = 0;
        static struct option long_options[] = {
            {"path",    required_argument, 0, 'p' },
            {"uuid",    required_argument, 0, 'u' },
            {"offset",  required_argument, 0, 'o' },
            {"size",    required_argument, 0, 's' },
            {"file",    required_argument, 0, 'f' },
            {"help",    no_argument,       0, 'h' },
            {0,         0,                 0,  0 }
        };

        c = getopt_long(argc, (char * const *)argv, "p:u:o:s:f:h",
                        long_options, &option_index);
        if (c == -1)
            break;

        switch (c) {
            case 'p': {
                devPath = optarg;
                break;
            }

            case 'u': {
                uuid = optarg;
                break;
            }

            case 'o': {
                errno = 0;
                char *endptr;
                offset = strtoul(optarg, &endptr, 0);
                if (errno != 0 || endptr == optarg || *endptr != '\0') {
                    fprintf(stderr, "offset '%s' is invalid!\n", optarg);
                    return 1;
                }
                if (offset > UINT32_MAX) {
                    fprintf(stderr, "offset '%llx' too large!\n", offset);
                    return 1;
                }
                break;
            }

            case 's': {
                errno = 0;
                char *endptr;
                size = strtoul(optarg, &endptr, 0);
                if (errno != 0 || endptr == optarg || *endptr != '\0') {
                    fprintf(stderr, "size '%s' is invalid!\n", optarg);
                    return 1;
                }
                if (size > UINT32_MAX) {
                    fprintf(stderr, "size '%llx' too large!\n", size);
                    return 1;
                }
                break;
            }
                
            case 'f': {
                filePath = optarg;
                break;
            }

            case 'h':
            case '?': {
                printHelp(argv[0]);
                return 1;
                break;
            }

            default: {
                printf("?? getopt returned character code 0%o ??\n", c);
            }
        }
    }
    
    @autoreleasepool {
        TBPManager *manager = [TBPManager sharedInstance];
        [TBPLogger sharedInstance].logger = ^ (NSString *line) {
            fprintf(stderr, "%s\n", [line cStringUsingEncoding:NSASCIIStringEncoding]);
        };
        size_t count = [manager discoverDevices];
        
        if (count == 0) {
            fprintf(stderr, "No devices found or not running as root!");
            return 1;
        }
        
        NSString *nsUuid = uuid ? [NSString stringWithCString:uuid encoding:NSASCIIStringEncoding] : nil;
        NSString *nsDevPath = devPath ? [NSString stringWithCString:devPath encoding:NSASCIIStringEncoding] : nil;
        NSString *nsFilePath = filePath ? [NSString stringWithCString:filePath encoding:NSASCIIStringEncoding] : nil;
        
        switch (mode) {
            case MODE_LIST: {
                return listDevices(manager, nsDevPath, nsUuid);
                break;
            }
            case MODE_PATCH: {
                if (!nsFilePath) {
                    fprintf(stderr, "patch file not specified\n");
                    return 1;
                }
                return patchEeprom(manager, nsFilePath, nsDevPath, nsUuid, reverse);
                break;
            }
            case MODE_DUMP: {
                if (size == 0) {
                    fprintf(stderr, "size is zero!\n");
                    return 1;
                }
                if (!nsFilePath) {
                    fprintf(stderr, "output file not specified\n");
                    return 1;
                }
                return dumpEeprom(manager, nsFilePath, nsDevPath, nsUuid, (uint32_t)offset, (uint32_t)size);
                break;
            }
            default: {
                break;
            }
        }
    }
    return 1;
}
