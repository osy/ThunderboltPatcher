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

#import "TBPLogger.h"
#import "TBPManager.h"
#import "TBPPatch.h"

#import <CommonCrypto/CommonDigest.h>

@implementation TBPManager {
    NSMutableDictionary<NSString *, TPS6598XDevice *> *_devices;
}

static TBPManager *sharedInstance = nil;

+ (TBPManager *)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[TBPManager alloc] init];
    }
    return sharedInstance;
}

- (size_t)discoverDevices {
    CFDictionaryRef matching = NULL;
    
    _devices = [NSMutableDictionary dictionary]; // clear existing
    
    matching = IOServiceMatching("AppleHPM");
    if (matching == NULL) {
        TBPLog(@"Failed to call IOServiceMatching");
        return 0;
    }
    
    io_iterator_t services = 0;
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, matching, &services) != kIOReturnSuccess) {
        TBPLog(@"Failed to call IOServiceGetMatchingServices");
        return 0;
    }
    
    io_service_t service;
    while ((service = IOIteratorNext(services))) {
        [self addDevicesForBus:service];
    }
    IOObjectRelease(services);
    
    return _devices.count;
}

- (void)addDevicesForBus:(io_service_t)bus {
    io_iterator_t iterator = 0;
    io_service_t service = 0;
    
    if (IORegistryEntryGetChildIterator(bus, kIOServicePlane, &iterator) != kIOReturnSuccess) {
        TBPLog(@"Failed to get iterator for bus %d", bus);
    }
    
    while ((service = IOIteratorNext(iterator))) {
        [self addDevice:service onBus:bus];
    }
    IOObjectRelease(iterator);
}

- (void)addDevice:(io_service_t)device onBus:(io_service_t)bus {
    io_string_t pathName;
    NSString *key;
    NSNumber *addrVal;
    uint64_t address;
    TPS6598XDevice *dev;
    
    if (IORegistryEntryGetPath(device, kIOServicePlane, pathName) != kIOReturnSuccess) {
        TBPLog(@"Failed to get device path for object %d.", device);
        return;
    }
    NSAssert(strnlen(pathName, sizeof(pathName)) > 10, @"Invalid device path");
    key = [NSString stringWithCString:&pathName[10] encoding:NSASCIIStringEncoding];
    
    addrVal = (NSNumber *)[self registry:device forKey:@"Address"];
    if (!addrVal || ![addrVal isKindOfClass:[NSNumber class]]) {
        TBPLog(@"Device %@ not added because of missing Address.", key);
        return;
    }
    address = [addrVal unsignedLongLongValue];
    dev = [[TPS6598XDevice alloc] initWithService:bus address:address];
    if (!dev) {
        TBPLog(@"Device %@ not added because failed to init.", key);
        return;
    }
    
    _devices[key] = dev;
}

- (NSObject *)registry:(io_registry_entry_t)entry forKey:(NSString *)key {
    return CFBridgingRelease(IORegistryEntryCreateCFProperty(entry, (__bridge CFStringRef)key, kCFAllocatorDefault, 0));
}

- (NSDictionary<NSString *,TPS6598XDevice *> *)devices {
    return _devices;
}

- (nullable TPS6598XDevice *)findDeviceWithPath:(nullable NSString *)path uuid:(nullable NSString *)uuid {
    NSArray<TPS6598XDevice *> *candidates;
    if (path) { // filter by path first
        NSMutableArray<TPS6598XDevice *> *mcandidates = [NSMutableArray array];
        for (NSString *key in self.devices) {
            if ([key containsString:path]) {
                [mcandidates addObject:self.devices[key]];
            }
        }
        candidates = mcandidates;
    } else {
        candidates = [self.devices allValues];
    }
    if (uuid) { // then filter by uuid
        for (TPS6598XDevice *dev in candidates) {
            if ([dev.uuid caseInsensitiveCompare:uuid] == NSOrderedSame) {
                return dev;
            }
        }
        return nil; // not found
    } else if (candidates) {
        return [candidates firstObject];
    } else {
        return nil;
    }
}

- (nullable NSData *)eepromDump:(TPS6598XDevice *)device at:(uint32_t)offset size:(uint32_t)size {
    NSMutableData *data = [NSMutableData dataWithLength:size];
    if (!data) {
        TBPLog(@"Cannot allocate memory!");
        return nil;
    }
    if ([device eepromRead:[data mutableBytes] at:offset length:size] != kIOReturnSuccess) {
        TBPLog(@"Dump failed!");
        return nil;
    }
    return data;
}

- (NSArray *)sortPatches:(NSArray *)unsorted {
    return [unsorted sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        NSAssert([obj1[@"Offset"] isKindOfClass:[NSNumber class]], @"Invalid patch list");
        NSAssert([obj2[@"Offset"] isKindOfClass:[NSNumber class]], @"Invalid patch list");
        return [(NSNumber *)obj1 compare:(NSNumber *)obj2];
    }];
}

- (nullable NSArray<TBPPatchSet *> *)generatePatchSets:(NSArray *)rawPatches {
    NSMutableArray<TBPPatch *> *patches = [NSMutableArray arrayWithCapacity:rawPatches.count];
    for (NSDictionary *rawPatch in rawPatches) {
        TBPPatch *patch = [[TBPPatch alloc] initWithDictionary:rawPatch];
        if (!patch) {
            TBPLog(@"Failed to parse patch: %@", rawPatch);
            return nil;
        }
        [patches addObject:patch];
    }
    [patches sortUsingComparator:^NSComparisonResult(TBPPatch *obj1, TBPPatch *obj2) {
        if (obj1.offset < obj2.offset) {
            return NSOrderedAscending;
        } else if (obj1.offset > obj2.offset) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }];
    NSMutableArray<TBPPatchSet *> *patchSets = [NSMutableArray array];
    TBPPatchSet *curPatchSet;
    uint32_t off = 0xFFFFFFFF;
    for (TBPPatch *patch in patches) {
        uint32_t alignedOffset = patch.offset & ~0xFFF;
        if (alignedOffset != off) {
            curPatchSet = [[TBPPatchSet alloc] initWithOffset:alignedOffset size:0x1000];
            [patchSets addObject:curPatchSet];
            off = alignedOffset;
        }
        if ((patch.offset + patch.original.length) > alignedOffset + 0x1000) {
            TBPLog(@"Patches that span two 4KiB pages are NOT yet supported. Please break your patches to not span a 4KiB boundary.");
            return nil;
        }
        [curPatchSet queuePatch:patch];
    }
    
    return patchSets;
}

- (IOReturn)eepromPatch:(TPS6598XDevice *)device patches:(NSArray<TBPPatchSet *> *)patchSets reverse:(bool)reverse {
    uint32_t base;
    IOReturn ret;
    TBPLog(@"Looking for the start address.");
    if ((ret = [device eepromRead:(void *)&base at:0 length:sizeof(base)]) != kIOReturnSuccess) {
        return ret;
    }
    if (base == 0x00000000 || base == 0xFFFFFFFF) {
        TBPLog(@"base not found at offset 0x0, trying 0x1000");
        if ((ret = [device eepromRead:(void *)&base at:0x1000 length:sizeof(base)]) != kIOReturnSuccess) {
            return ret;
        }
        if (base == 0x00000000 || base == 0xFFFFFFFF) {
            TBPLog(@"base not found at offset 0x1000, giving up");
            return kIOReturnNotFound;
        }
    }
    TBPLog(@"Found base: 0x%08X", base);
    TBPLog(@"Getting original data for each page and performing verification.");
    for (TBPPatchSet *patchSet in patchSets) {
        uint32_t addr = base + patchSet.offset;
        uint8_t data[0x1000];
        TBPLog(@"Getting data for page: 0x%08X", addr);
        if ((ret = [device eepromRead:data at:addr length:sizeof(data)]) != kIOReturnSuccess) {
            return ret;
        }
        patchSet.data = [NSData dataWithBytes:data length:sizeof(data)];
        TBPPatchData_t dataType = [patchSet dataType];
        TBPLog(@"Data matches patch set for original:%d replacement:%d", !!(dataType & DATA_MATCHES_ORIGINAL), !!(dataType & DATA_MATCHES_REPLACE));
        if (reverse && !(dataType & DATA_MATCHES_REPLACE)) {
            TBPLog(@"Exiting because existing data is not matching replacement.");
            return kIOReturnError;
        }
        if (!reverse && !(dataType & DATA_MATCHES_ORIGINAL)) {
            TBPLog(@"Exiting because existing data is not matching original.");
            return kIOReturnError;
        }
    }
    TBPLog(@"Writing patched pages");
    for (TBPPatchSet *patchSet in patchSets) {
        NSData *newData = [patchSet patchDataWithOriginal:reverse];
        uint8_t tmp[patchSet.size];
        uint32_t addr = base + patchSet.offset;
        int tries = 100;
        do {
            TBPLog(@"Writing page: 0x%08X with %lu patches", addr, (unsigned long)patchSet.numPatches);
            if ((ret = [device eepromWrite:newData.bytes at:addr length:patchSet.size]) != kIOReturnSuccess) {
                return ret;
            }
            TBPLog(@"Reading back page: 0x%08X", addr);
            if ((ret = [device eepromRead:tmp at:addr length:patchSet.size]) != kIOReturnSuccess) {
                return ret;
            }
            if (memcmp(newData.bytes, tmp, patchSet.size) != 0) {
                TBPLog(@"Read mismatch, trying patch again (%d tries remaining)", tries);
            } else {
                break;
            }
        } while (--tries > 0);
        if (tries == 0) {
            TBPLog(@"Patch failed at page 0x%08X", addr);
            return kIOReturnError;
        }
    }
    TBPLog(@"Done!");
    return kIOReturnSuccess;
}

@end
