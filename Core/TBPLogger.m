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

@implementation TBPLogger

static TBPLogger *sharedInstance = nil;

+ (TBPLogger *)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[TBPLogger alloc] init];
    }
    return sharedInstance;
}

- (id)init {
    if (self = [super init]) {
        _logger = ^ (NSString *line) {
            NSLog(@"%@", line);
        };
    }
    return self;
}

- (void)log:(NSString *)fmt, ... {
    va_list args;
    va_start(args, fmt);
    NSString *line = [[NSString alloc] initWithFormat:fmt arguments:args];
    self.logger(line);
}

@end

void TBPLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *line = [[NSString alloc] initWithFormat:fmt arguments:args];
    [TBPLogger sharedInstance].logger(line);
}
