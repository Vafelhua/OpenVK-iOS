import UIKit
import AVFoundation

/// Музыка: библиотека (`audio.get`), поиск (`audio.search`), проигрывание через AVPlayer.
final class MusicViewController: TableScreenController, UISearchBarDelegate {
    private var tracks: [VKAudio] = []
    private var searchBar: UISearchBar?

    private let playerBar = UIView()
    private let playerTitle = UIFactory.label("", size: 14, weight: .semibold)
    private let playButton = UIButton(type: .system)
    private var playerHeight: NSLayoutConstraint!
    private var playerBottom: NSLayoutConstraint!

    private let player = AVPlayer()
    private var currentTrack: VKAudio?

    /// Наблюдатели AVPlayer: `timeControlStatus` меняется асинхронно,
    /// поэтому опрашивать его сразу после `play()` бессмысленно —
    /// кнопка «зависала» в состоянии «пауза».
    private var timeControlObserver: NSKeyValueObservation?
    private var itemStatusObserver: NSKeyValueObservation?
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var progressTimer: Timer?

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

        buildPlayerBar()
        configureAudioSession()
        observePlayer()
        load()
    }

    deinit {
        stopObservingPlayer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Не останавливаем музыку при переходе на другой экран —
        // иначе сворачивание приложения прерывало трек.
    }

    private func observePlayer() {
        stopObservingPlayer()
        timeControlObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updatePlayButton() }
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerItemEnded),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: nil)
    }

    private func stopObservingPlayer() {
        timeControlObserver = nil
        itemStatusObserver = nil
        statusObservation = nil
        progressTimer?.invalidate()
        progressTimer = nil
        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    /// По завершении трека показываем ▶ вместо «паузы» на остановленном плеере.
    @objc private func playerItemEnded() {
        updatePlayButton()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    // MARK: - Плеер

    private func buildPlayerBar() {
        playerBar.translatesAutoresizingMaskIntoConstraints = false
        playerBar.backgroundColor = Theme.card

        let topLine = UIView()
        topLine.backgroundColor = Theme.divider
        topLine.translatesAutoresizingMaskIntoConstraints = false

        playButton.setImage(UIFactory.icon("▶", size: 20), for: .normal)
        playButton.tintColor = Theme.accent
        playButton.addTarget(self, action: #selector(togglePlayback), for: .touchUpInside)
        playButton.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = UIButton(type: .system)
        closeButton.setTitle("✕", for: .normal)
        closeButton.tintColor = Theme.textSecondary
        closeButton.addTarget(self, action: #selector(closePlayer), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(playerBar)
        playerBar.addSubview(topLine)
        playerBar.addSubview(playerTitle)
        playerBar.addSubview(playButton)
        playerBar.addSubview(closeButton)

        playerHeight = playerBar.heightAnchor.constraint(equalToConstant: 0)
        playerBottom = playerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)

        NSLayoutConstraint.activate([
            playerBottom,
            playerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerHeight,

            topLine.topAnchor.constraint(equalTo: playerBar.topAnchor),
            topLine.leadingAnchor.constraint(equalTo: playerBar.leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: playerBar.trailingAnchor),
            topLine.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            playerTitle.leadingAnchor.constraint(equalTo: playerBar.leadingAnchor, constant: 14),
            playerTitle.centerYAnchor.constraint(equalTo: playerBar.centerYAnchor),
            playerTitle.trailingAnchor.constraint(lessThanOrEqualTo: playButton.leadingAnchor, constant: -10),

            playButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -6),
            playButton.centerYAnchor.constraint(equalTo: playerBar.centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 44),
            playButton.heightAnchor.constraint(equalToConstant: 44),

            closeButton.trailingAnchor.constraint(equalTo: playerBar.trailingAnchor, constant: -10),
            closeButton.centerYAnchor.constraint(equalTo: playerBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 30)
        ])

        pinTableBottom(to: playerBar.topAnchor)
    }

    private func showPlayer(for track: VKAudio) {
        currentTrack = track
        playerTitle.text = track.displayName
        playerHeight.constant = 54

        guard var urlString = track.url as String?, let url = URL(string: urlString) else {
            presentAlert(title: "Недоступно", message: "Сервер не вернул ссылку на трек.")
            return
        }
        if let token = LocalSettings.shared.token, token.isEmpty == false,
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            var query = components.queryItems ?? []
            query.append(URLQueryItem(name: "access_token", value: token))
            components.queryItems = query
            urlString = components.url?.absoluteString ?? urlString
        }

        guard let finalURL = URL(string: urlString) else { return }

        let item = AVPlayerItem(url: finalURL)
        // Если поток недоступен, AVPlayerItem молча падает в .failed —
        // без этой проверки трек просто не играл без объяснения.
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] observed, _ in
            guard observed.status == .failed else { return }
            let message = observed.error?.localizedDescription ?? "Не удалось загрузить трек."
            DispatchQueue.main.async {
                self?.playButton.isEnabled = false
                self?.presentAlert(title: "Недоступно", message: message)
            }
        }
        itemStatusObserver = item.observe(\.duration, options: [.new]) { [weak self] observed, _ in
            DispatchQueue.main.async { self?.applyDuration(observed.duration) }
        }

        player.replaceCurrentItem(with: item)
        player.play()
        updatePlayButton()
        startProgressTimer()
    }

    @objc private func togglePlayback() {
        guard currentTrack != nil else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            // Досматриваем трек с начала, если он уже закончился.
            if let item = player.currentItem, item.duration.isNumeric,
               CMTimeGetSeconds(item.duration) > 0,
               CMTimeGetSeconds(player.currentTime()) >= CMTimeGetSeconds(item.duration) - 0.5 {
                player.seek(to: .zero)
            }
            player.play()
        }
        // Состояние кнопки обновит наблюдатель timeControlStatus.
    }

    private func updatePlayButton() {
        let playing = player.timeControlStatus == .playing
        let glyph = playing ? "❙❙" : "▶"
        playButton.setImage(UIFactory.icon(glyph, size: 18), for: .normal)
        playButton.tintColor = Theme.accent
        playButton.setTitle(playerTimeText(), for: .normal)
        playButton.titleLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        playButton.setTitleColor(Theme.textSecondary, for: .normal)
    }

    private func playerTimeText() -> String? {
        guard let duration = player.currentItem?.duration, duration.isNumeric else { return nil }
        let total = Int(CMTimeGetSeconds(duration))
        guard total > 0 else { return nil }
        let current = Int(max(0, CMTimeGetSeconds(player.currentTime())))
        return String(format: "%d:%02d / %d:%02d", current / 60, current % 60, total / 60, total % 60)
    }

    private func applyDuration(_ duration: CMTime) {
        guard duration.isNumeric, CMTimeGetSeconds(duration) > 0 else { return }
        guard playerTimeText() == nil else { return }
        let total = Int(CMTimeGetSeconds(duration))
        updatePlayButton()
        playerTitle.text = currentTrack.map { "\($0.displayName) · \(total / 60):\(String(format: "%02d", total % 60))" }
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        // Тик раз в секунду только на время показа панели плеера.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.updatePlayButton() }
        }
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
    }

    @objc private func closePlayer() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentTrack = nil
        playerTitle.text = nil
        playerHeight.constant = 0
        statusObservation = nil
        itemStatusObserver = nil
        progressTimer?.invalidate()
        progressTimer = nil
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
        let track = tracks[indexPath.row]
        let cell = table.dequeueReusableCell(withIdentifier: MemberCell.reuseId, for: indexPath) as! MemberCell
        cell.configure(title: track.displayName, subtitle: track.durationText, photo: nil)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        table.deselectRow(at: indexPath, animated: true)
        showPlayer(for: tracks[indexPath.row])
    }

    override func reload() {
        table.reloadData()
    }

    override func applyTheme() {
        super.applyTheme()
        playerBar.backgroundColor = Theme.card
        playerTitle.textColor = Theme.textPrimary
        playButton.tintColor = Theme.accent
    }
}