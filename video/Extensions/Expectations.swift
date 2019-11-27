//
//  Expectations.swift
//  video
//
//  Created by Bogdan Pashchenko on 27.11.2019.
//  Copyright © 2019 Alexey Voronov. All rights reserved.
//

func expectationFail() { assertionFailure() }

func expect(_ condition: Bool) { assert(condition) }
