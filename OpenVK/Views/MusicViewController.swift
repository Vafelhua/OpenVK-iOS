import UIKit
import AVFoundation

extension Notification.Name {
    /// Состояние общего плеера изменилось (трек, пауза, прогресс).
    static let openVKMusicDidChange = Notification.Name("OpenVKMusicDidChange")
}

/// Глобальный проигрыватель музыки.
///
/// Живёт всё время работы приложения, поэтому трек продолжает играть при
/// переходе между вкладками и в фоне (`UIBackgroundModes: audio` в Info.plist).
/// Экран «Музыка» и мини-плеер над таб-баром лишь управляют этим объектом,
/// а не владеют воспроизведением — иначе при уходе с экрана трек обрывался.
final class MusicPlayer {
    static let shared = MusicPlayer()

    private let player = AVPlayer()
    private(set) var queue: [VKAudio] = []
    private(set) var currentIndex = -1
    private(set) var isPlaying = false
    private(set) var progress: Float = 0
    private(set) var timeText: String?

    private var timeControlObserver: NSKeyValueObservation?
    private var itemStatusObserver: NSKeyValueObservation?
    private var durationObserver: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var progressTimer: Timer?

    var currentTrack: VKAudio? {
        guard queue.indices.contains(currentIndex) else { return nil }
        return queue[currentIndex]
    }

    private init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)

        // Состояние кнопки меняется асинхронно, поэтому опрашивать
        // `timeControlStatus` сразу после `play()` бессмысленно.
        timeControlObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isPlaying = (self.player.timeControlStatus == .playing)
                self.notify()
            }
        }
    }

    // MARK: - Управление

    func play(track: VKAudio, in list: [VKAudio]) {
        queue = list.isEmpty ? [track] : list
        currentIndex = queue.firstIndex { $0.id == track.id && $0.ownerId == track.ownerId } ?? 0
        startCurrent()
    }

    func toggle() {
        guard currentTrack != nil else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            if let item = player.currentItem, item.duration.isNumeric,
               CMTimeGetSeconds(item.duration) > 0,
               CMTimeGetSeconds(player.currentTime()) >= CMTimeGetSeconds(item.duration) - 0.5 {
                player.seek(to: .zero)
            }
            player.play()
        }
        // Состояние кнопки обновит наблюдатель timeControlStatus.
    }

    func next() {
        guard queue.isEmpty == false else { return }
        currentIndex = (currentIndex + 1) % queue.count
        startCurrent()
    }

    func previous() {
        guard queue.isEmpty == false else { return }
        // Если трек проигран больше трёх секунд — начинаем его заново.
        if CMTimeGetSeconds(player.currentTime()) > 3 {
            player.seek(to: .zero)
            return
        }
        currentIndex = (currentIndex - 1 + queue.count) % queue.count
        startCurrent()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        queue = []
        currentIndex = -1
        progress = 0
        timeText = nil
        stopTimer()
        notify()
    }

    // MARK: - Воспроизведение трека

    private func startCurrent() {
        guard let track = currentTrack else { return }
        guard let url = streamURL(for: track) else {
            presentUnavailable("Сервер не вернул ссылку на трек.")
            return
        }

        let item = AVPlayerItem(url: url)
        // Если поток недоступен, AVPlayerItem молча падает в .failed —
        // без этой проверки трек просто не играл бы без объяснения.
        itemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] observed, _ in
            guard observed.status == .failed else { return }
            DispatchQueue.main.async {
                self?.presentUnavailable(observed.error?.localizedDescription ?? "Не удалось загрузить трек.")
            }
        }
        durationObserver = item.observe(\.duration, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.notify() }
        }

        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                             object: item,
                                                             queue: .main) { [weak self] _ in
            self?.next()
        }

        player.replaceCurrentItem(with: item)
        player.play()
        startTimer()
        notify()
    }

    private func streamURL(for track: VKAudio) -> URL? {
        guard track.url.isEmpty == false, let url = URL(string: track.url) else { return nil }
        guard let token = LocalSettings.shared.token, token.isEmpty == false,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var query = components.queryItems ?? []
        query.append(URLQueryItem(name: "access_token", value: token))
        components.queryItems = query
        return components.url ?? url
    }

    private func presentUnavailable(_ message: String) {
        // Глобальный плеер не знает текущий экран — показываем alert у корня.
        let alert = UIFactory.alert(title: "Недоступно", message: message)
        guard let window = UIApplication.shared.keyWindow,
              let root = window.rootViewController else { return }
        if root.presentedViewController == nil {
            root.present(alert, animated: true)
        }
    }

    // MARK: - Прогресс

    private func startTimer() {
        stopTimer()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
        tick()
    }

    private func stopTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func tick() {
        refreshProgress()
        notify()
    }

    private func refreshProgress() {
        guard let duration = player.currentItem?.duration, duration.isNumeric else {
            progress = 0
            timeText = nil
            return
        }
        let total = CMTimeGetSeconds(duration)
        guard total > 0 else {
            progress = 0
            timeText = nil
            return
        }
        let current = max(0, CMTimeGetSeconds(player.currentTime()))
        progress = Float(min(max(current / total, 0), 1))
        timeText = String(format: "%d:%02d / %d:%02d",
                          Int(current) / 60, Int(current) % 60,
                          Int(total) / 60, Int(total) % 60)
    }

    private func notify() {
        NotificationCenter.default.post(name: .openVKMusicDidChange, object: nil)
    }
}

/// Мини-плеер над таб-баром: название трека слева, управление справа.
/// Хостится в `MainTabBarController`, поэтому виден из любой вкладки.
final class MiniPlayerBar: UIView {
    static let height: CGFloat = 54

    /// Открыть полноэкранный экран музыки по тапу на названии.
    var onOpen: (() -> Void)?

    private let topLine = UIView()
    private let titleLabel = UIFactory.label("", size: 14, weight: .semibold, lines: 1)
    private let artistLabel = UIFactory.label("", size: 12, color: Theme.textSecondary, lines: 1)
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let playButton = UIButton(type: .system)
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: .openVKMusicDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme),
                                               name: .openVKThemeDidChange, object: nil)
        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Theme.card
        clipsToBounds = true

        topLine.translatesAutoresizingMaskIntoConstraints = false
        topLine.backgroundColor = Theme.divider

        titleLabel.isUserInteractionEnabled = true
        titleLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openTapped)))

        progressView.trackTintColor = Theme.divider
        progressView.progressTintColor = Theme.accent
        progressView.translatesAutoresizingMaskIntoConstraints = false

        prevButton.setImage(UIFactory.icon("⏮", size: 18), for: .normal)
        prevButton.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        nextButton.setImage(UIFactory.icon("⏭", size: 18), for: .normal)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)

        for button in [prevButton, playButton, nextButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
        }

        addSubview(topLine)
        addSubview(titleLabel)
        addSubview(artistLabel)
        addSubview(progressView)
        addSubview(nextButton)
        addSubview(playButton)
        addSubview(prevButton)

        NSLayoutConstraint.activate([
            topLine.topAnchor.constraint(equalTo: topAnchor),
            topLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            topLine.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            nextButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 38),
            nextButton.heightAnchor.constraint(equalToConstant: 40),

            playButton.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor, constant: -2),
            playButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 44),
            playButton.heightAnchor.constraint(equalToConstant: 44),

            prevButton.trailingAnchor.constraint(equalTo: playButton.leadingAnchor, constant: -2),
            prevButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: 38),
            prevButton.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: prevButton.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),

            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.trailingAnchor.constraint(lessThanOrEqualTo: prevButton.leadingAnchor, constant: -8),
            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),

            progressView.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressView.bottomAnchor.constraint(equalTo: bottomAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])

        applyTheme()
    }

    @objc private func refresh() {
        guard let track = MusicPlayer.shared.currentTrack else { return }
        titleLabel.text = track.title.isEmpty ? track.displayName : track.title
        artistLabel.text = track.artistText
        let glyph = MusicPlayer.shared.isPlaying ? "❙❙" : "▶"
        playButton.setImage(UIFactory.icon(glyph, size: 20), for: .normal)
        progressView.progress = MusicPlayer.shared.progress
    }

    @objc func applyTheme() {
        backgroundColor = Theme.card
        topLine.backgroundColor = Theme.divider
        titleLabel.textColor = Theme.textPrimary
        artistLabel.textColor = Theme.textSecondary
        progressView.trackTintColor = Theme.divider
        progressView.progressTintColor = Theme.accent
        for button in [prevButton, playButton, nextButton] {
            button.tintColor = Theme.accent
        }
    }

    @objc private func playTapped() { MusicPlayer.shared.toggle() }
    @objc private func nextTapped() { MusicPlayer.shared.next() }
    @objc private func prevTapped() { MusicPlayer.shared.previous() }
    @objc private func openTapped() { onOpen?() }
}

/// Музыка: библиотека (`audio.get`), поиск (`audio.search`), воспроизведение
/// через общий `MusicPlayer`.
final class MusicViewController: TableScreenController, UISearchBarDelegate {
    private var tracks: [VKAudio] = []
    private var searchBar: UISearchBar?
    private var highlightedId: Int?

    override var itemsCount: Int { return tracks.count }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh,
                                                            target: self,
                                                            action: #selector(refreshTapped))

        let bar = UISearchBar()
        bar.delegate = self
        bar.placeholder = "Поиск музыки"
        bar.searchBarStyle = .minimal
        bar.sizeToFit()
        table.tableHeaderView = bar
        searchBar = bar

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(musicDidChange),
                                               name: .openVKMusicDidChange,
                                               object: nil)
        load()
    }

    /// Подсвечиваем строку только когда сменился трек: прогресс обновляется
    /// каждую секунду и полная перезагрузка таблицы на каждый тик лишняя.
    @objc private func musicDidChange() {
        let id = MusicPlayer.shared.currentTrack?.id
        guard id != highlightedId else { return }
        highlightedId = id
        reload()
    }

    // MARK: - Данные

    @objc private func refreshTapped() {
        load()
    }

    override func load() {
        setLoading(tracks.isEmpty)
        showStatus(nil)

        VKApiClient.shared.call("audio.get", ["count": "100"]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                switch result {
                case .success(let value):
                    self.tracks = VKAudio.readList(value)
                    self.showStatus(self.tracks.isEmpty ? "Музыкальной библиотеки нет" : nil)
                    self.reload()
                case .failure(let error):
                    self.showError(error)
                }
            }
        }
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        runSearch(searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchDebounce?.cancel()
        performSearch((searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Отложенный старт поиска: без паузы каждый символ порождал запрос.
    private var searchDebounce: DispatchWorkItem?
    private var searchGeneration = 0

    private func runSearch(_ query: String) {
        searchDebounce?.cancel()
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else {
            searchGeneration += 1
            VKApiClient.shared.cancel("music.search")
            load()
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.performSearch(text) }
        searchDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func performSearch(_ text: String) {
        searchGeneration += 1
        let generation = searchGeneration
        setLoading(tracks.isEmpty)
        VKApiClient.shared.call("audio.search",
                                ["q": text, "count": "50"],
                                cancelKey: "music.search") { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.searchGeneration == generation else { return }
                self.setLoading(false)
                switch result {
                case .success(let value):
                    self.tracks = VKAudio.readList(value)
                    self.showStatus(self.tracks.isEmpty ? "Ничего не найдено" : nil)
                    self.reload()
                case .failure(let error):
                    self.showError(error)
                }
            }
        }
    }

    // MARK: - Таблица

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tracks.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let track = tracks[safe: indexPath.row],
            let cell = dequeueCell(MemberCell.self,
                                   identifier: MemberCell.reuseId,
                                   at: indexPath) else { return UITableViewCell() }
        cell.configure(title: track.displayName, subtitle: track.durationText, photo: nil)
        cell.setPlaying(track.id == MusicPlayer.shared.currentTrack?.id)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        table.deselectRow(at: indexPath, animated: true)
        guard let track = tracks[safe: indexPath.row] else { return }
        MusicPlayer.shared.play(track: track, in: tracks)
        (table.cellForRow(at: indexPath) as? MemberCell)?.setPlaying(true)
    }

    override func reload() {
        table.reloadData()
    }
}
