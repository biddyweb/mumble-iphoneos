/* Copyright (C) 2009-2010 Mikkel Krautz <mikkel@krautz.dk>

   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

   - Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
   - Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution.
   - Neither the name of the Mumble Developers nor the names of its
     contributors may be used to endorse or promote products derived from this
     software without specific prior written permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "ServerRootViewController.h"
#import "ChannelViewController.h"
#import "LogViewController.h"
#import "UserViewController.h"
#import "PDFImageLoader.h"

@implementation ServerRootViewController

- (id) initWithHostname:(NSString *)host port:(NSUInteger)port {
	self = [super init];
	if (! self)
		return nil;

	_connection = [[MKConnection alloc] init];
	[_connection setDelegate:self];

	_model = [[MKServerModel alloc] initWithConnection:_connection];
	[_model addDelegate:self];

	[_connection connectToHost:host port:port];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userTalkStateChanged:) name:@"MKUserTalkStateChanged" object:nil];
	
	return self;
}

- (void) dealloc {
	[super dealloc];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void) viewDidAppear:(BOOL)animated {
	UIBarButtonItem *micItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:nil action:nil];
	[[self navigationController] setToolbarItems:[NSArray arrayWithObjects:micItem, nil]];
	[[self navigationController] setToolbarHidden:NO];
	[micItem release];
}

#pragma mark MKConnection Delegate

//
// The connection encountered an invalid SSL certificate chain. For now, we will show this dialog
// each time, as iPhoneOS 3.{1,2}.X doesn't allow for trusting certificates on an app-to-app basis.
//
- (void) connection:(MKConnection *)conn trustFailureInCertificateChain:(NSArray *)chain {
	NSString *title = @"Unable to validate server certificate";
	NSString *msg = @"Mumble was unable to validate the certificate chain of the server.";

	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:msg delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
	[alert addButtonWithTitle:@"OK"];
	[alert show];
	[alert release];
}

//
// The server rejected our connection.
//
- (void) connection:(MKConnection *)conn rejectedWithReason:(MKRejectReason)reason explanation:(NSString *)explanation {
	NSString *title = @"Connection Rejected";
	NSString *msg = nil;

	switch (reason) {
		case MKRejectReasonNone:
			msg = @"No reason";
			break;
		case MKRejectReasonWrongVersion:
			msg = @"Version mismatch between client and server.";
			break;
		case MKRejectReasonInvalidUsername:
			msg = @"Invalid username";
			break;
		case MKRejectReasonWrongUserPassword:
			msg = @"Wrong user password";
			break;
		case MKRejectReasonWrongServerPassword:
			msg = @"Wrong server password";
			break;
		case MKRejectReasonUsernameInUse:
			msg = @"Username already in use";
			break;
		case MKRejectReasonServerIsFull:
			msg = @"Server is full";
			break;
		case MKRejectReasonNoCertificate:
			msg = @"A certificate is needed to connect to this server";
			break;
	}

	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	[alert release];
}

//
// An SSL connection has been opened to the server.  We should authenticate ourselves.
//
- (void) connectionOpened:(MKConnection *)conn {
	[conn authenticateWithUsername:@"MumbleiPhoneUser" password:nil];
}

#pragma mark MKServerModel Delegate

//
// We've successfuly joined the server.
//
- (void) serverModel:(MKServerModel *)server joinedServerAsUser:(MKUser *)user {
	_currentChannel = [[_model connectedUser] channel];
	_channelUsers = [[[[_model connectedUser] channel] users] mutableCopy];
	[[self tableView] reloadData];
}

//
// A user joined the server.
//
- (void) serverModel:(MKServerModel *)server userJoined:(MKUser *)user {
	NSLog(@"ServerViewController: userJoined.");
}

//
// A user left the server.
//
- (void) serverModel:(MKServerModel *)server userLeft:(MKUser *)user {
	if (_currentChannel == nil)
		return;

	NSUInteger userIndex = [_channelUsers indexOfObject:user];
	if (userIndex != NSNotFound) {
		[_channelUsers removeObjectAtIndex:userIndex];
		[[self tableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIndex inSection:0]]
								withRowAnimation:UITableViewRowAnimationRight];
	}
}

//
// A user moved channel
//
- (void) serverModel:(MKServerModel *)server userMoved:(MKUser *)user toChannel:(MKChannel *)chan byUser:(MKUser *)mover {
	if (_currentChannel == nil)
		return;
	
	// Did the user join this channel?
	if (chan == _currentChannel) {
		[_channelUsers addObject:user];
		NSUInteger userIndex = [_channelUsers indexOfObject:user];
		[[self tableView] insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIndex inSection:0]]
								withRowAnimation:UITableViewRowAnimationLeft];
		// Or did he leave it?
	} else {
		NSUInteger userIndex = [_channelUsers indexOfObject:user];
		if (userIndex != NSNotFound) {
			[_channelUsers removeObjectAtIndex:userIndex];
			[[self tableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIndex inSection:0]]
									withRowAnimation:UITableViewRowAnimationRight];
		}
	}
}

//
// A channel was added.
//
- (void) serverModel:(MKServerModel *)server channelAdded:(MKChannel *)channel {
	NSLog(@"ServerViewController: channelAdded.");
}

//
// A channel was removed.
//
- (void) serverModel:(MKServerModel *)server channelRemoved:(MKChannel *)channel {
	NSLog(@"ServerViewController: channelRemoved.");
}

//
// User talk state changed
//
- (void) userTalkStateChanged:(NSNotification *)notification {
	if (_currentChannel == nil)
		return;
	
	MKUser *user = [notification object];
	NSUInteger userIndex = [_channelUsers indexOfObject:user];
	
	if (userIndex == NSNotFound)
		return;
	
	UITableViewCell *cell = [[self tableView] cellForRowAtIndexPath:[NSIndexPath indexPathForRow:userIndex inSection:0]];
	
	MKTalkState talkState = [user talkState];
	NSString *talkImageName = nil;
	if (talkState == MKTalkStatePassive)
		talkImageName = @"talking_off";
	else if (talkState == MKTalkStateTalking)
		talkImageName = @"talking_on";
	else if (talkState == MKTalkStateWhispering)
		talkImageName = @"talking_whisper";
	else if (talkState == MKTalkStateShouting)
		talkImageName = @"talking_alt";
	
	UIImageView *imageView = [cell imageView];
	UIImage *image = [PDFImageLoader imageFromPDF:talkImageName];
	[imageView setImage:image];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_channelUsers count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
    static NSString *CellIdentifier = @"Cell";
	
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
	
	NSUInteger row = [indexPath row];
	MKUser *user = [_channelUsers objectAtIndex:row];
	
	cell.textLabel.text = [user userName];
	
	MKTalkState talkState = [user talkState];
	NSString *talkImageName = nil;
	if (talkState == MKTalkStatePassive)
		talkImageName = @"talking_off";
	else if (talkState == MKTalkStateTalking)
		talkImageName = @"talking_on";
	else if (talkState == MKTalkStateWhispering)
		talkImageName = @"talking_whisper";
	else if (talkState == MKTalkStateShouting)
		talkImageName = @"talking_alt";
	cell.imageView.image = [PDFImageLoader imageFromPDF:talkImageName];
	
    return cell;
}

#pragma mark -
#pragma mark UIAlertView delegate

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	[_connection setIgnoreSSLVerification:YES];
	[_connection reconnect];
}

@end