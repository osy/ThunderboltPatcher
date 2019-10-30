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
#import "HPMController.h"

@implementation HPMController

- (id)initWithService:(io_service_t)service {
    if (self = [super init]) {
        IOReturn ret;
        SInt32 score;
        ret = IOCreatePlugInInterfaceForService(service, kAppleHPMLibType, kIOCFPlugInInterfaceID, &_plugin, &score);
        if (ret != kIOReturnSuccess) {
            TBPLog(@"IOCreatePlugInInterfaceForService failed: %x", ret);
            return nil;
        }
        
        HRESULT res;
        res = (*_plugin)->QueryInterface(_plugin, CFUUIDGetUUIDBytes(kAppleHPMLibInterface), (LPVOID)&_device);
        if (res != S_OK) {
            TBPLog(@"QueryInterface failed: %x", res);
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    if (_device) {
        (*_device)->Release(_device);
        _device = NULL;
    }
    
    if (_plugin) {
        IODestroyPlugInInterface(_plugin);
        _plugin = NULL;
    }
}

- (IOReturn)registerRead:(uint64_t)chipAddress regAddress:(uint8_t)regAddress buffer:(void *)buffer maxLength:(size_t)length readLength:(nullable size_t *)readLength {
    IOReturn ret = kIOReturnNotReady;
    if (_device) {
        mach_vm_size_t outlen;
        ret = (*_device)->Read(_device, chipAddress, regAddress, buffer, length, 0, &outlen);
        if (readLength) {
            *readLength = outlen;
        }
    }
    return ret;
}

- (IOReturn)registerRead:(uint64_t)chipAddress regAddress:(uint8_t)regAddress buffer:(void *)buffer length:(size_t)length {
    return [self registerRead:chipAddress regAddress:regAddress buffer:buffer maxLength:length readLength:NULL];
}

- (IOReturn)registerWrite:(uint64_t)chipAddress regAddress:(uint8_t)regAddress buffer:(const void *)buffer length:(size_t)length {
    IOReturn ret = kIOReturnNotReady;
    if (_device) {
        ret = (*_device)->Write(_device, chipAddress, regAddress, (void *)buffer, length, 0);
    }
    return ret;
}

- (IOReturn)command:(uint32_t)command forChipAddress:(uint64_t)chipAddress {
    IOReturn ret = kIOReturnNotReady;
    if (_device) {
        ret = (*_device)->Command(_device, chipAddress, command, 0);
    }
    return ret;
}

@end
