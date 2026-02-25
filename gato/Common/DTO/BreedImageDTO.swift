//
//  BreedImageDTO.swift
//  gato
//
//  Created by José Miguel Figueiredo on 25/02/2026.
//

import Foundation

struct BreedImageDTO: Decodable {
    struct BreedReferenceDTO: Decodable {
        let id: String
    }

    let url: URL?
    let breeds: [BreedReferenceDTO]?
}
