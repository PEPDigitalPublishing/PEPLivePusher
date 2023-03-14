//
//  PEPLivePusherUtility.h
//  LivePusher
//
//  Created by 李沛倬 on 2019/8/19.
//  Copyright © 2019 pep. All rights reserved.
//

#ifndef PEPLivePusherUtility_h
#define PEPLivePusherUtility_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static NSBundle *PEPLivePusherBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bundle = [NSBundle bundleWithPath:[NSBundle.mainBundle pathForResource:@"PEPLivePusher" ofType:@"bundle"]];
    });
    
    return bundle;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"

static NSString *PEPLivePusherLocalizedString(NSString *key) {
    return [PEPLivePusherBundle() localizedStringForKey:key value:@"" table:@"PEPLivePusher"];
}

static UIImage *ImageNamedFromPEPLivePusherBundle(NSString *name) {
    NSString *imgName = [@"PEPLivePusher.bundle" stringByAppendingPathComponent:name];
    return [UIImage imageNamed:imgName];
}

#pragma clang diagnostic pop


#endif /* PEPLivePusherUtility_h */
