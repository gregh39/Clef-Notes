//
//  DataExporter.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/26/25.
//

import Foundation
import CoreData

class DataExporter {
    
    func exportStudentToCSV(student: StudentCD) -> URL? {
        let fileName = "\(student.name ?? "Student")_Export.csv"
        let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        var csvText = "Session Date,Session Title,Duration (min),Song,Plays\n"
        
        for session in student.sessionsArray {
            let date = session.day?.formatted(.dateTime.year().month().day()) ?? "N/A"
            let title = session.title ?? "Practice"
            let duration = session.durationMinutes
            
            if session.playsArray.isEmpty {
                csvText.append("\(date),\(title),\(duration),,\n")
            } else {
                for play in session.playsArray {
                    let songTitle = play.song?.title ?? "N/A"
                    let plays = play.count
                    csvText.append("\(date),\(title),\(duration),\(songTitle),\(plays)\n")
                }
            }
        }
        
        do {
            try csvText.write(to: path!, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("Failed to create file: \(error)")
            return nil
        }
    }
}
