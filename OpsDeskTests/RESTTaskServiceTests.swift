import Foundation
import Testing
@testable import OpsDesk

nonisolated private let todosJSON = """
[{"userId":7,"id":42,"title":"Inspect cooling","completed":false},
 {"userId":99,"id":43,"title":"Check power","completed":true}]
"""
nonisolated private let usersJSON = """
[{"id":7,"name":"Alex Lee","username":"alex","email":"alex@example.com"}]
"""

nonisolated private func response(for url: URL, status: Int = 200, body: String) -> (Data, URLResponse) {
    (Data(body.utf8), HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!)
}

struct RESTTaskServiceTests {
    @Test
    func fetchesBothEndpointsAndAssociatesUsers() async throws {
        let service = RESTTaskService { url in
            #expect(url.scheme == "https")
            #expect(url.host == "jsonplaceholder.typicode.com")
            #expect(["/todos", "/users"].contains(url.path))
            return response(for: url, body: url.path == "/todos" ? todosJSON : usersJSON)
        }
        let tasks = try await service.fetchTasks()
        #expect(tasks == [
            OperationalTask(id: 42, title: "Inspect cooling", completed: false,
                            user: .init(id: 7, name: "Alex Lee", username: "alex", email: "alex@example.com")),
            OperationalTask(id: 43, title: "Check power", completed: true, user: nil)
        ])
    }

    @Test(arguments: ["/todos", "/users"])
    func rejectsHTTPFailureBeforeDecoding(path: String) async {
        let service = RESTTaskService { url in
            response(for: url, status: url.path == path ? 503 : 200,
                     body: url.path == path ? "Service unavailable" : (url.path == "/todos" ? todosJSON : usersJSON))
        }
        do {
            _ = try await service.fetchTasks()
            Issue.record("Expected an HTTP failure")
        } catch {
            // A status error must not be misreported as malformed JSON.
            #expect((error as? TaskNetworkError) == .httpStatus(503))
        }
    }

    @Test(arguments: ["/todos", "/users"])
    func rejectsMalformedJSON(path: String) async {
        let service = RESTTaskService { url in
            response(for: url, body: url.path == path ? "invalid" : (url.path == "/todos" ? todosJSON : usersJSON))
        }
        do {
            _ = try await service.fetchTasks()
            Issue.record("Expected a decoding failure")
        } catch {
            #expect(error is DecodingError)
        }
    }

    @Test
    func propagatesOfflineFailure() async {
        let service = RESTTaskService { _ in throw URLError(.notConnectedToInternet) }
        do {
            _ = try await service.fetchTasks()
            Issue.record("Expected a transport failure")
        } catch {
            #expect((error as? URLError)?.code == .notConnectedToInternet)
        }
    }

    @Test
    func propagatesCancellation() async {
        let service = RESTTaskService { _ in throw CancellationError() }
        do {
            _ = try await service.fetchTasks()
            Issue.record("Expected cancellation")
        } catch {
            #expect(error is CancellationError)
        }
    }

    @Test
    func rejectsNonHTTPResponse() async {
        let service = RESTTaskService { url in
            (Data("[]".utf8), URLResponse(url: url, mimeType: nil, expectedContentLength: 2, textEncodingName: nil))
        }
        do {
            _ = try await service.fetchTasks()
            Issue.record("Expected an invalid response failure")
        } catch {
            #expect((error as? TaskNetworkError) == .invalidResponse)
        }
    }

    @Test
    func acceptsEmptyResponses() async throws {
        let service = RESTTaskService { url in response(for: url, body: "[]") }
        #expect(try await service.fetchTasks().isEmpty)
    }
}
