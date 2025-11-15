import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';

class ContractCallTab extends StatefulWidget {
  final ReownAppKitModal? appKit;

  const ContractCallTab({super.key, required this.appKit});

  @override
  State<ContractCallTab> createState() => _ContractCallTabState();
}

class _ContractCallTabState extends State<ContractCallTab> {
  final _transactionDataController = TextEditingController();
  final _nonceController = TextEditingController();
  String? _signedTransaction;
  bool _isLoading = false;

  Future<void> _signCounterTransaction() async {
    if (widget.appKit == null || !widget.appKit!.isConnected) {
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
      final chainId = widget.appKit!.selectedChain?.chainId ?? 'eip155:11155111';
      final namespace = NamespaceUtils.getNamespaceFromChain(chainId);
      final address = widget.appKit!.session!.getAddress(namespace);

      if (address == null) {
        throw Exception('No wallet address found');
      }

      final transactionData = _transactionDataController.text.trim();

      if (chainId.startsWith('solana:')) {
        // Solana transaction signing
        await _signSolanaTransaction(chainId, transactionData);
      } else {
        // Ethereum transaction signing
        await _signEthereumTransaction(chainId, address, transactionData);
      }

      _showSnackBar('Transaction signed successfully!');
    } catch (e) {
      print('Error signing transaction: $e');
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signEthereumTransaction(String chainId, String address, String transactionData) async {
    // Create transaction object for Ethereum
    final toAddress = '0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f';
    final nonce = _nonceController.text.isEmpty ? null : int.tryParse(_nonceController.text);

    Map<String, dynamic> transaction = {
      'from': address,
      'to': toAddress,
      'value': '0x0', // 0 ETH
      'data': transactionData.startsWith('0x') ? transactionData : '0x$transactionData',
    };

    if (nonce != null) {
      transaction['nonce'] = '0x${nonce.toRadixString(16)}';
    }

    // Send the transaction for signing
    final result = await widget.appKit!.request(
      topic: widget.appKit!.session!.topic,
      chainId: chainId,
      request: SessionRequestParams(method: 'eth_sendTransaction', params: [transaction]),
    );

    setState(() {
      _signedTransaction = result.toString();
    });
  }

  Future<void> _signSolanaTransaction(String chainId, String transactionData) async {
    // For Solana, we use signMessage or signTransaction
    // This is a simplified example - in reality you'd construct a proper Solana transaction
    final result = await widget.appKit!.request(
      topic: widget.appKit!.session!.topic,
      chainId: chainId,
      request: SessionRequestParams(
        method: 'solana_signMessage',
        params: {'message': transactionData, 'display': 'utf8'},
      ),
    );

    setState(() {
      _signedTransaction = result.toString();
    });
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
    final isConnected = widget.appKit?.isConnected ?? false;

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
                decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.edit_note, color: colorScheme.onPrimaryContainer, size: 22),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sign Transaction', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(
                      'Sign transactions for Ethereum or Solana networks',
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
                    Icon(Icons.warning_amber_rounded, color: colorScheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please connect a wallet in the Connect tab first',
                        style: TextStyle(color: colorScheme.onErrorContainer, fontWeight: FontWeight.w500),
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
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _transactionDataController,
                    enabled: isConnected && !_isLoading,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText:
                          'For Ethereum: {"to": "0x...", "value": "0x0", "data": "0x..."}\nFor Solana: Message text or base58 transaction',
                      prefixIcon: Icon(Icons.code),
                      helperText: 'Enter transaction data (format depends on network)',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Nonce (Optional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nonceController,
                    enabled: isConnected && !_isLoading,
                    decoration: const InputDecoration(
                      hintText: '0',
                      prefixIcon: Icon(Icons.numbers),
                      helperText: 'Ethereum nonce (leave empty for auto, N/A for Solana)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (isConnected && !_isLoading) ? _signCounterTransaction : null,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.edit_note),
                      label: Text(_isLoading ? 'Signing...' : 'Sign Transaction'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
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
                        Icon(Icons.check_circle, color: colorScheme.onPrimaryContainer, size: 20),
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
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
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
                      Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Important Notes',
                        style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoItem('Supports both Ethereum and Solana transaction signing'),
                  _buildInfoItem('For Ethereum: Send transaction data as JSON or hex'),
                  _buildInfoItem('For Solana: Send message text for signing'),
                  _buildInfoItem('You will need to approve the signature in your wallet'),
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
            child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
