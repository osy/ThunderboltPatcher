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

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import "HPMController.h"

typedef enum _TPS6598XRegisters {
    kTPSRegVID          = 0x00,
    kTPSRegDID          = 0x01,
    kTPSRegUID          = 0x05,
    kTPSRegCmd1         = 0x08,
    kTPSRegData1        = 0x09,
    kTPSRegVersion      = 0x0F,
    kTPSRegBuild        = 0x2E,
    kTPSRegDevInfo      = 0x2F
} TPS6598XRegisters;

#define kTPSCmdFlashActiveRegion    ('FLrr')
#define kTPSCmdFlashEraseRegion     ('FLer')
#define kTPSCmdFlashAddressStart    ('FLad')
#define kTPSCmdFlashRead            ('FLrd')
#define kTPSCmdFlashWrite           ('FLwd')
#define kTPSCmdFlashErase           ('FLem')
#define kTPSCmdFlashVerify          ('FLvy')

#define kMaxRegisterSize            (64)

NS_ASSUME_NONNULL_BEGIN

@interface TPS6598XDevice : NSObject {
    HPMController *_controller;
    uint64_t _address;
}

@property (readonly) uint64_t address;
@property (readonly) uint64_t deviceId;
@property (readonly, nullable) NSString *uuid;
@property (readonly, nullable) NSString *version;
@property (readonly, nullable) NSString *build;
@property (readonly, nullable) NSString *device;

- (id)initWithService:(io_service_t)service address:(uint64_t)address;
- (IOReturn)readRegister:(uint8_t)regAddress data:(uint8_t [static kMaxRegisterSize])data length:(uint32_t)length;
- (IOReturn)writeRegister:(uint8_t)regAddress data:(const uint8_t [static kMaxRegisterSize])data length:(uint32_t)length;
- (IOReturn)runCommand:(uint32_t)cmd input:(const uint8_t [static 16])input output:(uint8_t [static 16])output;
- (IOReturn)eepromRead:(uint8_t *)buffer at:(uint32_t)offset length:(uint32_t)length;
- (IOReturn)eepromErase:(uint32_t)offset length:(uint32_t)length;
- (IOReturn)eepromWrite:(const uint8_t *)buffer at:(uint32_t)offset length:(uint32_t)length;

@end

NS_ASSUME_NONNULL_END
