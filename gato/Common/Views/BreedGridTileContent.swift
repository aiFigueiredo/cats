//
//  BreedGridTileContent.swift
//  gato
//
//  Created by José Miguel Figueiredo on 25/02/2026.
//

import SwiftUI

struct BreedGridTileContent: View, Equatable {
    let breed: Breed
    let imageClient: ImageClient
    let onFavorite: (() -> Void)?

    static func == (lhs: BreedGridTileContent, rhs: BreedGridTileContent) -> Bool {
        lhs.breed == rhs.breed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color(.systemGray6)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    GeometryReader { proxy in
                        RemoteImageView(url: breed.imageURL, imageClient: imageClient) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "cat.fill")
                                .resizable()
                                .scaledToFit()
                                .padding(10)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: proxy.size.width, height: proxy.size.width)
                    }
                }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(breed.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            if let onFavorite {
                Button {
                    onFavorite()
                } label: {
                    Image(systemName: breed.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(.yellow)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel(breed.isFavorite ? "Remove \(breed.name) from favorites" : "Add \(breed.name) to favorites")
                .accessibilityIdentifier("favorite_\(breed.id)")
            }
        }
    }
}
