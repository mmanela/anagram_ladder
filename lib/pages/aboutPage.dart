import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("About")),
        body: SafeArea(child: _aboutBody(context)));
  }

  Widget _aboutBody(BuildContext context) {
    final textScaleFactor = min(1.4, MediaQuery.of(context).textScaleFactor);
    return Markdown(
        onTapLink: (String text, String? href, String title) async {
          if (href != null) {
            await launch(href);
          }
        },
        styleSheet: MarkdownStyleSheet(
            textScaleFactor: textScaleFactor,
            p: TextStyle(fontSize: 20),
            h2: TextStyle(fontSize: 24)),
        data: '''## What is Anagram Ladder?
Anagram Ladder is a __challenging__ word game for those who love to unscramble big words. 
The game tasks you to solve a word ladder by unscrambling progressively longer words.
Each time you solve one new letters appear on the end of the previous word
 until you get to the max length for your difficulty level.
` `  
` `
## Difficulty Levels
With increasingly long scrambled words, the game offers a range of difficulty levels. 
The most difficult requires unscrambling a 10-letter word (very difficult)
Each ladder is unique which means a 10-letter difficulty ladder will not contain
the final word from any 6-letter difficulty ladder. This allows the harder levels to feel fresh and new.
` `  
` `
## This is hard!?!?
Yes, this is hard. Especially when you play the higher difficulties you may only
partially finish some ladders and need to leave them half done. That is ok! We save 
your progress and you can always go back and try again (or use hints).
` `  
` `
## How do hints work?
In each rung of the word ladder you can ask for hints. For every 
possible word in that rung you can reveal both the first and the last letter.
` `  
` `
## Why did a rung complete on its own?
Sometimes luck is on your side. If by chance the next letters revealed
make a word it will mark it correct and move on.
This is a good thing and consider it an early birthday present!
` `  
` `
## Who created this game?
Anagram Ladder was created by [Matthew Manela](https://matthewmanela.com) as a fun project to learn
how to make a word game on mobile devices. If you have questions or feedback please send emails
to [AnagramLadder@gmail.com](mailto:AnagramLadder@gmail.com?subject=Feedback).
    ''');
  }
}
