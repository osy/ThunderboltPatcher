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

#import "TBPPatchSet.h"

@implementation TBPPatchSet {
    NSMutableArray<TBPPatch *> *_patches;
}

- (id)initWithOffset:(uint32_t)offset size:(uint32_t)size {
    if (self = [super init]) {
        _patches = [NSMutableArray array];
        _offset = offset;
        _size = size;
    }
    return self;
}

- (void)queuePatch:(TBPPatch *)patch {
    NSAssert(patch.offset >= self.offset, @"trying to add a patch at offset %x to a patchset with base offset %x", patch.offset, self.offset);
    NSAssert(patch.offset + patch.original.length <= self.offset + self.size, @"patch too large");
    NSAssert(patch.original.length == patch.replace.length, @"patch has unmatching size");
    
    [_patches addObject:patch];
}

- (TBPPatchData_t)dataType {
    if (!self.data) {
        return DATA_UNKNOWN;
    }
    
    bool isOriginal = YES;
    bool isReplace = YES;
    for (TBPPatch *patch in _patches) {
        uint32_t off = patch.offset - _offset;
        NSData *dat = [self.data subdataWithRange:NSMakeRange(off, patch.original.length)];
        if (![dat isEqualToData:patch.original]) {
            isOriginal = NO;
        }
        if (![dat isEqualToData:patch.replace]) {
            isReplace = NO;
        }
    }
    
    return (isReplace << 1) | isOriginal;
}

- (NSUInteger)numPatches {
    return _patches.count;
}

- (NSData *)patchDataWithOriginal:(bool)original {
    if (!self.data) {
        return nil;
    }
    NSMutableData *data = [NSMutableData dataWithData:self.data];
    for (TBPPatch *patch in _patches) {
        uint32_t off = patch.offset - _offset;
        if (original) {
            [data replaceBytesInRange:NSMakeRange(off, patch.original.length) withBytes:patch.original.bytes];
        } else {
            [data replaceBytesInRange:NSMakeRange(off, patch.replace.length) withBytes:patch.replace.bytes];
        }
    }
    return data;
}

@end
