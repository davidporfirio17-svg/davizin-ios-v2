import Foundation
import UIKit

final class StorageService {
    static let shared = StorageService()

    private let fileManager = FileManager.default

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var projectsURL: URL {
        documentsURL.appendingPathComponent("projects")
    }

    private var indexURL: URL {
        documentsURL.appendingPathComponent("index.json")
    }

    private init() {
        try? fileManager.createDirectory(at: projectsURL, withIntermediateDirectories: true)
    }

    // MARK: - Projects

    func loadProjects() -> [ShaderProject] {
        guard let data = try? Data(contentsOf: indexURL),
              let projects = try? JSONDecoder().decode([ShaderProject].self, from: data)
        else { return [] }
        return projects.sorted { $0.created > $1.created }
    }

    func saveProjects(_ projects: [ShaderProject]) {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    func addProject(_ project: ShaderProject) {
        var projects = loadProjects()
        projects.insert(project, at: 0)
        saveProjects(projects)
    }

    func updateProject(_ project: ShaderProject) {
        var projects = loadProjects()
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = project
            saveProjects(projects)
        }
    }

    func deleteProject(_ project: ShaderProject) {
        var projects = loadProjects()
        projects.removeAll { $0.id == project.id }
        saveProjects(projects)
        let dir = projectMediaDir(for: project.id)
        try? fileManager.removeItem(at: dir)
    }

    // MARK: - Media

    func projectMediaDir(for id: UUID) -> URL {
        let dir = projectsURL.appendingPathComponent(id.uuidString)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func saveMedia(data: Data, fileName: String, projectId: UUID) -> String {
        let dir = projectMediaDir(for: projectId)
        let url = dir.appendingPathComponent(fileName)
        try? data.write(to: url, options: .atomic)
        return fileName
    }

    func mediaURL(fileName: String, projectId: UUID) -> URL {
        projectMediaDir(for: projectId).appendingPathComponent(fileName)
    }

    func loadMediaImage(fileName: String, projectId: UUID) -> UIImage? {
        let url = mediaURL(fileName: fileName, projectId: projectId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
