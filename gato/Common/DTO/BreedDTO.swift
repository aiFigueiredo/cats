//
//  BreedDTO.swift
//  gato
//
//  Created by José Miguel Figueiredo on 25/02/2026.
//

import Foundation

struct BreedDTO: Decodable {
    struct ImageDTO: Decodable {
        let url: URL?
    }

    let id: String
    let name: String
    let origin: String?
    let temperament: String?
    let description: String?
    let lifeSpan: String?
    let image: ImageDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case origin
        case temperament
        case description
        case lifeSpan = "life_span"
        case image
    }

    func toDomain() -> Breed {
        Breed(
            id: id,
            name: name,
            origin: origin,
            temperament: temperament,
            description: description,
            lifeSpan: LifeSpanRange(rawValue: lifeSpan),
            imageURL: image?.url,
            isFavorite: false
        )
    }
}
