//
//  MenuButtonTip.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/27/25.
//


import Foundation
import TipKit

// This tip will point to the main menu button in the navigation bar.
struct MenuButtonTip: Tip {
    var title: Text {
        Text("Main Menu")
    }

    var message: Text? {
        Text("Tap here to switch students, access tools like the metronome and tuner, and manage your account.")
    }

    var image: Image? {
        Image(systemName: "ellipsis.circle")
    }
}

struct NewSongButtonTip: Tip {
    var title: Text {
        Text("Add a new song")
    }

    var message: Text? {
        Text("Tap here to add a new song the student is working on.")
    }

    var image: Image? {
        Image("add.song")
    }
}

import TipKit

struct AddPlaySheetTip: Tip {
    var title: Text {
        Text("Add New Session Play")
    }

    var message: Text? {
        Text("Select the song played below or add a new song with the Add Song button above. Then, verify the play type and save!")
    }

    var image: Image? {
        Image(systemName: "music.quarternote.3")
    }
}
