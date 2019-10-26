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
#import "AppleHPMLib.h"

NS_ASSUME_NONNULL_BEGIN

@interface HPMController : NSObject {
    IOCFPlugInInterface **_plugin;
    AppleHPMLib **_device;
}

- (id)initWithService:(io_service_t)service;
- (IOReturn)registerRead:(uint64_t)chipAddress regAddress:(uint8_t)regAddress buffer:(void *)buffer maxLength:(size_t)length readLength:(nullable size_t *)readLength;
- (IOReturn)registerRead:(uint64_t)chipAddress regAddress:(uint8_t)regAddress buffer:(void *)buffer length:(size_t)length;
- (IOReturn)registerWrite:(uint64_t)chipAddress regAddress:(uint8_t)regAddress buffer:(const void *)buffer length:(size_t)length;
- (IOReturn)command:(uint32_t)command forChipAddress:(uint64_t)chipAddress;

@end

NS_ASSUME_NONNULL_END
