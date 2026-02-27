//
//  ScenePresets.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Built-in scene presets — everyday scenarios that require natural delivery.

import Foundation

enum ScenePresets {

    static let all: [ActingScene] = [
        ActingScene(
            title: "Morning Coffee",
            situation: "You're at a cafe, ordering your usual morning coffee and chatting with the barista.",
            role: "Customer",
            lines: [
                "Hi, can I get a large iced americano please?",
                "Oh wait, actually it's freezing outside. Let me switch that to a hot one.",
                "And do you still have those blueberry muffins? I'll take one of those too.",
                "You know what, make it two. My coworker's been having a rough week.",
                "Perfect, thank you so much. Keep the change.",
                "Oh hey, I love what you guys did with the place by the way. The new seats look great.",
                "Alright, I'll grab a seat by the window. Thanks again!"
            ]
        ),
        ActingScene(
            title: "Calling in Sick",
            situation: "You're calling your boss early in the morning to say you can't come in today.",
            role: "Employee",
            lines: [
                "Hey, good morning. Sorry to call so early.",
                "I don't think I'm gonna be able to make it in today.",
                "I woke up with this terrible headache and my throat is killing me.",
                "I think it might be that thing going around the office lately.",
                "I already told Sarah she can cover the afternoon meeting for me.",
                "I'll try to rest up and be back by tomorrow if I'm feeling better.",
                "Again, really sorry about the short notice. I'll check my email if anything urgent comes up.",
                "Thanks for understanding. I really appreciate it."
            ]
        ),
        ActingScene(
            title: "Running Late",
            situation: "You show up 20 minutes late to meet a friend at a restaurant.",
            role: "The Late Friend",
            lines: [
                "Oh my god, I am so sorry. The traffic was absolutely insane.",
                "I left the house on time, I swear, but then there was this accident on the highway.",
                "Have you been waiting long? I feel terrible.",
                "I should've just taken the subway honestly.",
                "Let me buy you dinner to make up for it. No, seriously, I insist.",
                "Anyway, how have you been? It feels like I haven't seen you in forever."
            ]
        ),
        ActingScene(
            title: "Funny Story",
            situation: "You're telling a friend about something ridiculous that happened to you yesterday.",
            role: "Storyteller",
            lines: [
                "Okay so you are not gonna believe what happened to me yesterday.",
                "I was at the grocery store, minding my own business, picking out avocados.",
                "And this guy just walks up and cuts right in front of me in line.",
                "So I'm standing there like, do I say something? Do I just let it go?",
                "I ended up just standing there. Didn't say a word. Just stared at him.",
                "And then he turns around and goes, oh sorry, I didn't see you there. Like, how?",
                "I swear, the most random things always happen to me at that store.",
                "I told my mom about it and she could not stop laughing.",
                "Honestly I'm still thinking about it. I should've said something, right?"
            ]
        ),
        ActingScene(
            title: "Giving Directions",
            situation: "A tourist asks you for directions and you try to help them out.",
            role: "Local",
            lines: [
                "Oh, the train station? Yeah, it's not too far from here actually.",
                "So what you wanna do is go straight down this road for about two blocks.",
                "Then you're gonna see a big intersection with a coffee shop on the corner.",
                "Take a left there, and then just keep walking for like five minutes.",
                "You'll see the station right in front of you. You really can't miss it.",
                "If you hit the park, you've gone too far. But honestly it's pretty easy to find.",
                "Oh and there's a shortcut through that alley over there, but it's kind of confusing.",
                "Yeah, just stick to the main road. You'll be fine."
            ]
        ),
        ActingScene(
            title: "Weekend Plans",
            situation: "Your friend asks what you did over the weekend.",
            role: "You",
            lines: [
                "Honestly? I did absolutely nothing this weekend and it was amazing.",
                "I just stayed home, watched a bunch of movies, ordered some pizza.",
                "Oh actually, I did go for a walk on Sunday morning. The weather was really nice.",
                "I found this little bookstore I'd never seen before. It was so cozy in there.",
                "The owner recommended me this one novel and we ended up talking for like twenty minutes.",
                "I ended up buying like three books even though I haven't finished the last one.",
                "Then I grabbed some coffee on the way home and just read on the couch all afternoon.",
                "But yeah, nothing crazy. Sometimes you just need a chill weekend, you know?",
                "What about you? Did you do anything fun?",
                "We should hang out next weekend though. I've been wanting to try that new ramen place."
            ]
        )
    ]
}
