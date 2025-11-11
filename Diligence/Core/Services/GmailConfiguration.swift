//
//  GmailConfiguration.swift
//  Diligence
//
//  Created by derham on 10/24/25.
//

import Foundation

struct GmailConfiguration {
    // MARK: - OAuth Configuration
    
    // Gmail API OAuth credentials from Google Cloud Console
    static let clientID = "1002215545273-ce3cd60tu1vahh5sg1e9crgat1rvkn9o.apps.googleusercontent.com"
    static let clientSecret = "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"
    
    // This should match your app's URL scheme in Info.plist
    static let redirectURI = "http://localhost:3000/oauth/callback"
    
    // Gmail API scopes - we only need read access
    static let scopes = [
        "https://www.googleapis.com/auth/gmail.readonly"
    ]
    
    // MARK: - Setup Instructions
    /*
     To set up Gmail API access:
     
     1. Go to https://console.cloud.google.com/
     2. Create a new project or select an existing one
     3. Enable the Gmail API for your project
     4. Create OAuth 2.0 credentials:
        - Application type: Desktop application
        - Name: Diligence macOS App (or whatever you prefer)
     5. Add the redirect URI to your OAuth client:
        - Use the same redirect URI as defined above
     6. Download the credentials and update the clientID and clientSecret above
     7. In your app's Info.plist, add a URL scheme that matches your redirect URI:
        - URL identifier: com.yourcompany.diligence
        - URL Schemes: com.yourcompany.diligence
     
     Example Info.plist entry:
     <key>CFBundleURLTypes</key>
     <array>
         <dict>
             <key>CFBundleURLName</key>
             <string>com.yourcompany.diligence</string>
             <key>CFBundleURLSchemes</key>
             <array>
                 <string>com.yourcompany.diligence</string>
             </array>
         </dict>
     </array>
     
     TROUBLESHOOTING "server with the specified hostname could not be found":
     
     1. Network Connectivity:
        - Check your internet connection
        - Try visiting https://mail.google.com in your browser
        - Check if you're behind a corporate firewall or proxy
     
     2. DNS Issues:
        - Try flushing DNS cache: sudo dscacheutil -flushcache
        - Try using Google's DNS: 8.8.8.8 and 8.8.4.4
        - Check /etc/hosts file for any Gmail/Google blocks
     
     3. macOS Network Settings:
        - Check System Preferences > Network > Advanced > Proxies
        - Temporarily disable any VPN connections
        - Check if Little Snitch or similar apps are blocking connections
     
     4. Firewall/Security Software:
        - Check if macOS Firewall is blocking the app
        - Temporarily disable antivirus software
        - Check corporate security policies
     
     5. OAuth Configuration:
        - Verify clientID and clientSecret are correct
        - Make sure Gmail API is enabled in Google Cloud Console
        - Check OAuth consent screen is configured properly
     */
}
