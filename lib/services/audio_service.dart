import 'dart:io';

import 'package:audio_manager/audio_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:flutter_ffmpeg/media_information.dart';
import 'package:mozika/model/database/db_sqlite.dart';
import 'package:mozika/model/entity/audio_model.dart';
import 'package:mozika/model/interface/audio_custom_info.dart';
import 'package:mozika/utils/audio_utils.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';

class AudioService {
  final String storagePath = "/storage/emulated/0/";
  final List<String> excludePath = [
    "/storage/emulated/0/Android",
    "/storage/emulated/0/Sound",
    "/storage/emulated/0/."
  ];

  /// Search all audio in storage
  Future _searchAudioFile() async {
    Directory? dir = await getExternalStorageDirectory();
    List<FileSystemEntity>? allMusics = [];

    if (dir != null) {
      await Permission.storage.request();
      Directory? parent = dir.parent.parent.parent.parent;
      List<FileSystemEntity>? files =
          parent.listSync(recursive: true, followLinks: false);

      for (FileSystemEntity file in files) {
        bool skip = false;

        for (String path in excludePath) {
          if (file.path.startsWith(path)) {
            skip = true;
            break;
          }
        }

        if (skip) continue;

        if (file.path.endsWith(".m4a") || file.path.endsWith(".mp3")) {
          allMusics.add(file);
        }
      }
    }

    return allMusics;
  }

  /// Create a audio file and add into
  /// audiomanager instance
  Future getAllAudioFiles() async {
    List<FileSystemEntity> allMusics = await _searchAudioFile();

    List audio = [];

    for (FileSystemEntity file in allMusics) {
      AudioInfo audioInfo = AudioInfo(file.uri.toString(),
          title: file.path,
          desc: "hira",
          coverUrl: "assets/images/photo1.jpeg");
      audio.add(audioInfo.toJson());

      AudioManager.instance.audioList.add(audioInfo);
    }

    return audio;
  }

  /// Save one audio file in database
  /// Manipulate audio file to get parent
  /// Get audio name without extension
  Future<int> saveAudioFileInDb(
      {required String filePath, required String uri}) async {
    File file = File(filePath);
    final String parent =
        file.parent.path.replaceAll(RegExp(r'\/storage\/emulated\/0\/'), '');
    final String name = basenameWithoutExtension(file.path);

    Audio audio = Audio(name: name, folder: parent, uriPath: uri);
    final db = await DatabaseInstance.createInstance();
    return await db.insert('audio', audio.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Map all audio file and save in database
  Future<void> saveAllAudioInDatabase() async {
    List allAudio = await AudioUtils().getAllAudioFiles();

    for (var audioInfo in allAudio) {
      await saveAudioFileInDb(
          filePath: audioInfo['title'], uri: audioInfo['url']);
    }
  }

  /// Get all audio file in database
  /// Sqlite Query
  /// Create a list to Audio Model
  /// Add all audio in AudioManager
  Future<List<Audio>> getAllAudioFromDb() async {
    final db = await DatabaseInstance.createInstance();

    final List<Map<String, dynamic>> data = await db.query('audio');

    final List<Audio> allAudio = List.generate(
        data.length,
        (i) => Audio(
            id: data[i]['id'],
            name: data[i]['name'],
            folder: data[i]['folder'],
            uriPath: data[i]['uri_path']));

    AudioManager.instance.audioList.clear();

    for (Audio file in allAudio) {
      AudioInfo audioInfo = AudioInfo(file.uriPath,
          title: file.name,
          desc: file.folder,
          coverUrl: "assets/images/photo1.jpeg");

      AudioManager.instance.audioList.add(audioInfo);
    }

    return allAudio;
  }

  /// Play music in audio manager
  static void playMusicInAudioManager(
      {required String uri, required String name}) {
    AudioManager.instance.file(File(uri), name,
        desc: "", cover: 'assets/images/photo1.jpeg', auto: true);
  }

  /// Format audio duration
  static String formatAudioDuration(Duration d) {
    if (d == null) return "--:--";

    int minute = d.inMinutes;
    int second = (d.inSeconds > 60) ? (d.inSeconds % 60) : d.inSeconds;
    String format = ((minute < 10) ? "0$minute" : "$minute") +
        ":" +
        ((second < 10) ? "0$second" : "$second");
    return format;
  }

  static Future<AudioCustomInfo> getAudioInformation(String uriPath) async {
    final FlutterFFprobe _flutterFFprobe = new FlutterFFprobe();
    MediaInformation info = await _flutterFFprobe.getMediaInformation(uriPath);
    // print(info.getMediaProperties());
    return AudioCustomInfo(
        artist: info.getMediaProperties()?['tags']?['artist'],
        duration: info.getMediaProperties()?['duration'],
        title: info.getMediaProperties()?['tags']?['title']);
  }
}
