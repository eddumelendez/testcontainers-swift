//
//  Docker.swift
//
//
//  Created by cristian on 6/08/24.
//

import Foundation
import AsyncHTTPClient
import NIOHTTP1
import Combine

protocol DockerClientProtocol {
    func send<T: Testcontainers.Request>(request: T, completion: @escaping (Result<T.Response, Error>) -> Void)
    func send<T: Testcontainers.Request>(_ request: T) -> AnyPublisher<T.Response, Error>
}

extension HTTPClient: DockerClientProtocol {
    
    func send<T: Testcontainers.Request>(request: T, completion: @escaping (Result<T.Response, Error>) -> Void) {
        HTTPClient.shared.execute(request: request.make(), delegate: HTTPClientResponse())
            .futureResult
            .whenComplete
        { result in
            switch result {
            case let .success(data):
                do {
                    let response = try request.decode(data)
                    completion(.success(response))
                } catch {
                    completion(.failure(error))
                }
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
    
    func send<T: Testcontainers.Request>(_ request: T) -> AnyPublisher<T.Response, Error> {
        Future { promise in
            self.send(request: request) { result in
                switch result {
                case .success(let response):
                    promise(.success(response))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

final class Docker {
    
    let client: DockerClientProtocol
    
    init(client: DockerClientProtocol) {
        self.client = client
    }
    
    func pull(image name: String) -> AnyPublisher<Docker.Image, Error> {
        let request = Docker.Image.Request.Create(fromImage: name)
        return client.send(request)
            .map { Docker.Image(name: name, client: self.client) }
            .eraseToAnyPublisher()
    }
        
    func create(container configuration: ContainerConfig) -> AnyPublisher<Docker.Container, Error> {
        let request = Docker.Container.Request.Create(configuration: configuration)
        return client.send(request)
            .map { Docker.Container(id: $0.Id, client: self.client) }
            .eraseToAnyPublisher()
    }
}

extension Docker.Container {
    enum Request { }
}

extension Docker.Image {
    enum Request { }
}
