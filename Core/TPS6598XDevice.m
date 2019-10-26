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

#import "TPS6598XDevice.h"

@implementation TPS6598XDevice

- (uint64_t)address {
    return _address;
}

- (uint64_t)deviceId {
    union {
        uint8_t buffer[8];
        uint64_t value;
    } data;
    if ([self readRegister:kTPSRegDID data:&data.buffer[0] length:4] != kIOReturnSuccess) {
        return 0;
    }
    if ([self readRegister:kTPSRegVID data:&data.buffer[4] length:4] != kIOReturnSuccess) {
        return 0;
    }
    return data.value;
}

- (NSString *)uuid {
    union {
        uint8_t buffer[16];
        CFUUIDBytes value;
    } data;
    if ([self readRegister:kTPSRegUID data:data.buffer length:sizeof(data)] != kIOReturnSuccess) {
        return nil;
    }
    CFUUIDRef uuid = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, data.value);
    CFStringRef uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuid);
    CFRelease(uuid);
    return CFBridgingRelease(uuidString);
}

- (NSString *)version {
    union {
        uint8_t buffer[kMaxRegisterSize];
        char value[kMaxRegisterSize];
    } data;
    if ([self readRegister:kTPSRegVersion data:data.buffer length:kMaxRegisterSize] != kIOReturnSuccess) {
        return nil;
    }
    return [NSString stringWithCString:data.value encoding:NSASCIIStringEncoding];
}

- (NSString *)build {
    union {
        uint8_t buffer[kMaxRegisterSize];
        char value[kMaxRegisterSize];
    } data;
    if ([self readRegister:kTPSRegBuild data:data.buffer length:kMaxRegisterSize] != kIOReturnSuccess) {
        return nil;
    }
    return [NSString stringWithCString:data.value encoding:NSASCIIStringEncoding];
}

- (NSString *)device {
    union {
        uint8_t buffer[kMaxRegisterSize];
        char value[kMaxRegisterSize];
    } data;
    if ([self readRegister:kTPSRegDevInfo data:data.buffer length:kMaxRegisterSize] != kIOReturnSuccess) {
        return nil;
    }
    return [NSString stringWithCString:data.value encoding:NSASCIIStringEncoding];
}

- (id)initWithService:(io_service_t)service address:(uint64_t)address {
    if (self = [super init]) {
        if ((_controller = [[HPMController alloc] initWithService:service]) == nil) {
            self = nil;
        } else {
            _address = address;
            if (self.deviceId == 0) {
                NSLog(@"Invalid address: %llx", address);
                self = nil;
            }
        }
    }
    return self;
}

- (IOReturn)readRegister:(uint8_t)regAddress data:(uint8_t [static kMaxRegisterSize])data length:(uint32_t)length {
    NSAssert(length <= kMaxRegisterSize, @"Invalid register length");
    return [_controller registerRead:_address regAddress:regAddress buffer:data length:length];
}

- (IOReturn)writeRegister:(uint8_t)regAddress data:(const uint8_t [static kMaxRegisterSize])data length:(uint32_t)length {
    NSAssert(length <= kMaxRegisterSize, @"Invalid register length");
    return [_controller registerWrite:_address regAddress:regAddress buffer:data length:length];
}

- (IOReturn)runCommand:(uint32_t)cmd input:(const uint8_t [static 16])input output:(uint8_t [static 16])output {
    IOReturn ret;
    if ((ret = [self writeRegister:kTPSRegData1 data:input length:16]) != kIOReturnSuccess) {
        return ret;
    }
    if ((ret = [_controller command:cmd forChipAddress:_address]) != kIOReturnSuccess) {
        return ret;
    }
    return [self readRegister:kTPSRegData1 data:output length:16];
}

- (void)createInputParams:(uint8_t [static 16])buffer address:(uint32_t)addr size:(uint32_t)size {
    // endian swap address
    buffer[0] = (addr >>  0) & 0xFF;
    buffer[1] = (addr >>  8) & 0xFF;
    buffer[2] = (addr >> 16) & 0xFF;
    buffer[3] = (addr >> 24) & 0xFF;
    buffer[4] = (size / 0x1000) & 0xFF;
}

- (IOReturn)eepromRead:(uint8_t *)buffer at:(uint32_t)offset length:(uint32_t)length {
    uint8_t tmp[16];
    IOReturn ret;
    
    while (length > 0) {
        memset(tmp, 0, sizeof(tmp));
        [self createInputParams:tmp address:offset size:0];
        // read command
        if ((ret = [self runCommand:kTPSCmdFlashRead input:tmp output:tmp]) != kIOReturnSuccess) {
            NSLog(@"Read failed at 0x%08X", offset);
            return ret;
        }
        // write out to buffer
        if (length < 16) {
            memcpy(buffer, tmp, length);
            buffer += length;
            offset += length;
            length = 0;
        } else {
            memcpy(buffer, tmp, 16);
            buffer += 16;
            offset += 16;
            length -= 16;
        }
    }
    
    return kIOReturnSuccess;
}

- (IOReturn)eepromErase:(uint32_t)offset length:(uint32_t)length {
    uint8_t tmp[16];
    IOReturn ret;
    
    if (offset & 0xFFF) {
        return kIOReturnNotAligned;
    }
    if (length & 0xFFF) {
        return kIOReturnNotAligned;
    }
    if (length > 0xFF000) {
        return kIOReturnInvalid;
    }
    [self createInputParams:tmp address:offset size:length];
    ret = [self runCommand:kTPSCmdFlashErase input:tmp output:tmp];
    if (ret == kIOReturnSuccess) {
        if (tmp[0] != 0x00) {
            NSLog(@"Erase 0x%08X failed with: 0x%02X", offset, tmp[0]);
            ret = kIOReturnError;
        }
    }
    return ret;
}

- (IOReturn)eepromWrite:(const uint8_t *)buffer at:(uint32_t)offset length:(uint32_t)length {
    uint8_t tmp[16];
    IOReturn ret;
    
    if (offset & 0xFFF) {
        return kIOReturnNotAligned;
    }
    if (length & 0xFFF) {
        return kIOReturnNotAligned;
    }
    if (length > 0xFF000) {
        return kIOReturnInvalid;
    }
    if ((ret = [self eepromErase:offset length:length]) != kIOReturnSuccess) {
        return ret;
    }
    [self createInputParams:tmp address:offset size:0];
    if ((ret = [self runCommand:kTPSCmdFlashAddressStart input:tmp output:tmp]) != kIOReturnSuccess) {
        return ret;
    } else if (tmp[0] != 0x00) {
        NSLog(@"Set write address failed with: 0x%02X", tmp[0]);
        return kIOReturnError;
    }
    while (length > 0) {
        ret = [self runCommand:kTPSCmdFlashWrite input:buffer output:tmp];
        if (ret != kIOReturnSuccess) {
            NSLog(@"Write failed at 0x%08X", offset);
            return ret;
        } else if (tmp[0] != 0x00) {
            NSLog(@"Write failed at 0x%08X with: 0x%02X", offset, tmp[0]);
            return kIOReturnError;
        }
        buffer += 0x10;
        offset += 0x10;
        length -= 0x10;
    }
    
    return kIOReturnSuccess;
}

@end
