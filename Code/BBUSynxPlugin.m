//
//  BBUsynx-plugin.m
//  BBUsynx-plugin
//
//  Created by Boris Bügling on 22/06/14.
//    Copyright (c) 2014 Boris Bügling. All rights reserved.
//

#import "BBUSynxPlugin.h"

static BBUSynxPlugin *sharedPlugin;

@interface BBUSynxPlugin ()

@property (nonatomic, strong) NSBundle *bundle;

@end

#pragma mark -

@implementation BBUSynxPlugin

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init]) {
        self.bundle = plugin;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
