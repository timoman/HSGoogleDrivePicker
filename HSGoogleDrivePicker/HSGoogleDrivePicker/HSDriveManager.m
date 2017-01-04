//
//  GDriveManager.m
//  gdrive
//
//  Created by Rob Jonson on 13/10/2015.
//  Copyright © 2015 HobbyistSoftware. All rights reserved.
//

#import "HSDriveManager.h"
#import "HSGIDSignInHandler.h"
#import <GTMOAuth2/GTMOAuth2ViewControllerTouch.h>


static NSString *const kKeychainItemName = @"Drive API";

@interface HSDriveManager ()

@property (retain) NSString *clientId;
@property (retain) NSString *clientSecret;
@property (nonatomic, strong) GTLServiceDrive *service;
@property (retain) GTMOAuth2ViewControllerTouch *authController;
@property (nonatomic) Class authControllerClass;

@end

@implementation HSDriveManager

- (instancetype)initWithId:(NSString*)clientId secret:(NSString*)secret
{
    return [self initWithId:clientId secret:secret authControllerClass:[GTMOAuth2ViewControllerTouch class]];
}

- (instancetype)initWithId:(NSString*)clientId secret:(NSString*)secret authControllerClass:(Class)authControllerClass
{
    self = [super init];
    if (self) {
        if (![authControllerClass isSubclassOfClass:[GTMOAuth2ViewControllerTouch class]]) {
            [NSException raise:@"Invalid authControllerClass" format:@"authControllerClass must be a subclass of GTMOAuth2ViewControllerTouch but was %@", authControllerClass];
        } else {
            self.authControllerClass = authControllerClass;
        }

        self.clientId=clientId;
        self.clientSecret=secret;
        // Initialize the Drive API service & load existing credentials from the keychain if available.
        self.service = [[GTLServiceDrive alloc] init];
        
        self.service.authorizer = [HSGIDSignInHandler authoriser];
        
        self.folderId=@"root";
        self.maxResults=1000;

    }
    return self;
}

#pragma mark download

-(GTMSessionFetcher*)downloadFile:(GTLDriveFile*)file toPath:(NSString*)path withCompletionHandler:(void (^)(NSError *error))handler
{
    GTMSessionFetcher *fetcher = [self.service.fetcherService fetcherWithURLString:file.downloadUrl];
    NSURL* destinationUrl=[NSURL fileURLWithPath:path];
    [fetcher setDestinationFileURL:destinationUrl];
    [fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error) {
        if (error == nil) {
            // Success.
            handler( nil);
        } else {
            NSLog(@"An error occurred: %@", error);
            handler( error);
        }
    }];

    return fetcher;
}

#pragma mark file listing

-(NSString*)query
{
    NSString *query=[NSString stringWithFormat:@"'%@' in parents", self.folderId];
    if (self.sharedWithMe)
    {
        query=@"sharedWithMe";
    }

    if (!self.showTrashed)
    {
        query=[query stringByAppendingString:@" and trashed = false"];
    }


    return query;
}

// Construct a query to get names and IDs of files using the Google Drive API.
- (void)fetchFilesWithCompletionHandler:(void (^)(GTLServiceTicket *ticket, GTLDriveFileList *fileList, NSError *error))handler
{

    self.service.shouldFetchNextPages = self.autoFetchPages;

    GTLQueryDrive *query = [GTLQueryDrive queryForFilesList];

    query.q=[self query];
    query.fields=@"files(id,kind,mimeType,name,size,iconLink)";
    
    
    query.pageSize = self.maxResults;
    [self.service executeQuery:query
             completionHandler:handler];

}

#pragma mark auth controller

-(void)updateAuthoriser
{
    self.service.authorizer = [HSGIDSignInHandler authoriser];
}


@end
