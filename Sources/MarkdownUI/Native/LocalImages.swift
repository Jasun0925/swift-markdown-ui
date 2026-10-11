#if os(macOS)
  import AppKit

  /// Images a document names by path, read from one folder on disk.
  ///
  /// A document from a model can name any path, so only files inside
  /// `directory` are read: the path is resolved, symbolic links included,
  /// and must still be under the folder. Only image types are read, up to
  /// `maxBytes`. Web images are never fetched; they stay as their alt text.
  enum LocalImages {
    static let maxBytes = 20 * 1024 * 1024
    static let extensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "tif", "bmp", "svg"]

    private final class Box {
      let image: NSImage?
      let modified: Date?
      init(_ image: NSImage?, modified: Date?) { self.image = image; self.modified = modified }
    }
    private static let cache = NSCache<NSURL, Box>()

    /// The file `source` names inside `directory`, or `nil` when it names
    /// the web, another folder, or something that is not an image.
    static func file(for source: String, in directory: URL) -> URL? {
      let trimmed = source.trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty else { return nil }
      let candidate: URL
      if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), scheme.count > 1 {
        // `C:` style drive letters aside, a scheme other than file is the web.
        guard scheme == "file" else { return nil }
        candidate = url
      } else {
        let path = trimmed.removingPercentEncoding ?? trimmed
        let expanded = (path as NSString).expandingTildeInPath
        candidate = expanded.hasPrefix("/")
          ? URL(fileURLWithPath: expanded) : directory.appendingPathComponent(expanded)
      }
      let root = directory.standardizedFileURL.resolvingSymlinksInPath().path
      let resolved = candidate.standardizedFileURL.resolvingSymlinksInPath()
      guard resolved.path == root || resolved.path.hasPrefix(root.hasSuffix("/") ? root : root + "/") else {
        return nil
      }
      guard extensions.contains(resolved.pathExtension.lowercased()) else { return nil }
      return resolved
    }

    /// The image at `file`, read once and again only when the file changes.
    static func image(at file: URL) -> NSImage? {
      let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey])
      guard values?.isRegularFile == true, let size = values?.fileSize, size > 0, size <= maxBytes else {
        return nil
      }
      let modified = values?.contentModificationDate
      if let hit = cache.object(forKey: file as NSURL), hit.modified == modified { return hit.image }
      let image = NSImage(contentsOf: file).flatMap { $0.size.width > 0 && $0.size.height > 0 ? $0 : nil }
      cache.setObject(Box(image, modified: modified), forKey: file as NSURL)
      return image
    }

    /// Display size: the image's own size in points, no wider than `width`.
    static func displaySize(of image: NSImage, maxWidth width: CGFloat) -> CGSize {
      let size = image.size
      guard size.width > width, width > 0 else { return size }
      return CGSize(width: width, height: (size.height * width / size.width).rounded())
    }
  }
#endif
