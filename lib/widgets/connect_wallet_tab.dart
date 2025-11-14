import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web3modal_flutter/web3modal_flutter.dart';
import 'dart:developer';

// Tab 2: Connect Wallet
class ConnectWalletTab extends StatefulWidget {
  final W3MService? w3mService;

  const ConnectWalletTab({super.key, required this.w3mService});

  @override
  State<ConnectWalletTab> createState() => _ConnectWalletTabState();
}

class _ConnectWalletTabState extends State<ConnectWalletTab> {
  String? _connectedAddress;

  @override
  void initState() {
    super.initState();
    _updateAddress();
    widget.w3mService?.addListener(_updateAddress);
  }

  void _updateAddress() {
    final accounts = widget.w3mService?.session?.getAccounts();
    String? address;
    if (accounts != null && accounts.isNotEmpty) {
      final accountString = accounts.first;
      if (accountString.contains(':')) {
        address = accountString.split(':').last;
      } else {
        address = accountString;
      }
    }
    if (mounted) {
      setState(() {
        _connectedAddress = address;
      });
    }
  }

  Future<void> _connectWallet() async {
    if (widget.w3mService == null) {
      _showSnackBar('Web3Modal not initialized');
      return;
    }

    try {
      if (widget.w3mService!.isConnected) {
        await widget.w3mService!.disconnect();
        _updateAddress();
      } else {
        await widget.w3mService!.openModal(context);
        _updateAddress();
      }
    } catch (e) {
      log('Error connecting wallet: $e');
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isConnected = widget.w3mService?.isConnected ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            isConnected ? 'Wallet Connected' : 'Connect Your Wallet',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isConnected
                ? 'Your wallet is ready to use'
                : 'Connect your wallet to get started',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Card(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isConnected
                      ? [Colors.green.shade50, Colors.green.shade100]
                      : [
                          colorScheme.surfaceContainerHighest,
                          colorScheme.surfaceContainer,
                        ],
                ),
              ),
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isConnected ? Icons.check_circle : Icons.wallet_outlined,
                      size: 64,
                      color: isConnected ? Colors.green.shade700 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isConnected ? 'Connected' : 'Not Connected',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isConnected
                          ? Colors.green.shade900
                          : Colors.grey.shade700,
                    ),
                  ),
                  if (_connectedAddress != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Address',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _connectedAddress!),
                                  );
                                  _showSnackBar('Address copied to clipboard');
                                },
                                tooltip: 'Copy address',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onLongPress: () {
                              Clipboard.setData(
                                ClipboardData(text: _connectedAddress!),
                              );
                              _showSnackBar('Address copied to clipboard');
                            },
                            child: Text(
                              _connectedAddress!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.w3mService == null ? null : _connectWallet,
              icon: Icon(isConnected ? Icons.logout : Icons.login),
              label: Text(isConnected ? 'Disconnect Wallet' : 'Connect Wallet'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: isConnected
                    ? colorScheme.error
                    : colorScheme.primary,
                foregroundColor: isConnected
                    ? colorScheme.onError
                    : colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
