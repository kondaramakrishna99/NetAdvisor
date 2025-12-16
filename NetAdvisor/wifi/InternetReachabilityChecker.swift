//
//  InternetReachabilityChecker.swift
//  NetAdvisor
//
//  Created by Rama Krishna Konda on 16/12/25.
//

import Foundation

final class InternetReachabilityChecker {

    private let testURL = URL(string: "https://www.apple.com/library/test/success.html")!
    private let timeout: TimeInterval = 5

    func check(completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: testURL)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }
}
