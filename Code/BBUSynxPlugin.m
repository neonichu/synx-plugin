//
//  BBUsynx-plugin.m
//  synx-plugin
//
//  Created by Boris Bügling on 22/06/14.
//    Copyright (c) 2014 Boris Bügling. All rights reserved.
//

#import <objc/runtime.h>
#import <Aspects/Aspects.h>

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

        [self swizzleOpeningWorkspaceDocument];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)logOutputToPipe:(NSPipe*)pipe
{
    [[pipe fileHandleForReading] waitForDataInBackgroundAndNotify];

    return [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleDataAvailableNotification object:[pipe fileHandleForReading] queue:nil usingBlock:^(NSNotification*notification) {
        NSData *output = [[pipe fileHandleForReading] availableData];
        NSString *outStr = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];

        dispatch_sync(dispatch_get_main_queue(), ^{
            NSLog(@"synx-plugin: %@", outStr);
        });

        [[pipe fileHandleForReading] waitForDataInBackgroundAndNotify];
    }];
}

- (void)runTask:(NSTask*)task
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        task.standardError = [NSPipe new];
        task.standardOutput = [NSPipe new];

        id errorObserver = [self logOutputToPipe:task.standardError];
        id outputObserver = [self logOutputToPipe:task.standardOutput];

        [task launch];
        [task waitUntilExit];
        
        [[NSNotificationCenter defaultCenter] removeObserver:errorObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:outputObserver];
    });
}

- (void)swizzleOpeningWorkspaceDocument
{
    NSError* error = nil;
    [objc_getClass("IDEWorkspaceDocument") aspect_hookSelector:@selector(readFromURL:ofType:error:) withOptions:AspectPositionBefore usingBlock:^(id<AspectInfo> info, NSURL* url, id type, NSError** error) {
        NSString* path = [url path];
        NSString* project = nil;

        if ([path.lastPathComponent isEqualToString:@"project.xcworkspace"]) {
            project = [[path stringByDeletingLastPathComponent] lastPathComponent];
            path = [[path stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
        } else {
            path = [path stringByDeletingLastPathComponent];

            for (NSString* file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path
                                                                                       error:nil]) {
                if ([file.pathExtension isEqualToString:@"xcodeproj"]) {
                    project = file;
                    break;
                }
            }
        }

        if (!path || !project) {
            return;
        }

        NSTask* synxTask = [NSTask new];
        [synxTask setArguments:@[ project ]];
        [synxTask setCurrentDirectoryPath:path];
        [synxTask setLaunchPath:@"/usr/bin/synx"];

        [self runTask:synxTask];
    } error:&error];

    if (error) {
        NSLog(@"Could not initialize synx-plugin: %@", error);
    }
}

@end
