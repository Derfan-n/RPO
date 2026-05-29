// lib/src/libnfc/libnfc_reader.dart

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../models.dart';
import 'libnfc_bindings.dart';

class LibNfcReader {
  LibNfcReader({this.connstring = 'pn532_uart:/dev/tty.usbserial-TGJLH5CH'});

  final String connstring;

  late final LibNfcBindings _nfc;
  Pointer<NfcContext> _context = nullptr;
  Pointer<NfcDevice> _device = nullptr;

  bool get isOpen => _device != nullptr;

  void open() {
    _nfc = LibNfcBindings(openLibNfc());

    final contextPtr = calloc<Pointer<NfcContext>>();

    try {
      _nfc.nfcInit(contextPtr);

      _context = contextPtr.value;

      if (_context == nullptr) {
        throw StateError('libnfc: nfc_init failed');
      }

      final connstringPtr = connstring.toNativeUtf8();

      try {
        _device = _nfc.nfcOpen(_context, connstringPtr);

        if (_device == nullptr) {
          throw StateError('libnfc: nfc_open failed for $connstring');
        }
      } finally {
        calloc.free(connstringPtr);
      }

      final initResult = _nfc.nfcInitiatorInit(_device);

      if (initResult < 0) {
        throw StateError('libnfc: nfc_initiator_init failed: ${_lastError()}');
      }
    } finally {
      calloc.free(contextPtr);
    }
  }

  void close() {
    if (_device != nullptr) {
      _nfc.nfcClose(_device);
      _device = nullptr;
    }

    if (_context != nullptr) {
      _nfc.nfcExit(_context);
      _context = nullptr;
    }
  }

  Pn532Card? scanOneCard() {
    if (_device == nullptr) {
      throw StateError('LibNfcReader is not open. Call open() first.');
    }

    final modulation = calloc<NfcModulation>();
    final target = calloc<NfcTarget>();

    try {
      modulation.ref
        ..nmt = nmtIso14443A
        ..nbr = nbr106;

      final result = _nfc.nfcInitiatorSelectPassiveTarget(
        _device,
        modulation.ref,
        nullptr,
        0,
        target,
      );

      if (result <= 0) {
        return null;
      }

      final nai = target.ref.nti.nai;

      final uidLength = nai.szUidLen;

      if (uidLength <= 0 || uidLength > 10) {
        throw StateError('libnfc: invalid UID length: $uidLength');
      }

      final uid = <int>[];

      for (var i = 0; i < uidLength; i++) {
        uid.add(nai.abtUid[i]);
      }

      final atqa = <int>[nai.abtAtqa[0], nai.abtAtqa[1]];

      return Pn532Card(uid: uid, atqa: atqa, sak: nai.btSak);
    } finally {
      calloc.free(modulation);
      calloc.free(target);
    }
  }

  String _lastError() {
    if (_device == nullptr) {
      return 'unknown error';
    }

    final ptr = _nfc.nfcStrError(_device);

    if (ptr == nullptr) {
      return 'unknown error';
    }

    return ptr.toDartString();
  }
}
