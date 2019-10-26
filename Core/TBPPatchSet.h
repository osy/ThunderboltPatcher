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
#import "TBPPatch.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    DATA_UNKNOWN = 0x0,
    DATA_MATCHES_ORIGINAL = 0x1,
    DATA_MATCHES_REPLACE = 0x2,
    DATA_MATCHES_BOTH = 0x3
} TBPPatchData_t;

@interface TBPPatchSet : NSObject

@property (nonatomic, readonly) uint32_t offset;
@property (nonatomic, readonly) uint32_t size;
@property (nonatomic, nullable) NSData *data;
@property (nonatomic, readonly) TBPPatchData_t dataType;
@property (nonatomic, readonly) NSUInteger numPatches;

- (id)initWithOffset:(uint32_t)offset size:(uint32_t)size;
- (void)queuePatch:(TBPPatch *)patch;
- (NSData *)patchDataWithOriginal:(bool)original;

@end

NS_ASSUME_NONNULL_END
