#!/bin/sh

#  headerdoc2docset.sh
#  AHDispatch
#
#  Created by Ray Scott on 19/12/2013.
#  Copyright (c) 2013 Alien Hitcher. All rights reserved.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
# 
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
# 
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.

#///////////////////////////////////////////////////////////////////////////////
# SETTINGS
#///////////////////////////////////////////////////////////////////////////////

# PlistBuddy location
PLIST_BUDDY_HOME=/usr/libexec

# location of our source code, where headerdoc2html will start from
SOURCE_DIR=AHDispatch

# Publisher
DOCSET_PUBLISHER_NAME="Alien Hitcher"
DOCSET_PUBLISHER_ID="com.alienhitcher.documentation"

# Doc set deployment location
DOCSET_NAME=com.alienhitcher.$PROJECT_NAME.docset 
DOCSET_HOME=~/Library/Developer/Shared/Documentation/DocSets
DOCSET_DIR=$DOCSET_HOME/$DOCSET_NAME

# Build site
DOCSET_BUILD_HOME=HeaderDoc # Root will become *.docset and deployed to $DOCSET_HOME
DOCSET_BUILD_DOCUMENTS=$DOCSET_BUILD_HOME/Contents/Resources/Documents # Build location of headerdoc2html output
DOCSET_BUILD_RESOURCES=$DOCSET_BUILD_HOME/Contents/Resources # Build location of headerdoc2html output
DOCSET_BUILD_INFO_PLIST=$DOCSET_BUILD_HOME/Contents/Info.plist

# location of html code document, generated by headerdoc2html
RESOURCES_DIR=$DOCSET_DIR/Contents/Resources
DOCUMENT_DIR=$RESOURCES_DIR/Documents

#///////////////////////////////////////////////////////////////////////////////
# CLEAN
#///////////////////////////////////////////////////////////////////////////////

# create/clean build site
if [ -d ./$DOCSET_BUILD_HOME/Contents ]; then
    rm -rd ./$DOCSET_BUILD_HOME/Contents
fi

mkdir -p ./$DOCSET_BUILD_DOCUMENTS

#///////////////////////////////////////////////////////////////////////////////
# BUILD
#///////////////////////////////////////////////////////////////////////////////

# generate html code document for source code.  -j will recognize java comment tag ex. /** */
headerdoc2html -p -o $DOCSET_BUILD_DOCUMENTS $SOURCE_DIR

# generate main index file. -d will generate Tokens.xml for us.
gatherheaderdoc -d $DOCSET_BUILD_RESOURCES

# extract existing plist info data from main project 
PLIST_BUNDLE_ID=`$PLIST_BUDDY_HOME/PlistBuddy -c "Print :CFBundleIdentifier" $INFOPLIST_FILE 2>&1`

# generate Info.plist file
$PLIST_BUDDY_HOME/PlistBuddy -c "Add :CFBundleName string '$PROJECT_NAME API Reference'" $DOCSET_BUILD_INFO_PLIST
$PLIST_BUDDY_HOME/PlistBuddy -c "Add :CFBundleIdentifier string '$PLIST_BUNDLE_ID.docset'" $DOCSET_BUILD_INFO_PLIST
$PLIST_BUDDY_HOME/PlistBuddy -c "Add :DocSetPublisherIdentifier string '$DOCSET_PUBLISHER_ID'" $DOCSET_BUILD_INFO_PLIST
$PLIST_BUDDY_HOME/PlistBuddy -c "Add :DocSetPublisherName string '$DOCSET_PUBLISHER_NAME'" $DOCSET_BUILD_INFO_PLIST
$PLIST_BUDDY_HOME/PlistBuddy -c "Add :DocSetDescription string 'API reference for AHDispatch.'" $DOCSET_BUILD_INFO_PLIST
$PLIST_BUDDY_HOME/PlistBuddy -c "Add :DocSetFallbackURL string 'http://rayascott.github.io/AHDispatch'" $DOCSET_BUILD_INFO_PLIST
$PLIST_BUDDY_HOME/PlistBuddy -c "Add :NSHumanReadableCopyright string 'Copyright © Alien Hitcher. All rights reserved.'" $DOCSET_BUILD_INFO_PLIST

#///////////////////////////////////////////////////////////////////////////////
# DEPLOY
#///////////////////////////////////////////////////////////////////////////////

# deploy docset to Xcode docset home
if [ -d ./$DOCSET_DIR ]; then
    rm -rdf ./$DOCSET_DIR
fi

mkdir -p $DOCSET_DIR
cp -R $DOCSET_BUILD_HOME/Contents $DOCSET_DIR

#///////////////////////////////////////////////////////////////////////////////
# VALIDATE
#///////////////////////////////////////////////////////////////////////////////

#/Applications/Xcode.app/Contents/Developer/usr/bin/docsetutil validate -verbose -debug $DOCSET_DIR
