import 'package:azan/models/reciter_model.dart';
import 'package:azan/services/quran_api_service.dart';
import 'package:azan/utils/helpers/colors_manager.dart';
import 'package:azan/utils/helpers/hive_manager.dart';
import 'package:azan/utils/helpers/quran_data.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class SurahReaderScreen extends StatefulWidget {
  final SurahItem surah;
  final ReciterModel? initialReciter;

  const SurahReaderScreen({
    super.key,
    required this.surah,
    this.initialReciter,
  });

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  late Future<List<QuranAyah>> _versesFuture;
  late ReciterModel _selectedReciter;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isLocallyCached = false;
  bool _showTranslation = true;
  bool _showTransliteration = false;

  // Audio Playback State
  String? _currentlyPlayingKey; // e.g. "surah" for full surah or "ayah_1" for verse 1
  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _selectedReciter = widget.initialReciter ?? availableReciters.first;
    _isLocallyCached = HiveManager.isSurahCached(widget.surah.traditionalOrder);
    _loadVerses();
    _initAudioListeners();
  }

  void _initAudioListeners() {
    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _currentlyPlayingKey = null;
          _isPlaying = false;
          _currentPosition = Duration.zero;
        }
      });
    });

    _audioPlayer.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() {
        _currentPosition = pos;
      });
    });

    _audioPlayer.durationStream.listen((dur) {
      if (!mounted) return;
      if (dur != null) {
        setState(() {
          _totalDuration = dur;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _loadVerses() {
    setState(() {
      _versesFuture = QuranApiService.getSurahVerses(widget.surah.traditionalOrder).then((verses) {
        if (mounted) {
          setState(() {
            _isLocallyCached = true;
          });
        }
        return verses;
      });
    });
  }

  Future<void> _playFullSurah() async {
    final audioKey = 'surah_${widget.surah.traditionalOrder}';

    if (_currentlyPlayingKey == audioKey && _isPlaying) {
      await _audioPlayer.pause();
      return;
    }

    if (_currentlyPlayingKey == audioKey && !_isPlaying) {
      await _audioPlayer.play();
      return;
    }

    setState(() {
      _currentlyPlayingKey = audioKey;
      _isLoadingAudio = true;
    });

    try {
      final url = _selectedReciter.getFullSurahAudioUrl(widget.surah.traditionalOrder);
      await _audioPlayer.stop();
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play Surah audio: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
        });
      }
    }
  }

  Future<void> _playVerse(QuranAyah ayah) async {
    final audioKey = 'ayah_${ayah.ayah}';

    if (_currentlyPlayingKey == audioKey && _isPlaying) {
      await _audioPlayer.pause();
      return;
    }

    if (_currentlyPlayingKey == audioKey && !_isPlaying) {
      await _audioPlayer.play();
      return;
    }

    setState(() {
      _currentlyPlayingKey = audioKey;
      _isLoadingAudio = true;
    });

    try {
      final url = _selectedReciter.getAyahAudioUrl(widget.surah.traditionalOrder, ayah.ayah);
      await _audioPlayer.stop();
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play Ayah audio: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
        });
      }
    }
  }

  void _showReciterSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          color: Color(0xFF242422),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Audio Reciter',
              style: TextStyle(
                color: ColorsManager.primaryGold,
                fontSize: 20,
                fontFamily: 'serif',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Audio will stream from the selected reciter',
              style: TextStyle(color: ColorsManager.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: availableReciters.length,
                separatorBuilder: (ctx, idx) => Divider(
                  color: Colors.white.withValues(alpha: 0.06),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final reciter = availableReciters[index];
                  final isSelected = reciter.id == _selectedReciter.id;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    onTap: () async {
                      final wasPlaying = _isPlaying;
                      final currentKey = _currentlyPlayingKey;
                      await _audioPlayer.stop();

                      setState(() {
                        _selectedReciter = reciter;
                        _currentlyPlayingKey = null;
                        _isPlaying = false;
                      });

                      await HiveManager.addUpdateMetaData('selected_reciter_id', reciter.id);
                      if (ctx.mounted) Navigator.pop(ctx);

                      // If was playing full surah, resume with new reciter
                      if (wasPlaying && currentKey == 'surah_${widget.surah.traditionalOrder}') {
                        _playFullSurah();
                      }
                    },
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isSelected ? ColorsManager.primaryGold : ColorsManager.textMuted,
                      size: 20,
                    ),
                    title: Text(
                      reciter.name,
                      style: TextStyle(
                        color: isSelected ? ColorsManager.primaryGoldLight : ColorsManager.textPrimary,
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(
                      reciter.style,
                      style: const TextStyle(color: ColorsManager.textMuted, fontSize: 11),
                    ),
                    trailing: Text(
                      reciter.nameArabic,
                      style: TextStyle(
                        color: isSelected ? ColorsManager.primaryGold : ColorsManager.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191A19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF222220),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: ColorsManager.primaryGold, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              widget.surah.name,
              style: const TextStyle(
                color: ColorsManager.textPrimary,
                fontSize: 18,
                fontFamily: 'serif',
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.surah.numberOfVerses} Verses • ${widget.surah.location}',
                  style: const TextStyle(color: ColorsManager.textMuted, fontSize: 11),
                ),
                if (_isLocallyCached) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 10),
                        SizedBox(width: 3),
                        Text('Cached', style: TextStyle(color: Colors.green, fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.mic, color: ColorsManager.primaryGold),
            tooltip: 'Change Reciter',
            onPressed: _showReciterSelector,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: ColorsManager.primaryGold),
            color: const Color(0xFF2C2C2A),
            onSelected: (val) {
              setState(() {
                if (val == 'translation') _showTranslation = !_showTranslation;
                if (val == 'transliteration') _showTransliteration = !_showTransliteration;
                if (val == 'reciter') _showReciterSelector();
              });
            },
            itemBuilder: (ctx) => [
              CheckedPopupMenuItem(
                value: 'translation',
                checked: _showTranslation,
                child: const Text('Translation', style: TextStyle(color: ColorsManager.textPrimary)),
              ),
              CheckedPopupMenuItem(
                value: 'transliteration',
                checked: _showTransliteration,
                child: const Text('Transliteration', style: TextStyle(color: ColorsManager.textPrimary)),
              ),
              const PopupMenuItem(
                value: 'reciter',
                child: Text('Change Reciter', style: TextStyle(color: ColorsManager.primaryGold)),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<QuranAyah>>(
        future: _versesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: ColorsManager.primaryGold),
                  const SizedBox(height: 18),
                  Text(
                    _isLocallyCached ? 'Loading from cache...' : 'Retrieving Surah from API (one-time)...',
                    style: const TextStyle(color: ColorsManager.textMuted, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to load Surah',
                      style: TextStyle(color: ColorsManager.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ColorsManager.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: ColorsManager.primaryGoldDark),
                      onPressed: _loadVerses,
                      child: const Text('Retry', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          }

          final verses = snapshot.data ?? [];

          return Column(
            children: [
              // Scrollable Verses List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: verses.length + 1, // +1 for the Surah header banner
                  separatorBuilder: (ctx, idx) => Divider(
                    color: Colors.white.withValues(alpha: 0.08),
                    height: 28,
                  ),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildSurahBanner();
                    }

                    final ayah = verses[index - 1];
                    return _buildAyahItem(ayah);
                  },
                ),
              ),

              // Bottom Full-Surah Audio Player Bar
              _buildBottomAudioPlayerBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSurahBanner() {
    final showBismillah = widget.surah.traditionalOrder != 9 && widget.surah.traditionalOrder != 1;
    final isPlayingFullSurah = _currentlyPlayingKey == 'surah_${widget.surah.traditionalOrder}' && _isPlaying;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF282826),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPlayingFullSurah
              ? ColorsManager.primaryGold
              : ColorsManager.primaryGold.withValues(alpha: 0.35),
          width: isPlayingFullSurah ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          if (isPlayingFullSurah)
            BoxShadow(
              color: ColorsManager.primaryGold.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.surah.arabicName,
            style: const TextStyle(
              color: ColorsManager.primaryGoldLight,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Surah ${widget.surah.name}',
            style: const TextStyle(
              color: ColorsManager.textPrimary,
              fontSize: 18,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.surah.location} • ${widget.surah.numberOfVerses} Verses • Revelation #${widget.surah.chronologicalOrder}',
            style: const TextStyle(color: ColorsManager.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),

          // Play Full Surah Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isPlayingFullSurah ? ColorsManager.primaryGoldDark : const Color(0xFF333330),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            icon: Icon(
              isPlayingFullSurah ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: ColorsManager.primaryGold,
              size: 22,
            ),
            label: Text(
              isPlayingFullSurah ? 'Playing Full Surah' : 'Play Full Surah (${_selectedReciter.name})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            onPressed: _playFullSurah,
          ),

          if (showBismillah) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF20201E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: ColorsManager.primaryGold,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAyahItem(QuranAyah ayah) {
    final isThisAyahPlaying = _currentlyPlayingKey == 'ayah_${ayah.ayah}' && _isPlaying;
    final isThisAyahLoading = _currentlyPlayingKey == 'ayah_${ayah.ayah}' && _isLoadingAudio;

    return Container(
      padding: isThisAyahPlaying ? const EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: isThisAyahPlaying
          ? BoxDecoration(
              color: ColorsManager.primaryGold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorsManager.primaryGold.withValues(alpha: 0.3)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ayah Header Row: Number Badge, Key, and Verse Play Audio Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isThisAyahPlaying ? ColorsManager.primaryGold : const Color(0xFF282826),
                      border: Border.all(
                        color: ColorsManager.primaryGold.withValues(alpha: 0.5),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${ayah.ayah}',
                      style: TextStyle(
                        color: isThisAyahPlaying ? const Color(0xFF191A19) : ColorsManager.primaryGold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ayah.verseKey,
                    style: const TextStyle(color: ColorsManager.textMuted, fontSize: 11),
                  ),
                ],
              ),

              // Verse Audio Play Button
              InkWell(
                onTap: () => _playVerse(ayah),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isThisAyahPlaying
                        ? ColorsManager.primaryGold
                        : const Color(0xFF282826),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: ColorsManager.primaryGold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isThisAyahLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: ColorsManager.primaryGold),
                        )
                      else
                        Icon(
                          isThisAyahPlaying ? Icons.pause : Icons.play_arrow,
                          color: isThisAyahPlaying ? const Color(0xFF191A19) : ColorsManager.primaryGold,
                          size: 16,
                        ),
                      const SizedBox(width: 4),
                      Text(
                        isThisAyahPlaying ? 'Playing' : 'Audio',
                        style: TextStyle(
                          color: isThisAyahPlaying ? const Color(0xFF191A19) : ColorsManager.primaryGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Arabic Verse Text
          Text(
            ayah.arabic,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: ColorsManager.textPrimary,
              fontSize: 24,
              height: 1.8,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Transliteration
          if (_showTransliteration && ayah.transliteration.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              ayah.transliteration,
              style: TextStyle(
                color: ColorsManager.primaryGoldLight.withValues(alpha: 0.8),
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],

          // English Translation
          if (_showTranslation && ayah.translation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              ayah.translation,
              style: const TextStyle(
                color: ColorsManager.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomAudioPlayerBar() {
    if (_currentlyPlayingKey == null) {
      return const SizedBox.shrink();
    }

    final isSurah = _currentlyPlayingKey!.startsWith('surah');
    final title = isSurah ? 'Playing Surah ${widget.surah.name}' : 'Playing Ayah ${_currentlyPlayingKey!.replaceAll('ayah_', '')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF242422),
        border: Border(
          top: BorderSide(color: ColorsManager.primaryGold.withValues(alpha: 0.3)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: ColorsManager.primaryGoldLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _selectedReciter.name,
                        style: const TextStyle(color: ColorsManager.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        color: ColorsManager.primaryGold,
                        size: 32,
                      ),
                      onPressed: () {
                        if (_isPlaying) {
                          _audioPlayer.pause();
                        } else {
                          _audioPlayer.play();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop_circle_outlined, color: ColorsManager.textMuted, size: 26),
                      onPressed: () {
                        _audioPlayer.stop();
                        setState(() {
                          _currentlyPlayingKey = null;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            if (_totalDuration.inSeconds > 0) ...[
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  trackHeight: 3,
                  activeTrackColor: ColorsManager.primaryGold,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                  thumbColor: ColorsManager.primaryGold,
                ),
                child: Slider(
                  value: _currentPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds).toDouble(),
                  max: _totalDuration.inMilliseconds.toDouble(),
                  onChanged: (val) {
                    _audioPlayer.seek(Duration(milliseconds: val.toInt()));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_currentPosition), style: const TextStyle(color: ColorsManager.textMuted, fontSize: 10)),
                    Text(_formatDuration(_totalDuration), style: const TextStyle(color: ColorsManager.textMuted, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
