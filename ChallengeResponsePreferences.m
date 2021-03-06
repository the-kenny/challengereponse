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
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIServiceMenu.h>
#import <Adium/AIService.h>
#import <AIUtilities/AIArrayAdditions.h>
#import <AIUtilities/AIPopUpButtonAdditions.h>

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
	whiteList = [[NSMutableArray alloc] init];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(tableViewSelectionDidChange:)
												 name:NSTableViewSelectionDidChangeNotification
											   object:tableView_whitelist];
	
	[[adium preferenceController] registerPreferenceObserver:self forGroup:CHALLENGE_RESPONSE_PREFERENCE_GROUP];
	
	[self updateControls];
	
	[tableView_whitelist setDataSource:self];
	
	serviceMenu = [AIServiceMenu menuOfServicesWithTarget:self 
									   activeServicesOnly:NO
										  longDescription:NO
												   format:nil];
	
	[serviceMenu setAutoenablesItems:YES];
	
	[[[tableView_whitelist tableColumnWithIdentifier:@"service"] dataCell] setMenu:serviceMenu];
	
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
	
	[whiteList removeAllObjects];
	[whiteList addObjectsFromArray:[prefDict objectForKey:CHALLENGE_RESPONSE_PREFERENCE_WHITELIST]];
	
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
		return [NSNumber numberWithInt:[[tableColumn dataCell] indexOfItemWithRepresentedObject:[[adium accountController] firstServiceWithServiceID:serviceID]]];
	} else if([identifier isEqualToString:@"uid"]) {
		return uid;
	}
	
	return nil;
}

/*!
 * @brief Target of the AIServiceMenu, required to validate the menu item
 */
- (void)selectServiceType:(id)service { }

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	if(row < 0 || row >= [whiteList count])
		return;
	
	NSString		*identifier = [tableColumn identifier];
	
	if([identifier isEqualToString:@"service"]) {
		
		NSString		*serviceID = [[[serviceMenu itemAtIndex:[object intValue]] representedObject] serviceID];		
		NSString		*internalObjectID = [whiteList objectAtIndex:row];	
		NSRange			periodRange = [internalObjectID rangeOfString:@"."];
		NSString		*uid = [internalObjectID substringFromIndex:(periodRange.location + 1)];

		[whiteList setObject:[AIListObject internalObjectIDForServiceID:serviceID
																	UID:uid]
					 atIndex:row];
		
		[[adium preferenceController] setPreference:whiteList
											 forKey:CHALLENGE_RESPONSE_PREFERENCE_WHITELIST
											  group:CHALLENGE_RESPONSE_PREFERENCE_GROUP];
		
		[tableView reloadData];
	} if([identifier isEqualToString:@"uid"]) {
		NSString		*internalObjectID = [whiteList objectAtIndex:row];
		NSRange			periodRange = [internalObjectID rangeOfString:@"."];
		NSString		*serviceID = [internalObjectID substringToIndex:periodRange.location];
		
		AIService		*service = [[adium accountController] firstServiceWithServiceID:serviceID];
			
		NSString *uid = [service normalizeUID:object
					  removeIgnoredCharacters:YES];

		[whiteList setObject:[AIListObject internalObjectIDForServiceID:serviceID
																	UID:uid]
					 atIndex:row];
		
		[[adium preferenceController] setPreference:whiteList
											 forKey:CHALLENGE_RESPONSE_PREFERENCE_WHITELIST
											  group:CHALLENGE_RESPONSE_PREFERENCE_GROUP];
		
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
	
	[button_log setEnabled:[[preferences objectForKey:CHALLENGE_RESPONSE_PREFERENCE_ENABLED] boolValue]];
	[button_log setState:[[preferences objectForKey:CHALLENGE_RESPONSE_PREFERENCE_LOGENABLED] boolValue]];
	[button_justContain setState:[[preferences objectForKey:CHALLENGE_RESPONSE_PREFERENCE_JUSTCONTAIN] boolValue]];
	
	[button_hideBlocked setState:[[preferences objectForKey:CHALLENGE_RESPONSE_PREFERENCE_HIDEBLOCKED] boolValue]];
	
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
	} else if(sender == button_log) {
		[[adium preferenceController] setPreference:[NSNumber numberWithBool:[sender state]]
											 forKey:CHALLENGE_RESPONSE_PREFERENCE_LOGENABLED
											  group:CHALLENGE_RESPONSE_PREFERENCE_GROUP];
		
		[self updateControls];
	} else if(sender == button_hideBlocked) {
		[[adium preferenceController] setPreference:[NSNumber numberWithBool:[sender state]]
											 forKey:CHALLENGE_RESPONSE_PREFERENCE_HIDEBLOCKED
											  group:CHALLENGE_RESPONSE_PREFERENCE_GROUP];	

	} else if(sender == button_justContain) {
		[[adium preferenceController] setPreference:[NSNumber numberWithBool:[sender state]]
											 forKey:CHALLENGE_RESPONSE_PREFERENCE_JUSTCONTAIN
											  group:CHALLENGE_RESPONSE_PREFERENCE_GROUP];	
	}
}

/*!
 * @brief Called when the add button is pressed.
 */
- (IBAction)addWhitelist:(id)sender
{
	[whiteList addObject:@"AIM.(placeholder)"];
	
	[tableView_whitelist reloadData];
}

/*!
 * @brief Called when the remove button is pressed
 */
- (IBAction)removeWhitelist:(id)sender
{	
	[whiteList removeObjectsAtIndexes:[tableView_whitelist selectedRowIndexes]];
	
	[[adium preferenceController] setPreference:whiteList
										 forKey:CHALLENGE_RESPONSE_PREFERENCE_WHITELIST
										  group:CHALLENGE_RESPONSE_PREFERENCE_GROUP];
	
	[tableView_whitelist reloadData];
}

@end
