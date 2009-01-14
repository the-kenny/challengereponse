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

#import <Adium/AISharedAdium.h>
#import <Adium/AIWindowController.h>
#import <Adium/AIPreferenceControllerProtocol.h>

@interface ChallengeResponsePreferences : AIWindowController {
	IBOutlet		NSWindow		*window;
	
	// Main window.
	IBOutlet		NSButton		*button_enable;
	IBOutlet		NSTabView		*tabView_options;
	
	// Settings tab
	IBOutlet		NSButton		*button_log;
	IBOutlet		NSButton		*button_hideBlocked;
	IBOutlet		NSButton		*button_justContain;
	
	IBOutlet		NSTextField		*textField_challenge;
	IBOutlet		NSTextField		*textField_response;
	
	// Whitelist tab
	IBOutlet		NSButton		*button_remove;
	
	IBOutlet		NSScrollView	*scrollView_whitelist;
	IBOutlet		NSTableView		*tableView_whitelist;
	
	// Whitelist store
	NSMutableArray	*whiteList;
	
	// Service popup
	NSMenu			*serviceMenu;
}

+ (void)showWindow;

- (IBAction)updatePreferences:(id)sender;
- (IBAction)addWhitelist:(id)sender;
- (IBAction)removeWhitelist:(id)sender;

@end
