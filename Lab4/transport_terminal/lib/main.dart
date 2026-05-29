import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'package:pn532_cli/pn532_cli.dart';

void main() {
  runApp(const TransportTerminalApp());
}

class TransportTerminalApp extends StatelessWidget {
  const TransportTerminalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Transport Terminal',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: const Color(0xFF050816),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF22C55E),
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0B1120),
          labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
          helperStyle: const TextStyle(color: Color(0xFF64748B)),
          hintStyle: const TextStyle(color: Color(0xFF64748B)),
          prefixIconColor: const Color(0xFF38BDF8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1E293B)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1E293B)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF22C55E), width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: const Color(0xFF04130A),
            disabledBackgroundColor: const Color(0xFF1E293B),
            disabledForegroundColor: const Color(0xFF64748B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF22C55E);
            }
            return const Color(0xFF94A3B8);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF14532D);
            }
            return const Color(0xFF1E293B);
          }),
        ),
      ),
      home: const PaymentPage(),
    );
  }
}

class LibNfcScanResult {
  const LibNfcScanResult({
    required this.found,
    this.uidHex,
    this.uidCompactHex,
    this.atqaHex,
    this.sakHex,
    this.message,
    this.error,
  });

  final bool found;
  final String? uidHex;
  final String? uidCompactHex;
  final String? atqaHex;
  final String? sakHex;
  final String? message;
  final String? error;

  factory LibNfcScanResult.fromMap(Map<dynamic, dynamic> map) {
    return LibNfcScanResult(
      found: map['found'] == true,
      uidHex: map['uidHex'] as String?,
      uidCompactHex: map['uidCompactHex'] as String?,
      atqaHex: map['atqaHex'] as String?,
      sakHex: map['sakHex'] as String?,
      message: map['message'] as String?,
      error: map['error'] as String?,
    );
  }
}

class _BackendCard {
  const _BackendCard({
    required this.id,
    required this.cardNo,
    required this.balance,
    required this.blocked,
    required this.ownerName,
    required this.keyId,
  });

  final int id;
  final String cardNo;
  final int balance;
  final bool blocked;
  final String ownerName;
  final int keyId;

  factory _BackendCard.fromJson(Map<String, dynamic> json) {
    return _BackendCard(
      id: _asInt(json['id']) ?? 0,
      cardNo: (json['card_no'] ?? json['card_number'] ?? '').toString(),
      balance: _asInt(json['balance']) ?? 0,
      blocked: json['blocked'] == true || json['is_blocked'] == true,
      ownerName: (json['owner_name'] ?? '').toString(),
      keyId: _asInt(json['key_id']) ?? 1,
    );
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class _NfcCommandResult {
  const _NfcCommandResult({
    required this.executable,
    required this.exitCode,
    required this.stdoutText,
    required this.stderrText,
  });

  final String executable;
  final int exitCode;
  final String stdoutText;
  final String stderrText;

  String get fullOutput {
    final parts = <String>[];
    if (stdoutText.trim().isNotEmpty) {
      parts.add(stdoutText.trim());
    }
    if (stderrText.trim().isNotEmpty) {
      parts.add(stderrText.trim());
    }
    return parts.join('\n');
  }
}

class _PhysicalCardDump {
  const _PhysicalCardDump({
    required this.directory,
    required this.dumpPath,
    required this.bytes,
    required this.commandOutput,
  });

  final Directory directory;
  final String dumpPath;
  final List<int> bytes;
  final String commandOutput;
}

class _PhysicalCardBalance {
  const _PhysicalCardBalance({
    required this.dump,
    required this.balance,
    required this.rawText,
  });

  final _PhysicalCardDump dump;
  final int balance;
  final String rawText;
}

class _PhysicalWriteResult {
  const _PhysicalWriteResult({
    required this.newBalance,
    required this.newDumpPath,
    required this.commandOutput,
  });

  final int newBalance;
  final String newDumpPath;
  final String commandOutput;
}

void libNfcScanIsolateEntry(List<dynamic> args) {
  final sendPort = args[0] as SendPort;
  final connstring = args[1] as String;
  final timeoutSeconds = args[2] as int;

  final reader = LibNfcReader(connstring: connstring);
  final stopwatch = Stopwatch()..start();

  try {
    reader.open();

    while (stopwatch.elapsed < Duration(seconds: timeoutSeconds)) {
      final card = reader.scanOneCard();

      if (card != null) {
        sendPort.send({
          'found': true,
          'uidHex': card.uidHex,
          'uidCompactHex': card.uidCompactHex,
          'atqaHex': card.atqaHex,
          'sakHex': card.sakHex,
        });
        return;
      }

      sleep(const Duration(milliseconds: 200));
    }

    sendPort.send({
      'found': false,
      'message': 'Card not found before timeout.',
    });
  } catch (e) {
    sendPort.send({'found': false, 'error': e.toString()});
  } finally {
    try {
      reader.close();
    } catch (_) {
      // Ignore close errors.
    }
  }
}

Future<LibNfcScanResult> runLibNfcScanInIsolate({
  required String connstring,
  required int timeoutSeconds,
}) async {
  final receivePort = ReceivePort();

  await Isolate.spawn(libNfcScanIsolateEntry, [
    receivePort.sendPort,
    connstring,
    timeoutSeconds,
  ]);

  final message = await receivePort.first;
  receivePort.close();

  if (message is Map) {
    return LibNfcScanResult.fromMap(message);
  }

  return LibNfcScanResult(
    found: false,
    error: 'Unexpected isolate response: $message',
  );
}

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  static const Color _bg = Color(0xFF050816);
  static const Color _panel = Color(0xFF0B1120);
  static const Color _panelSoft = Color(0xFF111827);
  static const Color _border = Color(0xFF1E293B);
  static const Color _green = Color(0xFF22C55E);
  static const Color _cyan = Color(0xFF38BDF8);
  static const Color _red = Color(0xFFFB7185);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _text = Color(0xFFE5E7EB);
  static const Color _muted = Color(0xFF94A3B8);

  final apiBaseController = TextEditingController(
    text: 'https://localhost:8888/api/v1',
  );

  final terminalController = TextEditingController(text: 'TERM-001');
  final cardController = TextEditingController(text: 'b754105e');
  final amountController = TextEditingController(text: '65');

  final ownerNameController = TextEditingController(text: 'Test Passenger');
  final initialBalanceController = TextEditingController(text: '500');
  final keyIdController = TextEditingController(text: '1');

  final connstringController = TextEditingController(
    text: 'pn532_uart:/dev/cu.usbserial-0001',
  );

  bool loadingPayment = false;
  bool loadingCreateCard = false;
  bool loadingPhysicalCard = false;
  bool scanning = false;
  bool isBlocked = false;
  bool usePhysicalCardBalance = true;

  String paymentResultText = '';
  String createCardResultText = '';
  String scanResultText = '';
  String physicalCardResultText = '';

  int? lastPhysicalBalance;
  bool? approved;

  late final IOClient client;

  @override
  void initState() {
    super.initState();

    final httpClient = HttpClient()
      ..badCertificateCallback = (certificate, host, port) {
        return host == 'localhost' || host == '127.0.0.1';
      };

    client = IOClient(httpClient);

    terminalController.addListener(_refreshHeader);
    cardController.addListener(_refreshHeader);
    amountController.addListener(_refreshHeader);
  }

  void _refreshHeader() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    terminalController.removeListener(_refreshHeader);
    cardController.removeListener(_refreshHeader);
    amountController.removeListener(_refreshHeader);

    apiBaseController.dispose();
    terminalController.dispose();
    cardController.dispose();
    amountController.dispose();
    ownerNameController.dispose();
    initialBalanceController.dispose();
    keyIdController.dispose();
    connstringController.dispose();
    client.close();
    super.dispose();
  }

  Future<void> scanCard() async {
    setState(() {
      scanning = true;
      scanResultText = 'Opening libnfc reader...\nWaiting for card...';
      approved = null;
    });

    try {
      final connstring = connstringController.text.trim();

      if (connstring.isEmpty) {
        throw Exception('libnfc connstring is required');
      }

      final result = await runLibNfcScanInIsolate(
        connstring: connstring,
        timeoutSeconds: 10,
      );

      if (!mounted) {
        return;
      }

      if (result.error != null) {
        setState(() {
          scanResultText = 'Scan error: ${result.error}';
        });
        return;
      }

      if (!result.found) {
        setState(() {
          scanResultText =
              '''
Card not found.

Timeout: 10 seconds
${result.message ?? ''}
''';
        });
        return;
      }

      final uidCompact = result.uidCompactHex;

      if (uidCompact == null || uidCompact.isEmpty) {
        throw Exception('libnfc returned empty UID compact');
      }

      setState(() {
        cardController.text = uidCompact;
        scanResultText =
            '''
Card found via libnfc.

UID: ${result.uidHex}
UID compact: ${result.uidCompactHex}
ATQA: ${result.atqaHex}
SAK: ${result.sakHex}
''';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        scanResultText = 'Scan error: $e';
      });
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        scanning = false;
      });
    }
  }


  Future<void> scanAndAuthorizePayment() async {
    setState(() {
      scanning = true;
      loadingPayment = true;
      scanResultText = 'Opening libnfc reader...\nWaiting for card to pay...';
      paymentResultText = '';
      physicalCardResultText = usePhysicalCardBalance
          ? 'Положи карту на PN532 и держи её до конца операции.\nСначала читаю UID, потом BAL из блока 4, потом списываю.'
          : physicalCardResultText;
      approved = null;
    });

    try {
      final apiBase = trimRightSlash(apiBaseController.text.trim());
      final terminalSerial = terminalController.text.trim();
      final amount = int.tryParse(amountController.text.trim());
      final connstring = connstringController.text.trim();

      if (apiBase.isEmpty) {
        throw Exception('API base URL is required');
      }

      if (terminalSerial.isEmpty) {
        throw Exception('Terminal serial is required');
      }

      if (amount == null || amount <= 0) {
        throw Exception('Amount must be a positive integer');
      }

      if (connstring.isEmpty) {
        throw Exception('libnfc connstring is required');
      }

      _PhysicalCardBalance? physicalBefore;
      late final String uidCompact;

      if (usePhysicalCardBalance) {
        setState(() {
          scanResultText =
              'Физический режим включён.\n'
              'Не открываю PN532 отдельным сканером, чтобы порт не был занят.\n'
              'Сразу читаю MIFARE Classic dump через nfc-mfclassic...';
          physicalCardResultText =
              'Положи карту на PN532 и держи её до конца операции.\n'
              'Сейчас читаю UID и BAL из физической карты...';
        });

        final physicalRead = await _readPhysicalCardBalance(connstring);
        physicalBefore = physicalRead;
        uidCompact = _uidCompactFromClassicDump(physicalRead.dump.bytes);
        final uidPretty = _uidPrettyFromClassicDump(physicalRead.dump.bytes);

        if (physicalRead.balance < amount) {
          throw Exception(
            'Недостаточно денег на физической карте.\n'
            'На карте: ${physicalRead.balance}\n'
            'Нужно списать: $amount',
          );
        }

        if (!mounted) {
          return;
        }

        setState(() {
          cardController.text = uidCompact;
          scanResultText =
              'Card found via nfc-mfclassic dump.\n\n'
              'UID: $uidPretty\n'
              'UID compact: $uidCompact';
          lastPhysicalBalance = physicalRead.balance;
          physicalCardResultText =
              'Физический BAL прочитан.\n\n'
              'UID: $uidCompact\n'
              'Block 4: ${physicalRead.rawText}\n'
              'До списания: ${physicalRead.balance}\n'
              'Сумма списания: $amount\n\n'
              'Держи карту на PN532.\n'
              'Теперь отправляю операцию в backend...';
        });
      } else {
        final result = await runLibNfcScanInIsolate(
          connstring: connstring,
          timeoutSeconds: 10,
        );

        if (!mounted) {
          return;
        }

        if (result.error != null) {
          throw Exception('Scan error: ${result.error}');
        }

        if (!result.found) {
          throw Exception('Card not found before timeout. ${result.message ?? ''}');
        }

        final scannedUid = result.uidCompactHex;
        if (scannedUid == null || scannedUid.isEmpty) {
          throw Exception('libnfc returned empty UID compact');
        }
        uidCompact = scannedUid;

        setState(() {
          cardController.text = uidCompact;
          scanResultText =
              """
Card found via libnfc.

UID: ${result.uidHex}
UID compact: ${result.uidCompactHex}
ATQA: ${result.atqaHex}
SAK: ${result.sakHex}
""";
        });
      }

      final token = await login(apiBase);
      var backendSyncMessage = '';

      if (usePhysicalCardBalance && physicalBefore != null) {
        final physicalBalanceBefore = physicalBefore.balance;

        setState(() {
          physicalCardResultText =
              'Физический BAL прочитан: $physicalBalanceBefore.\n\n'
              'Теперь синхронизирую backend с физической картой, чтобы списание шло именно от BAL:$physicalBalanceBefore, а не от старого значения в БД...';
        });

        backendSyncMessage = await _syncBackendCardBalance(
          apiBase: apiBase,
          token: token,
          cardNo: uidCompact.toLowerCase(),
          physicalBalance: physicalBalanceBefore,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          physicalCardResultText =
              '$backendSyncMessage\n\n'
              'Держи карту на PN532. Теперь отправляю оплату в backend...';
        });
      }

      final response = await client.post(
        Uri.parse('$apiBase/terminal/transactions/authorize'),
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer $token',
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.acceptHeader: 'application/json',
        },
        body: jsonEncode({
          'terminal_serial': terminalSerial,
          'card_number': uidCompact.toLowerCase(),
          'amount': amount,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final isApproved = json['approved'] == true;

      _PhysicalWriteResult? physicalWrite;
      int? newPhysicalBalance;

      if (usePhysicalCardBalance && physicalBefore != null && isApproved) {
        final physical = physicalBefore;
        newPhysicalBalance =
            _jsonInt(json, 'balance_after') ?? physical.balance - amount;

        setState(() {
          physicalCardResultText =
              'Backend подтвердил оплату.\n\n'
              'Держи карту на PN532.\n'
              'Записываю новый BAL:$newPhysicalBalance в block 4...';
        });

        physicalWrite = await _writePhysicalCardBalance(
          connstring: connstring,
          sourceDump: physical.dump,
          newBalance: newPhysicalBalance,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        approved = isApproved;
        paymentResultText = const JsonEncoder.withIndent('  ').convert(json);

        if (usePhysicalCardBalance && physicalBefore != null) {
          if (isApproved && physicalWrite != null) {
            lastPhysicalBalance = physicalWrite.newBalance;
            physicalCardResultText =
                'Готово. Деньги списаны и в backend, и на физической карте.\n\n'
                'UID: $uidCompact\n'
                'Было на карте: ${physicalBefore!.balance}\n'
                'Списано: $amount\n'
                'Стало на карте: ${physicalWrite.newBalance}\n\n'
                'Block 4 теперь: BAL:${physicalWrite.newBalance}\n\n'
                '$backendSyncMessage\n\n'
                'В React нажми «Обновить всё», чтобы увидеть новую транзакцию.';
          } else {
            physicalCardResultText =
                'Backend не подтвердил оплату.\n'
                'Физическая карта не изменялась.\n\n'
                'Было на карте: ${physicalBefore!.balance}';
          }
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        approved = false;
        paymentResultText = 'Error: $e';
        if (usePhysicalCardBalance) {
          physicalCardResultText =
              'Операция остановлена.\n\n'
              '$e\n\n'
              'Если видишь «no tag was found», положи карту на PN532 до нажатия кнопки и держи до конца.';
        }
      });
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        scanning = false;
        loadingPayment = false;
      });
    }
  }

  Future<_NfcCommandResult> _runNfcMfclassic(
    String connstring,
    List<String> args,
  ) async {
    final executables = <String>[
      'nfc-mfclassic',
      '/opt/homebrew/bin/nfc-mfclassic',
      '/usr/local/bin/nfc-mfclassic',
    ];

    Object? lastError;

    for (final executable in executables) {
      try {
        final result = await Process.run(
          executable,
          args,
          environment: {'LIBNFC_DEFAULT_DEVICE': connstring},
          includeParentEnvironment: true,
        );

        final commandResult = _NfcCommandResult(
          executable: executable,
          exitCode: result.exitCode,
          stdoutText: result.stdout.toString(),
          stderrText: result.stderr.toString(),
        );

        if (result.exitCode == 0) {
          return commandResult;
        }

        throw Exception(
          'Command failed: $executable ${args.join(' ')}\n'
          'Exit code: ${result.exitCode}\n'
          '${commandResult.fullOutput}',
        );
      } on ProcessException catch (e) {
        lastError = e;
        continue;
      }
    }

    throw Exception(
      'Cannot run nfc-mfclassic. Install libnfc tools first:\n'
      'brew install libnfc\n\n'
      'Last error: $lastError',
    );
  }

  Future<_PhysicalCardDump> _readPhysicalCardDump(String connstring) async {
    final tempDir = await Directory.systemTemp.createTemp('transport_card_');
    final dumpPath = '${tempDir.path}/card_dump.mfd';

    final result = await _runNfcMfclassic(connstring, [
      'r',
      'A',
      'u',
      dumpPath,
    ]);

    final dumpFile = File(dumpPath);
    if (!await dumpFile.exists()) {
      throw Exception(
        'nfc-mfclassic finished, but dump file was not created.\n'
        '${result.fullOutput}',
      );
    }

    final bytes = await dumpFile.readAsBytes();
    if (bytes.length < 1024) {
      throw Exception('Unexpected dump size: ${bytes.length} bytes');
    }

    return _PhysicalCardDump(
      directory: tempDir,
      dumpPath: dumpPath,
      bytes: bytes,
      commandOutput: result.fullOutput,
    );
  }

  String _blockText(List<int> bytes, int block) {
    final start = block * 16;
    final end = start + 16;

    if (bytes.length < end) {
      throw Exception('Dump is too small for block $block');
    }

    final raw = bytes.sublist(start, end);
    final zeroIndex = raw.indexOf(0);
    final visible = zeroIndex >= 0 ? raw.sublist(0, zeroIndex) : raw;

    return ascii.decode(visible, allowInvalid: true).trim();
  }


  String _uidCompactFromClassicDump(List<int> bytes) {
    if (bytes.length < 4) {
      throw Exception('Dump is too small to read UID from block 0');
    }

    return bytes
        .take(4)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  String _uidPrettyFromClassicDump(List<int> bytes) {
    if (bytes.length < 4) {
      throw Exception('Dump is too small to read UID from block 0');
    }

    return bytes
        .take(4)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join(' ');
  }

  int _parsePhysicalBalance(List<int> bytes) {
    final text = _blockText(bytes, 4);
    final match = RegExp(r'^BAL:(\d+)$').firstMatch(text);

    if (match == null) {
      throw Exception(
        'Block 4 does not contain balance in BAL:500 format.\n'
        'Current block 4 text: ${text.isEmpty ? '(empty)' : text}',
      );
    }

    return int.parse(match.group(1)!);
  }

  Future<_PhysicalCardBalance> _readPhysicalCardBalance(
    String connstring,
  ) async {
    final dump = await _readPhysicalCardDump(connstring);
    final balance = _parsePhysicalBalance(dump.bytes);

    return _PhysicalCardBalance(
      dump: dump,
      balance: balance,
      rawText: _blockText(dump.bytes, 4),
    );
  }

  Future<_PhysicalWriteResult> _writePhysicalCardBalance({
    required String connstring,
    required _PhysicalCardDump sourceDump,
    required int newBalance,
  }) async {
    if (newBalance < 0) {
      throw Exception('New physical card balance cannot be negative');
    }

    final modified = List<int>.from(sourceDump.bytes);
    final block = 4;
    final offset = block * 16;
    final payloadText = 'BAL:$newBalance';
    final payload = ascii.encode(payloadText);

    if (payload.length > 16) {
      throw Exception('Balance is too large for one MIFARE block: $payloadText');
    }

    for (var i = 0; i < 16; i++) {
      modified[offset + i] = i < payload.length ? payload[i] : 0;
    }

    final newDumpPath = '${sourceDump.directory.path}/card_dump_balance_$newBalance.mfd';
    await File(newDumpPath).writeAsBytes(modified, flush: true);

    final result = await _runNfcMfclassic(connstring, [
      'w',
      'A',
      'u',
      newDumpPath,
      sourceDump.dumpPath,
    ]);

    return _PhysicalWriteResult(
      newBalance: newBalance,
      newDumpPath: newDumpPath,
      commandOutput: result.fullOutput,
    );
  }

  int? _jsonInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  Future<_BackendCard?> _findBackendCard({
    required String apiBase,
    required String token,
    required String cardNo,
  }) async {
    final response = await client.get(
      Uri.parse('$apiBase/cards'),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        HttpHeaders.acceptHeader: 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Cannot load backend cards: HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Unexpected /cards response: ${response.body}');
    }

    final target = cardNo.toLowerCase();
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        final card = _BackendCard.fromJson(item);
        if (card.cardNo.toLowerCase() == target) {
          return card;
        }
      } else if (item is Map) {
        final card = _BackendCard.fromJson(Map<String, dynamic>.from(item));
        if (card.cardNo.toLowerCase() == target) {
          return card;
        }
      }
    }

    return null;
  }

  Future<String> _syncBackendCardBalance({
    required String apiBase,
    required String token,
    required String cardNo,
    required int physicalBalance,
  }) async {
    final existing = await _findBackendCard(
      apiBase: apiBase,
      token: token,
      cardNo: cardNo,
    );

    if (existing != null) {
      final response = await client.put(
        Uri.parse('$apiBase/cards/${existing.id}'),
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer $token',
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.acceptHeader: 'application/json',
        },
        body: jsonEncode({'balance': physicalBalance}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Cannot sync backend card balance: HTTP ${response.statusCode}: ${response.body}');
      }

      return 'Backend sync: карта $cardNo найдена, баланс БД обновлён ${existing.balance} → $physicalBalance.';
    }

    final ownerName = ownerNameController.text.trim().isEmpty
        ? 'MIFARE Passenger'
        : ownerNameController.text.trim();
    final keyId = int.tryParse(keyIdController.text.trim()) ?? 1;

    final response = await client.post(
      Uri.parse('$apiBase/cards'),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader: 'application/json',
      },
      body: jsonEncode({
        'card_number': cardNo.toLowerCase(),
        'owner_name': ownerName,
        'balance': physicalBalance,
        'is_blocked': false,
        'key_id': keyId <= 0 ? 1 : keyId,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Cannot create backend card from physical card: HTTP ${response.statusCode}: ${response.body}');
    }

    return 'Backend sync: карта $cardNo не была в БД, создана с балансом $physicalBalance.';
  }

  Future<void> readPhysicalCardBalance() async {
    setState(() {
      loadingPhysicalCard = true;
      physicalCardResultText =
          'Положи карту на PN532 и не убирай.\nЧитаю физический баланс из блока 4...';
    });

    try {
      final connstring = connstringController.text.trim();
      if (connstring.isEmpty) {
        throw Exception('libnfc connstring is required');
      }

      final result = await _readPhysicalCardBalance(connstring);

      if (!mounted) {
        return;
      }

      final uidCompact = _uidCompactFromClassicDump(result.dump.bytes);

      setState(() {
        cardController.text = uidCompact;
        lastPhysicalBalance = result.balance;
        physicalCardResultText =
            'Физический баланс прочитан.\n\n'
            'UID: $uidCompact\n'
            'Block 4: ${result.rawText}\n'
            'Balance: ${result.balance}\n\n'
            'Теперь карту можно убрать.';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        physicalCardResultText =
            'Ошибка чтения физического баланса:\n$e\n\n'
            'Проверь: карта лежит на PN532, connstring правильный, libnfc установлен через brew install libnfc.';
      });
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        loadingPhysicalCard = false;
      });
    }
  }

  Future<void> writeInitialPhysicalCardBalance() async {
    setState(() {
      loadingPhysicalCard = true;
      physicalCardResultText =
          'Положи карту на PN532 и не убирай.\n'
          'Сначала читаю дамп, потом запишу Initial balance в блок 4...';
    });

    try {
      final connstring = connstringController.text.trim();
      final initialBalance = int.tryParse(initialBalanceController.text.trim());

      if (connstring.isEmpty) {
        throw Exception('libnfc connstring is required');
      }
      if (initialBalance == null || initialBalance < 0) {
        throw Exception('Initial balance must be zero or positive integer');
      }

      final dump = await _readPhysicalCardDump(connstring);
      final uidCompact = _uidCompactFromClassicDump(dump.bytes);
      final writeResult = await _writePhysicalCardBalance(
        connstring: connstring,
        sourceDump: dump,
        newBalance: initialBalance,
      );

      var backendSyncMessage = '';
      try {
        final apiBase = trimRightSlash(apiBaseController.text.trim());
        if (apiBase.isNotEmpty) {
          final token = await login(apiBase);
          backendSyncMessage = await _syncBackendCardBalance(
            apiBase: apiBase,
            token: token,
            cardNo: uidCompact.toLowerCase(),
            physicalBalance: initialBalance,
          );
        }
      } catch (syncError) {
        backendSyncMessage =
            'ВНИМАНИЕ: на физическую карту записалось, но БД не синхронизировалась: $syncError';
      }

      if (!mounted) {
        return;
      }

      setState(() {
        cardController.text = uidCompact;
        lastPhysicalBalance = writeResult.newBalance;
        physicalCardResultText =
            'Initial balance записан на физическую карту и синхронизирован с backend.\n\n'
            'UID: $uidCompact\n'
            'Block 4: BAL:${writeResult.newBalance}\n'
            'Dump file: ${writeResult.newDumpPath}\n\n'
            '$backendSyncMessage\n\n'
            'Теперь в React нажми «Обновить всё»: баланс карты должен быть ${writeResult.newBalance}.';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        physicalCardResultText = 'Ошибка записи Initial balance на карту:\n$e';
      });
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        loadingPhysicalCard = false;
      });
    }
  }

  Future<void> createCard() async {
    setState(() {
      loadingCreateCard = true;
      createCardResultText = '';
    });

    try {
      final apiBase = trimRightSlash(apiBaseController.text.trim());
      final cardNumber = cardController.text.trim().toLowerCase();
      final ownerName = ownerNameController.text.trim();
      final initialBalance = int.tryParse(initialBalanceController.text.trim());
      final keyId = int.tryParse(keyIdController.text.trim());

      if (apiBase.isEmpty) {
        throw Exception('API base URL is required');
      }

      if (cardNumber.isEmpty) {
        throw Exception('Card UID is required. Scan card first.');
      }

      if (ownerName.isEmpty) {
        throw Exception('Owner name is required');
      }

      if (initialBalance == null || initialBalance < 0) {
        throw Exception('Initial balance must be zero or positive integer');
      }

      if (keyId == null || keyId <= 0) {
        throw Exception('Key ID must be positive integer');
      }

      final token = await login(apiBase);

      final response = await client.post(
        Uri.parse('$apiBase/cards'),
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer $token',
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.acceptHeader: 'application/json',
        },
        body: jsonEncode({
          'card_number': cardNumber,
          'owner_name': ownerName,
          'balance': initialBalance,
          'is_blocked': isBlocked,
          'key_id': keyId,
        }),
      );

      final body = response.body;

      if (response.statusCode == 409) {
        setState(() {
          createCardResultText =
              'Card already exists.\n\nBackend response:\n$body';
        });
        return;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: $body');
      }

      final json = jsonDecode(body) as Map<String, dynamic>;

      setState(() {
        createCardResultText =
            'Card created successfully:\n\n${const JsonEncoder.withIndent('  ').convert(json)}';
      });
    } catch (e) {
      setState(() {
        createCardResultText = 'Create card error: $e';
      });
    } finally {
      setState(() {
        loadingCreateCard = false;
      });
    }
  }

  Future<void> authorizePayment() async {
    setState(() {
      loadingPayment = true;
      paymentResultText = '';
      approved = null;
    });

    try {
      final apiBase = trimRightSlash(apiBaseController.text.trim());
      final terminalSerial = terminalController.text.trim();
      final cardNumber = cardController.text.trim().toLowerCase();
      final amount = int.tryParse(amountController.text.trim());

      if (apiBase.isEmpty) {
        throw Exception('API base URL is required');
      }

      if (terminalSerial.isEmpty) {
        throw Exception('Terminal serial is required');
      }

      if (cardNumber.isEmpty) {
        throw Exception('Card UID is required');
      }

      if (amount == null || amount <= 0) {
        throw Exception('Amount must be a positive integer');
      }

      final token = await login(apiBase);

      final response = await client.post(
        Uri.parse('$apiBase/terminal/transactions/authorize'),
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer $token',
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.acceptHeader: 'application/json',
        },
        body: jsonEncode({
          'terminal_serial': terminalSerial,
          'card_number': cardNumber,
          'amount': amount,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      setState(() {
        approved = json['approved'] == true;
        paymentResultText = const JsonEncoder.withIndent('  ').convert(json);
      });
    } catch (e) {
      setState(() {
        approved = false;
        paymentResultText = 'Error: $e';
      });
    } finally {
      setState(() {
        loadingPayment = false;
      });
    }
  }

  Future<String> login(String apiBase) async {
    final response = await client.post(
      Uri.parse('$apiBase/auth/login'),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader: 'application/json',
      },
      body: jsonEncode({'username': 'admin', 'password': 'admin123'}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Login failed: HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final token = json['token'];

    if (token is! String || token.isEmpty) {
      throw Exception('Login response does not contain token');
    }

    return token;
  }

  String trimRightSlash(String value) {
    var result = value;
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  Widget _terminalPanel({
    required IconData icon,
    required String title,
    required String command,
    required List<Widget> children,
    Color accent = _green,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              color: _panelSoft,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(color: accent.withOpacity(0.25)),
              ),
            ),
            child: Row(
              children: [
                const _MacDot(color: Color(0xFFFB7185)),
                const SizedBox(width: 7),
                const _MacDot(color: Color(0xFFFBBF24)),
                const SizedBox(width: 7),
                const _MacDot(color: Color(0xFF34D399)),
                const SizedBox(width: 14),
                Icon(icon, color: accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _commandLine(command, accent),
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _commandLine(String command, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Text(
            'kirill@terminal ~ %',
            style: TextStyle(
              color: accent,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              command,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _text,
                fontFamily: 'monospace',
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _terminalOutput(String text, {double fontSize = 13}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          color: const Color(0xFFD1FAE5),
          fontFamily: 'monospace',
          fontSize: fontSize,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _terminalButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required String loadingLabel,
    required bool loading,
    Color color = _green,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: color == _green ? const Color(0xFF04130A) : _text,
                ),
              )
            : Icon(icon),
        label: Text(loading ? loadingLabel : label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: color == _green ? const Color(0xFF04130A) : _bg,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF020617).withOpacity(0.48),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value.isEmpty ? '—' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String statusText, Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: statusColor.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.75),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(String statusText, Color statusColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _green.withOpacity(0.28)),
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.08),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _green.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            right: 80,
            bottom: -90,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _cyan.withOpacity(0.05),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _green.withOpacity(0.35)),
                    ),
                    child: const Text(
                      'SECURE NFC POS',
                      style: TextStyle(
                        color: _green,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  _statusBadge(statusText, statusColor),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Transport Terminal',
                style: TextStyle(
                  color: _text,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Тёмная терминальная панель для сканирования, регистрации карт и авторизации оплаты.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metricCard(
                    label: 'Terminal',
                    value: terminalController.text,
                    icon: Icons.point_of_sale_rounded,
                    color: _cyan,
                  ),
                  _metricCard(
                    label: 'Card UID',
                    value: cardController.text,
                    icon: Icons.credit_card_rounded,
                    color: _green,
                  ),
                  _metricCard(
                    label: 'Amount',
                    value: amountController.text,
                    icon: Icons.payments_rounded,
                    color: _amber,
                  ),
                  _metricCard(
                    label: 'Card BAL',
                    value: lastPhysicalBalance == null
                        ? 'not read'
                        : lastPhysicalBalance.toString(),
                    icon: Icons.account_balance_wallet_rounded,
                    color: _green,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScanPanel() {
    return _terminalPanel(
      icon: Icons.contactless_rounded,
      title: 'PN532 Scanner',
      command: 'nfc-list && scan-card',
      accent: _green,
      children: [
        TextField(
          controller: connstringController,
          decoration: const InputDecoration(
            labelText: 'libnfc connstring',
            helperText: 'Например: pn532_uart:/dev/cu.usbserial-0001',
            prefixIcon: Icon(Icons.usb_rounded),
          ),
        ),
        const SizedBox(height: 14),
        _terminalButton(
          onPressed: scanning ? null : scanCard,
          icon: Icons.nfc_rounded,
          label: 'Сканировать карту',
          loadingLabel: 'Ожидание карты...',
          loading: scanning,
        ),
        const SizedBox(height: 14),
        _terminalOutput(
          scanResultText.isEmpty
              ? 'No scan yet.\nConnect PN532 and press scan.'
              : scanResultText,
        ),
      ],
    );
  }

  Widget _buildRegisterPanel() {
    return _terminalPanel(
      icon: Icons.add_card_rounded,
      title: 'Card Registry',
      command: 'POST /api/v1/cards',
      accent: _cyan,
      children: [
        TextField(
          controller: cardController,
          decoration: const InputDecoration(
            labelText: 'Card UID compact',
            helperText: 'Заполняется автоматически после сканирования',
            prefixIcon: Icon(Icons.credit_card_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: ownerNameController,
          decoration: const InputDecoration(
            labelText: 'Owner name',
            prefixIcon: Icon(Icons.person_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: initialBalanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Initial balance',
                  prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: keyIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'MIFARE key ID',
                  prefixIcon: Icon(Icons.vpn_key_rounded),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF020617),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: SwitchListTile(
            title: const Text(
              'Blocked card',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Для новой карты обычно выключено'),
            value: isBlocked,
            onChanged: (value) {
              setState(() {
                isBlocked = value;
              });
            },
          ),
        ),
        const SizedBox(height: 14),
        _terminalButton(
          onPressed: loadingCreateCard ? null : createCard,
          icon: Icons.playlist_add_check_rounded,
          label: 'Зарегистрировать карту',
          loadingLabel: 'Создание карты...',
          loading: loadingCreateCard,
          color: _cyan,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: loadingPhysicalCard ? null : writeInitialPhysicalCardBalance,
          icon: const Icon(Icons.save_as_rounded),
          label: const Text('Записать Initial balance на карту и в БД'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _green,
            side: BorderSide(color: _green.withOpacity(0.55)),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _terminalOutput(
          createCardResultText.isEmpty
              ? 'No card registration yet.'
              : createCardResultText,
        ),
      ],
    );
  }

  Widget _buildPaymentPanel() {
    return _terminalPanel(
      icon: Icons.payments_rounded,
      title: 'Payment Authorization',
      command: 'POST /api/v1/terminal/transactions/authorize',
      accent: _amber,
      children: [
        TextField(
          controller: apiBaseController,
          decoration: const InputDecoration(
            labelText: 'API base URL',
            prefixIcon: Icon(Icons.language_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: terminalController,
          decoration: const InputDecoration(
            labelText: 'Terminal serial',
            prefixIcon: Icon(Icons.confirmation_number_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Payment amount',
            prefixIcon: Icon(Icons.attach_money_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF020617),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: SwitchListTile(
            title: const Text(
              'Списывать физический BAL на MIFARE Classic',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Использует block 4 с форматом BAL:500. Перед списанием БД автоматически синхронизируется с физической картой.',
            ),
            value: usePhysicalCardBalance,
            onChanged: (value) {
              setState(() {
                usePhysicalCardBalance = value;
              });
            },
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: loadingPhysicalCard ? null : readPhysicalCardBalance,
          icon: const Icon(Icons.manage_search_rounded),
          label: const Text('Считать BAL с физической карты'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _green,
            side: BorderSide(color: _green.withOpacity(0.55)),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _terminalButton(
          onPressed: (loadingPayment || scanning || loadingPhysicalCard) ? null : scanAndAuthorizePayment,
          icon: Icons.nfc_rounded,
          label: 'Приложить карту и списать',
          loadingLabel: 'Ожидание карты / списание...',
          loading: loadingPayment || scanning,
          color: _amber,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: (loadingPayment || loadingPhysicalCard) ? null : authorizePayment,
          icon: const Icon(Icons.bolt_rounded),
          label: const Text('Списать по UID из поля Card UID'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _amber,
            side: BorderSide(color: _amber.withOpacity(0.55)),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultPanel(String statusText, Color statusColor) {
    final icon = approved == true
        ? Icons.check_circle_rounded
        : approved == false
            ? Icons.cancel_rounded
            : Icons.pending_rounded;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withOpacity(0.34)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.08),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: statusColor, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _terminalOutput(
            paymentResultText.isEmpty
                ? 'No payment yet.\nWaiting for authorization request...'
                : paymentResultText,
            fontSize: 14,
          ),
          const SizedBox(height: 14),
          _terminalOutput(
            physicalCardResultText.isEmpty
                ? 'Physical card balance log is empty.\nUse «Считать BAL» or «Приложить карту и списать». '
                : physicalCardResultText,
            fontSize: 13,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = approved == true
        ? _green
        : approved == false
            ? _red
            : _cyan;

    final statusText = approved == true
        ? 'APPROVED'
        : approved == false
            ? 'DECLINED / ERROR'
            : 'READY';

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1120;

            final leftColumn = Column(
              children: [
                _buildScanPanel(),
                const SizedBox(height: 18),
                _buildRegisterPanel(),
              ],
            );

            final rightColumn = Column(
              children: [
                _buildPaymentPanel(),
                const SizedBox(height: 18),
                _buildResultPanel(statusText, statusColor),
              ],
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Column(
                    children: [
                      _hero(statusText, statusColor),
                      const SizedBox(height: 22),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: leftColumn),
                            const SizedBox(width: 18),
                            Expanded(flex: 5, child: rightColumn),
                          ],
                        )
                      else
                        Column(
                          children: [
                            leftColumn,
                            const SizedBox(height: 18),
                            rightColumn,
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MacDot extends StatelessWidget {
  const _MacDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
