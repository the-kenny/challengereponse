/* 
 * Adium is the legal property of its developers, whose names are listed in the copyright file included
 * with this source distribution.
 * 
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU
 * General Public License as published by the Free Software Foundation; either version 2 of the License,
 * or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
 * the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along with this program; if not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#import "ChallengeResponsePreferences.h"
#import "ChallengeResponsePlugin.h"
#import <AIUtilities/AIImageTextCell.h>
#import <Adium/AIPreferenceControllerProtocol.h>
#import <AIUtilities/AIArrayAdditions.h>

@interface ChallengeResponsePreferences ()
- (void)updateControls;
@end

@implementation ChallengeResponsePreferences

static ChallengeResponsePreferences *sharedInstance = nil;

/*!
 * @brief Shows the preference window using a shared instance
 */
+ (void)showWindow
{
	if(!sharedInstance) {
		sharedInstance = [[self alloc] initWithWindowNibName:@"ChallengeResponsePreferences"];
	}
	
	[sharedInstance showWindow:nil];
	[[sharedInstance window] makeKeyAndOrderFront:nil];
}

/*!
 * @brief Set up our defaults when we load
 */
- (void)windowDidLoad
{
	whiteList = [[NSMutableDictionary alloc] init];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(tableViewSelectionDidChange:)
												 name:NSTableViewSelectionDidChangeNotification
											   object:tableView_whitelist];
	
	[[adium preferenceController] registerPreferenceObserver:self forGroup:CHALLENGE_RESPONSE_PREFERENCE_GROUP];
	
	[self updateControls];
	
	[tableView_whitelist setDataSource:self];
	
	[super windowDidLoad];
}

/*!
 * @brief Unregister ourselves, unset our shared instance
 */
- (void)windowWillClose:(id)sender
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[adium preferenceController] unregisterPreferenceObserver:self];
	[sharedInstance release]; sharedInstance = nil;
	
	[super windowWillClose:sender];
}

/*!
 * @brief Deallocate
 */
- (void)dealloc
{
	[whiteList release]; whiteList = nil;
	
	[super dealloc];
}

/*!
 * @brief Frame autosave name
 */
- (NSString *)adiumFrameAutosaveName
{
	return @"Challenge/ResponseWindow";
}

/*!
 * @brief Save our whitelist, update controls
 */
- (void)preferencesChangedForGroup:(NSString *)group key:(NSString *)key
							object:(AIListObject *)object preferenceDict:(NSDictionary *)prefDict firstTime:(BOOL)firstTime
{
	if(object)
		return;
	
	[whiteList release];
	whiteList = [[prefDict objectForKey:CHALLENGE_RESPONSE_PREFERENCE_WHITELIST] mutableCopy];
	
	[self updateControls];
}

#pragma mark Data source
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [whiteList count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	if(row < 0 || row >= [whiteList count])
		return nil;
	
	NSString		*identifier = [tableColumn identifier];
	NSString		*internalObjectID = [whiteList objectAtIndex:row];
	NSRange			periodRange = [internalObjectID rangeOfString:@"."];
	NSString		*serviceID = [internalObjectID substringToIndex:periodRange.location];
	NSString		*uid = [internalObjectID substringFromIndex:(periodRange.location + 1)];
	
	if([identifier isEqualToString:@"service"]) {
		return [AIServiceIcons serviceIconForServiceID:serviceID
												  type:AIServiceIconList
											 direction:AIIconNormal];
	} else if([identifier isEqualToString:@"uid"]) {
		return uid;
	}
	
	return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	if(row < 0 || row >= [whiteList count])
		return;
	
	NSString		*identifier = [tableColumn identifier];
	
	if([identifier isEqualToString:@"uid"]) {
		NSString		*internalObjectID = [whiteList objectAtIndex:row];
		NSRange			periodRange = [internalObjectID rangeOfString:@"."];
		NSString		*serviceID = [internalObjectID substringToIndex:periodRange.location];
		
		NSMutableArray		*mutableWhiteList = [whiteList mutableCopy];
		
		[mutableWhiteList setObject:[AIListObject internalObjectIDForServiceID:serviceID
																		   UID:object]
							atIndex:row];
		
		[[adium preferenceController] setPreference:mutableWhiteList
											 forKey:CHALLENGE_RESPONSE_PREFERENCE_WHITELIST
											  group:CHALLENGE_RESPONSE_PREFERENCE_GROUP];
		
		[mutableWhiteList release];
		
		[tableView reloadData];
		
	}
}

#pragma mark Control updating
/*!
 * @brief Update controls when tableview selection cahnges
 */
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
			[self updateControls];
}

/*!
 * @brief Update control availability
 */
- (void)updateControls
{
	NSDictionary		*preferences = [[adium preferenceController] preferencesForGroup:CHALLENGE_RESPONSE_PREFERENCE_GROUP];
	
	[button_remove setEnabled:([tableView_whitelist numberOfSelectedRows] > 0)];
	
	[button_enable setState:[[preferences objectForKey:CHALLENGE_RESPONSE_PREFERENCE_ENABLED] boolValue]];
	
	[textField_response setStringValue:[preferences objectForKey:CHALLENGE_RESPONSE_PREFERENCE_RESPONSE] ?: @""];
	[textField_challenge setStringValue:[preferences objectForKey:CHALLENGE_RESPONSE_PREFERENCE_CHALLENGE] ?: @""];
	
	[tableView_whitelist reloadData];
}

#define View methods
/*!
 * @brief Target when preference controls change
 */
- (IBAction)updatePreferences:(id)sender
{
	if(sender == button_enable) {
		[[adium preferenceController] setPreference:[NSNumber numberWithBool:[sender state]]
											 forKey:CHALLENGE_RESPONSE_PREFERENCE_ENABLED
											  group:CHALLENGE_RESPONSE_PREFERENCE_GROUP];
		
	} else if(sender == textField_challenge) {
		[[adium preferenceController] setPreference:[sender stringValue]
											 forKey:CHALLENGE_RESPONSE_PREFERENCE_CHALLENGE
											  group:CHALLENGE_RESPONSE_PREFERENCE_GROUP];		
	} else if(sender == textField_response) {
		[[adium preferenceController] setPreference:[sender stringValue]
											 forKey:CHALLENGE_RESPONSE_PREFERENCE_RESPONSE
											  group:CHALLENGE_RESPONSE_PREFERENCE_GROUP];		
	}
}

/*!
 * @brief Called when the remove button is pressed
 */
- (IBAction)removeWhitelist:(id)sender
{
	NSMutableArray	*mutableWhiteList = [whiteList mutableCopy];
	
	[mutableWhiteList removeObjectsAtIndexes:[tableView_whitelist selectedRowIndexes]];
	
	[[adium preferenceController] setPreference:mutableWhiteList
										 forKey:CHALLENGE_RESPONSE_PREFERENCE_WHITELIST
										  group:CHALLENGE_RESPONSE_PREFERENCE_GROUP];
	
	[mutableWhiteList release];
	
	[tableView_whitelist reloadData];
}

@end
