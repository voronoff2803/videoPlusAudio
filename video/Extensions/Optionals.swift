//
//  Optionals.swift
//  video
//
//  Created by Bogdan Pashchenko on 27.11.2019.
//  Copyright © 2019 Alexey Voronov. All rights reserved.
//

extension Optional {
    var valOrExpFail: Wrapped? {
        expect(self != nil)
        return self
    }
}
