// Copyright (c) 2009 Tim Duckett (www.adoptioncurve.net)
//
// Based on original code by Bob S (http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1231812230)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
// http://www.opensource.org/licenses/mit-license.php
//
//  Assumptions: single XML line looks like:
//    <tag>data</tag> or <tag>data
//
//////////////////////////////////////////////

// Include description files for other libraries used (if any)
#include <string.h>
#include <Ethernet.h>

// Define Constants
// Max string length may have to be adjusted depending on data to be extracted
#define MAX_STRING_LEN  20

// Setup vars
char tagStr[MAX_STRING_LEN] = "";
char dataStr[MAX_STRING_LEN] = "";
char tmpStr[MAX_STRING_LEN] = "";
char endTag[3] = {'<', '/', '\0'};
int len;

// Flags to differentiate XML tags from document elements (ie. data)
boolean tagFlag = false;
boolean dataFlag = false;

// Ethernet vars
byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };  // Set MAC address to DE-AD-BE-EF-FE-ED
byte ip[] = { 192, 168, 1, 150 };                     // Set IP address to 192.169.1.150
byte server[] = { 67, 297, 146, 63 };                 // www.adoptioncurve.net (67.207.146.63)
byte netmask[] = {255, 255, 255, 0 };
byte gateway[] = {192, 168, 1, 1 };                   // Set default gateway to 192.168.1.1

// Start ethernet client
Client client(server, 80);

void setup()
{
  Serial.begin(9600);
  Serial.println("Starting MarketBear");
  Serial.println("connecting...");
  Ethernet.begin(mac, ip);
  delay(1000);

  if (client.connect()) {
    Serial.println("connected");
    client.println("GET /marketbear.xml HTTP/1.0");    
    client.println();
    delay(2000);
  } else {
    Serial.println("connection failed");
  }  
}

void loop() {

  // Read serial data in from web:
  while (client.available()) {
    serialEvent();
  }

  if (!client.connected()) {
    //Serial.println();
    //Serial.println("Disconnected");
    client.stop();

    // Wait 15 minutes until next update
    Serial.println("Waiting 15 mins...");
    for (int t = 1; t <= 15; t++) {
      delay(60000); // 60k mS = 1 minute
    }

    if (client.connect()) {
      //Serial.println("Reconnected");
      client.println("GET /marketbear.xml HTTP/1.0");    
      client.println();
      delay(2000);
    } else {
      Serial.println("Reconnect failed");
    }      
  }
}

// Process each char from web
void serialEvent() {

   // Read a char
	char inChar = client.read();
   //Serial.print(".");
  
   if (inChar == '<') {          // Character is the beginning of a tag
      addChar(inChar, tmpStr);   // Add the current char to the end of tmpStr
      tagFlag = true;            // Set the tag flag to true
      dataFlag = false;          // Set the data flag to fales

   } else if (inChar == '>') {   // Character is the end of the tag
      addChar(inChar, tmpStr);   // Add the current character to the end of tmpStr

      if (tagFlag) {                                  // If this *is* a tag,
         strncpy(tagStr, tmpStr, strlen(tmpStr)+1);   // dump the contents of tmpStr into tagStr
      }

      // Clear tmp
      clearStr(tmpStr);

      tagFlag = false;
      dataFlag = true;    // Must be the start of the data itself            
      
   } else if (inChar != 10) {  // if the char ISN'T a linefeed...
      if (tagFlag) {
         // Add tag char to string
         addChar(inChar, tmpStr);

         // Check for </XML> end tag, ignore it
         if ( tagFlag && strcmp(tmpStr, endTag) == 0 ) {
            clearStr(tmpStr);		// clear out tmpStr
            tagFlag = false;		// set both tagFlag and dataFlag
            dataFlag = false;		// to false
         }
      }
      
      if (dataFlag) {				// if this is data, then
         addChar(inChar, dataStr);	// add the char to dataStr
      }
   }  
  
   // If a LF, process the line
   if (inChar == 10 ) {

/*////////////////////////////////
//
//	This is where the magic goes
//
/////////////////////////////////*/

      Serial.print("tagStr: ");
      Serial.println(tagStr);
      Serial.print("dataStr: ");
      Serial.println(dataStr);

      // Find specific tags and print data
      if (matchTag("<temp_f>")) {
	      Serial.print("Temp: ");
         Serial.print(dataStr);
      }
      if (matchTag("<relative_humidity>")) {
	      Serial.print(", Humidity: ");
         Serial.print(dataStr);
      }
      if (matchTag("<pressure_in>")) {
	      Serial.print(", Pressure: ");
         Serial.print(dataStr);
         Serial.println("");
      }

      // Clear all strings
      clearStr(tmpStr);
      clearStr(tagStr);
      clearStr(dataStr);

      // Clear Flags
      tagFlag = false;
      dataFlag = false;
   }
}

/////////////////////
// Other Functions //
/////////////////////

// Function to clear a string
void clearStr (char* str) {
   int len = strlen(str);
   for (int c = 0; c < len; c++) {
      str[c] = 0;
   }
}

//Function to add a char to a string and check its length
void addChar (char ch, char* str) {
   char *tagMsg  = "<TRUNCATED_TAG>";
   char *dataMsg = "-TRUNCATED_DATA-";

   // Check the max size of the string to make sure it doesn't grow too
   // big.  If string is beyond MAX_STRING_LEN assume it is unimportant
   // and replace it with a warning message.
   if (strlen(str) > MAX_STRING_LEN - 2) {
      if (tagFlag) {
         clearStr(tagStr);
         strcpy(tagStr,tagMsg);
      }
      if (dataFlag) {
         clearStr(dataStr);
         strcpy(dataStr,dataMsg);
      }

      // Clear the temp buffer and flags to stop current processing
      clearStr(tmpStr);
      tagFlag = false;
      dataFlag = false;

   } else {
      // Add char to string
      str[strlen(str)] = ch;
   }
}

// Function to check the current tag for a specific string
boolean matchTag (char* searchTag) {
   if ( strcmp(tagStr, searchTag) == 0 ) {
      return true;
   } else {
      return false;
   }
}
