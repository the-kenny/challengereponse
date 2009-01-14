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

#import "ChallengeResponsePlugin.h"
#import "ChallengeResponsePreferences.h"
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIDictionaryAdditions.h>
#import <Adium/AIAdiumProtocol.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIPreferenceControllerProtocol.h>
#import <Adium/AIMenuControllerProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIListObject.h>
#import <Adium/AIChat.h>
#import <Adium/AIContentObject.h>

@interface ChallengeResponsePlugin()
- (void)logContentObject:(AIContentObject *)contentObject;
@end

@implementation ChallengeResponsePlugin

/*!
 * @brief Initialize default values and register observers
 */
- (void)installPlugin
{
	menuItem_challengeResponse = [[NSMenuItem alloc] initWithTitle:@"Challenge/Response"
															target:self
															action:@selector(showPreferences:)
													 keyEquivalent:@""];
	
	[[adium menuController] addMenuItem:menuItem_challengeResponse toLocation:LOC_Adium_Preferences];
	
	whiteList = nil;
	
	greyListContent = [[NSMutableDictionary alloc] init];
	openChats = [[NSMutableDictionary alloc] init];
	
	[[adium preferenceController] registerPreferenceObserver:self forGroup:CHALLENGE_RESPONSE_PREFERENCE_GROUP];
}

/*!
 * @brief Remove observers
 */
- (void)uninstallPlugin
{
	[[adium preferenceController] unregisterPreferenceObserver:self];
	[[adium notificationCenter] removeObserver:self];
}

/*!
 * @brief Deallocate
 */
- (void)dealloc
{
	[whiteList release];
	[greyListContent release];
	[menuItem_challengeResponse release];
	[challengeMessage release];
	[responseMessage release];
	[openChats release];
	
	[super dealloc];
}

/*! 
 * @brief The menu item is always valid
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	return YES;
}

/*!
 * @brief Ask the C/R preferences to display
 */
- (IBAction)showPreferences:(id)sender
{
	[ChallengeResponsePreferences showWindow];
}

#pragma mark Chat handing
/*!
 * @brief Handles content before it's displayed
 *
 * If a content object requires sending a challenge, we prevent its display and re-display it when the
 * channge is successfully responded to
 */
- (void)willReceiveContent:(NSNotification *)notification
{
	if((!enabled || !challengeMessage || !responseMessage) && (!hideBlocked))
		return;
	
	AIContentObject		*contentObject = [[notification userInfo] objectForKey:@"Object"];
	
	// Don't do anything to group chats.
	if([[contentObject chat] isGroupChat])
		return;
	
	AIListObject		*listObject = [contentObject source];
	
	if((hideBlocked && [listObject isBlocked])) {
		// Do nothing.
		[contentObject setDisplayContent:NO];
		NSLog(@"C/R: Hiding %@ (blocked)", listObject);
	} else if(!enabled || !challengeMessage || !responseMessage) {
		// Don't do anything when not enabled, or without a challenge or response message.
		// This lets the "hide blocked" above get executed, but prevents the C/R portion from doing so.
		
		NSLog(@"C/R: Not enabled, no chalennge message or no response message.");
	} else if ([[contentObject chat] isOpen] && ![self listObjectIsWhitelisted:listObject]) {	
		NSLog(@"C/R: Open chat from non-whitelisted; whitelisting.");
		
		// Automatically whitelist those we manually start chats with		
		[self addListObjectToWhitelist:listObject];
		[self displayGreyListAndClearForObjectID:[listObject internalObjectID]];
		
	} else if (![self listObjectIsWhitelisted:listObject]) {		
		// Always hide content if not whitelisted
		[contentObject setDisplayContent:NO];
		
		if([self savedGreyListExistsForListObject:listObject]) {		
			// User has already messaged us; check if this matches the response
			NSString		*message = [[contentObject message] string];
			
			if(mustJustContain) {
				NSRange range = [message rangeOfString:responseMessage options:NSCaseInsensitiveSearch];
				//rangeOfString: returns {NSNotFound, 0} if the string isn't found
				if(range.location != NSNotFound && range.length != 0) {
					NSLog(@"C/R: User %@ provided valid response (%@ = %@)", listObject, message, responseMessage);
					
					// User has passed the challenge; present them to the user and add to the whitelist
					[self addListObjectToWhitelist:listObject];
					[self displayGreyListAndClearForObjectID:[listObject internalObjectID]];
				} else {				
					// User has failed the challenge; continue saving content
					[self addToGreyList:contentObject];
				}
			} else {
				if([message compare:responseMessage	options:NSCaseInsensitiveSearch] == NSOrderedSame) {
					NSLog(@"C/R: User %@ provided valid response (%@ = %@)", listObject, message, responseMessage);
					
					// User has passed the challenge; present them to the user and add to the whitelist
					[self addListObjectToWhitelist:listObject];
					[self displayGreyListAndClearForObjectID:[listObject internalObjectID]];
				} else {				
					// User has failed the challenge; continue saving content
					[self addToGreyList:contentObject];
				}
			}
		} else {
			NSLog(@"C/R: First-time message from user %@", listObject);
			
			// User has not already messaged us; add this content to our greylist
			[self addToGreyList:contentObject];
			
			// Send the challenge response
			[[adium contentController] sendRawMessage:challengeMessage toContact:(AIListContact *)listObject];
		}
		
		// Log if set to do so
		if(loggingEnabled) {
			[self logContentObject:contentObject];		
		}		
	}
}

- (void)logContentObject:(AIContentObject *)contentObject
{
	// This shouldn't happen, but shrug. Break if we arne't destinationed to an account.
	if(![[contentObject destination] isKindOfClass:[AIAccount class]]) {
		return;
	}
	
	AIAccount	*account = (AIAccount *)[contentObject destination];
	
	AIChat		*chat = [openChats objectForKey:[account internalObjectID]];
	
	// Chat doesn't already exist, we have to make our own!
	if(!chat) {
		chat = [AIChat chatForAccount:account];
		
		[chat setName:CHALLENGE_RESPONSE_CHAT_NAME];
		[chat setIsGroupChat:YES];
		[openChats setObject:chat forKey:[account internalObjectID]];
	}
	
	// Fake it.
	AIChat		*originalChat = [contentObject chat];
	BOOL		originalDisplayContent = [contentObject displayContent];
	
	[contentObject setChat:chat];
	[contentObject setDisplayContent:YES];
	
	[[adium notificationCenter] postNotificationName:Content_ContentObjectAdded
											  object:chat
											userInfo:[NSDictionary dictionaryWithObjectsAndKeys:contentObject,@"AIContentObject",nil]];
	
	[contentObject setChat:originalChat];
	[contentObject setDisplayContent:originalDisplayContent];
}

#pragma mark Greylist handling
/*!
 * @brief Has this contact already messaged us?
 * @return YES if we have saved content, otherwise NO
 */
- (BOOL)savedGreyListExistsForListObject:(AIListObject *)listObject
{
	return ([greyListContent objectForKey:[listObject internalObjectID]] != nil);
}

/*!
 * @brief Adds content to a list object's grey list
 *
 * @param contentObject the AIContentObject to add
 *
 * This adds the \c contentObject to the \c contentObject's source greylist
 */
- (void)addToGreyList:(AIContentObject *)contentObject
{
	AIListObject	*listObject = [contentObject source];
	NSArray			*contentArray = [greyListContent objectForKey:[listObject internalObjectID]];
	
	contentArray = [[NSArray arrayWithArray:contentArray] arrayByAddingObject:contentObject];
	
	[greyListContent setObject:contentArray forKey:[listObject internalObjectID]];
}

/*!
 * @brief Display and clear a greylist
 *
 * Displays all saved content we have for a list contact, and then removes our store
 */
- (void)displayGreyListAndClearForObjectID:(NSString *)objectID
{
	if (![greyListContent objectForKey:objectID])
		return;
	
	NSEnumerator		*enumerator = [(NSArray *)[greyListContent objectForKey:objectID] objectEnumerator];
	AIContentObject		*contentObject;
	
	while ((contentObject = [enumerator nextObject])) {
		[contentObject setDisplayContent:YES];
		[[adium contentController] receiveContentObject:contentObject];
	}
	
	[greyListContent removeObjectForKey:objectID];
}

#pragma mark Whitelist handling

/*!
 * @brief Adds a list object ot the white list
 *
 * @param listObject The list object to  add to the whitelist
 */
- (void)addListObjectToWhitelist:(AIListObject *)listObject
{
	NSArray		*newArray = [[NSArray arrayWithArray:whiteList] arrayByAddingObject:[listObject internalObjectID]];

	[[adium preferenceController] setPreference:newArray
										 forKey:CHALLENGE_RESPONSE_PREFERENCE_WHITELIST
										  group:CHALLENGE_RESPONSE_PREFERENCE_GROUP];
}

/*!
 * @brief Checks if a list object is whitelisted
 * @return YES if whitelisted, otherwise NO
 *
 * This will also return YES if the user is on the contact list
 */
- (BOOL)listObjectIsWhitelisted:(AIListObject *)listObject
{
	return ((![listObject isStranger] && [(AIListContact *)listObject isIntentionallyNotAStranger]) ||
			[whiteList containsObject:[listObject internalObjectID]]);
}

- (void)preferencesChangedForGroup:(NSString *)group key:(NSString *)key
							object:(AIListObject *)object preferenceDict:(NSDictionary *)prefDict firstTime:(BOOL)firstTime
{
	if(object)
		return;

	[whiteList release];
	whiteList = [[prefDict objectForKey:CHALLENGE_RESPONSE_PREFERENCE_WHITELIST] retain];
	
	[challengeMessage release];
	challengeMessage = [[prefDict objectForKey:CHALLENGE_RESPONSE_PREFERENCE_CHALLENGE] retain];
	
	[responseMessage release];
	responseMessage = [[prefDict objectForKey:CHALLENGE_RESPONSE_PREFERENCE_RESPONSE] retain];
	
	hideBlocked = [[prefDict objectForKey:CHALLENGE_RESPONSE_PREFERENCE_HIDEBLOCKED] boolValue];
	
	mustJustContain = [[prefDict objectForKey:CHALLENGE_RESPONSE_PREFERENCE_JUSTCONTAIN] boolValue];
	
	// Overall enabled
	if([key isEqualToString:CHALLENGE_RESPONSE_PREFERENCE_ENABLED] || firstTime) {
		enabled = [[prefDict objectForKey:CHALLENGE_RESPONSE_PREFERENCE_ENABLED] boolValue];
		
		if(enabled) {
			[[adium notificationCenter] addObserver:self
										   selector:@selector(willReceiveContent:)
											   name:Content_WillReceiveContent
											 object:nil];	
		} else if(!firstTime) {
			// Unregister ourself as an observer.			
			[[adium notificationCenter] removeObserver:self];
			
			// Restore all saved messages we have.
			NSEnumerator		*enumerator = [greyListContent keyEnumerator];
			NSString			*objectID;
			
			while((objectID = [enumerator nextObject])) {
				[self displayGreyListAndClearForObjectID:objectID];
			}
		}
	}

	// Logging enabled
	if([key isEqualToString:CHALLENGE_RESPONSE_PREFERENCE_LOGENABLED] || firstTime) {
		loggingEnabled = [[prefDict objectForKey:CHALLENGE_RESPONSE_PREFERENCE_LOGENABLED] boolValue];
		
		// Close all active chats we have.
		if(!loggingEnabled && !firstTime) {
			[openChats removeAllObjects];
		}
	}
}

@end
