import 'package:flutter/material.dart';
import 'package:web3modal_flutter/web3modal_flutter.dart';
import 'dart:convert';
import 'dart:developer';

// Tab 3: Sign Counter Transaction
class SignTransactionTab extends StatefulWidget {
  final W3MService? w3mService;
  final Web3Client rpcClient;

  const SignTransactionTab({
    super.key,
    required this.w3mService,
    required this.rpcClient,
  });

  @override
  State<SignTransactionTab> createState() => _SignTransactionTabState();
}

class _SignTransactionTabState extends State<SignTransactionTab> {
  final TextEditingController _transactionDataController =
      TextEditingController();
  final TextEditingController _nonceController = TextEditingController();
  String? _signedTransaction;
  bool _isLoading = false;

  Future<void> _signCounterTransaction() async {
    if (widget.w3mService == null || !widget.w3mService!.isConnected) {
      _showSnackBar('Please connect a wallet first');
      return;
    }

    if (_transactionDataController.text.isEmpty) {
      _showSnackBar('Please enter transaction data to sign');
      return;
    }

    setState(() {
      _isLoading = true;
      _signedTransaction = null;
    });

    try {
      final accounts = widget.w3mService!.session?.getAccounts();
      if (accounts == null || accounts.isEmpty) {
        throw Exception('No connected address found');
      }

      final accountString = accounts.first;
      final fromAddress = accountString.contains(':')
          ? accountString.split(':').last
          : accountString;

      // Parse transaction data (can be JSON string or hex)
      Map<String, dynamic> tx;
      final input = _transactionDataController.text.trim();

      // Try to parse as JSON first
      if (input.startsWith('{')) {
        try {
          // Parse JSON transaction data
          final jsonData = jsonDecode(input) as Map<String, dynamic>;
          tx = Map<String, dynamic>.from(jsonData);
        } catch (e) {
          // If JSON parsing fails, treat as hex data
          tx = {
            "from": fromAddress,
            "data": input.startsWith('0x') ? input : '0x$input',
          };
        }
      } else {
        // Treat as hex data or simple string
        tx = {
          "from": fromAddress,
          "data": input.startsWith('0x') ? input : '0x$input',
        };
      }

      // Ensure from address is set
      if (!tx.containsKey("from") || tx["from"] == null) {
        tx["from"] = fromAddress;
      }

      // Add nonce if provided
      if (_nonceController.text.isNotEmpty) {
        final nonce = int.tryParse(_nonceController.text);
        if (nonce != null) {
          tx["nonce"] = '0x${nonce.toRadixString(16)}';
        }
      }

      final session = widget.w3mService!.session;
      if (session == null || session.topic == null) {
        throw Exception('No active session');
      }

      // Sign the transaction (eth_signTransaction signs without broadcasting)
      final signature = await widget.w3mService!.request(
        topic: session.topic!,
        chainId: 'eip155:11155111',
        request: SessionRequestParams(
          method: 'eth_signTransaction',
          params: [tx],
        ),
      );

      setState(() {
        _signedTransaction = signature.toString();
        _isLoading = false;
      });

      _showSnackBar('Transaction signed successfully!');
    } catch (e) {
      log('Error signing transaction: $e');
      _showSnackBar('Error: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
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
  void dispose() {
    _transactionDataController.dispose();
    _nonceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isConnected = widget.w3mService?.isConnected ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.edit_note,
                  color: colorScheme.onPrimaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign Counter Transaction',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sign a counter transaction',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (!isConnected)
            Card(
              color: colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please connect a wallet in the Connect tab first',
                        style: TextStyle(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!isConnected) const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transaction Data',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _transactionDataController,
                    enabled: isConnected && !_isLoading,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText:
                          '{"to": "0x...", "value": "0x0", "data": "0x..."}\nor\n0x...',
                      prefixIcon: Icon(Icons.code),
                      helperText: 'Enter transaction JSON or hex data',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Nonce (Optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nonceController,
                    enabled: isConnected && !_isLoading,
                    decoration: const InputDecoration(
                      hintText: '0',
                      prefixIcon: Icon(Icons.numbers),
                      helperText: 'Transaction nonce (leave empty for auto)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (isConnected && !_isLoading)
                          ? _signCounterTransaction
                          : null,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.edit_note),
                      label: Text(
                        _isLoading ? 'Signing...' : 'Sign Counter Transaction',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_signedTransaction != null) ...[
            const SizedBox(height: 24),
            Card(
              color: colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Signed Transaction',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SelectableText(
                        _signedTransaction!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            color: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Important Notes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoItem(
                    'Signs a counter transaction without broadcasting',
                  ),
                  _buildInfoItem(
                    'Transaction data can be JSON format or hex string',
                  ),
                  _buildInfoItem(
                    'You will need to approve the signature in your wallet',
                  ),
                  _buildInfoItem(
                    'The signed transaction can be used later to counter another transaction',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
