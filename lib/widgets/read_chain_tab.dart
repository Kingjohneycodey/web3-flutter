import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

class ReadChainTab extends StatefulWidget {
  const ReadChainTab({super.key});

  @override
  State<ReadChainTab> createState() => _ReadChainTabState();
}

class _ReadChainTabState extends State<ReadChainTab> {
  final _addressController = TextEditingController();
  final _tokenAddressController = TextEditingController();
  final _tokenWalletAddressController = TextEditingController();
  String _selectedChain = 'Sepolia';
  String? _balance;
  String? _tokenBalance;
  bool _isLoading = false;
  bool _isTokenLoading = false;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoadingTransactions = false;

  final Map<String, Map<String, dynamic>> _chains = {
    'Sepolia': {'type': 'evm', 'rpc': 'https://sepolia.drpc.org', 'chainId': 11155111},
    'Solana Devnet': {'type': 'solana', 'rpc': 'https://api.devnet.solana.com', 'chainId': null},
    'Sui Testnet': {'type': 'sui', 'rpc': 'https://fullnode.testnet.sui.io:443', 'chainId': null},
  };

  Future<void> _fetchBalance() async {
    if (_addressController.text.isEmpty) {
      _showSnackBar('Please enter a wallet address');
      return;
    }

    setState(() {
      _isLoading = true;
      _balance = null;
    });

    try {
      final address = _addressController.text.trim();
      final chainInfo = _chains[_selectedChain]!;
      final chainType = chainInfo['type'] as String;

      if (chainType == 'evm') {
        final rpcUrl = chainInfo['rpc'] as String;
        final client = Web3Client(rpcUrl, Client());
        final ethAddress = EthereumAddress.fromHex(address);
        final balance = await client.getBalance(ethAddress);
        final ethBalance = balance.getValueInUnit(EtherUnit.ether);

        setState(() {
          _balance = '$ethBalance ETH';
          _isLoading = false;
        });
      } else if (chainType == 'solana') {
        final rpcUrl = chainInfo['rpc'] as String;
        final response = await Client().post(
          Uri.parse(rpcUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'getBalance',
            'params': [address],
          }),
        );

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data.containsKey('error')) {
          throw Exception(data['error']['message']);
        }

        final lamports = data['result']['value'] as int;
        final solBalance = lamports / 1e9; // Convert lamports to SOL

        setState(() {
          _balance = '$solBalance SOL';
          _isLoading = false;
        });
      } else if (chainType == 'sui') {
        final rpcUrl = chainInfo['rpc'] as String;
        final response = await Client().post(
          Uri.parse(rpcUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'suix_getBalance',
            'params': [address],
          }),
        );

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data.containsKey('error')) {
          throw Exception(data['error']['message']);
        }

        final totalBalance = data['result']['totalBalance'] as String;
        final suiBalance = BigInt.parse(totalBalance) / BigInt.from(10).pow(9);

        setState(() {
          _balance = '$suiBalance SUI';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _balance = 'Error: ${e.toString()}';
        _isLoading = false;
      });
      log('Error fetching balance: $e');
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

  Future<void> _fetchTokenBalance() async {
    if (_tokenWalletAddressController.text.isEmpty || _tokenAddressController.text.isEmpty) {
      _showSnackBar('Please enter wallet address and token address');
      return;
    }

    setState(() {
      _isTokenLoading = true;
      _tokenBalance = null;
    });

    try {
      final walletAddress = _tokenWalletAddressController.text.trim();
      final tokenAddress = _tokenAddressController.text.trim();
      final chainInfo = _chains[_selectedChain]!;
      final chainType = chainInfo['type'] as String;

      if (chainType == 'evm') {
        final rpcUrl = chainInfo['rpc'] as String;
        final client = Web3Client(rpcUrl, Client());
        final walletEthAddress = EthereumAddress.fromHex(walletAddress);
        final tokenEthAddress = EthereumAddress.fromHex(tokenAddress);

        // Create contract ABI and function
        final abi = ContractAbi.fromJson(
          '[{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"}]',
          'ERC20',
        );

        final contract = DeployedContract(abi, tokenEthAddress);
        final function = contract.function('balanceOf');

        // Call the contract
        final result = await client.call(contract: contract, function: function, params: [walletEthAddress]);

        if (result.isNotEmpty) {
          final balance = result[0] as BigInt;
          // Assume 18 decimals (standard for most tokens)
          final tokenBalance = (balance / BigInt.from(10).pow(18)).toString();
          setState(() {
            _tokenBalance = '$tokenBalance Tokens';
            _isTokenLoading = false;
          });
        } else {
          throw Exception('No balance returned');
        }
      } else if (chainType == 'solana') {
        // Solana SPL token balance
        final rpcUrl = chainInfo['rpc'] as String;
        final response = await Client().post(
          Uri.parse(rpcUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'getTokenAccountBalance',
            'params': [tokenAddress],
          }),
        );

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data.containsKey('error')) {
          throw Exception(data['error']['message']);
        }

        final amount = data['result']['value']['amount'] as String;
        final decimals = data['result']['value']['decimals'] as int;
        final tokenBalance = BigInt.parse(amount) / BigInt.from(10).pow(decimals);

        setState(() {
          _tokenBalance = '$tokenBalance Tokens';
          _isTokenLoading = false;
        });
      } else if (chainType == 'sui') {
        // Sui token balance
        final rpcUrl = chainInfo['rpc'] as String;
        final response = await Client().post(
          Uri.parse(rpcUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'suix_getBalance',
            'params': [walletAddress, tokenAddress],
          }),
        );

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data.containsKey('error')) {
          throw Exception(data['error']['message']);
        }

        final totalBalance = data['result']['totalBalance'] as String;
        final tokenBalance = BigInt.parse(totalBalance) / BigInt.from(10).pow(9);

        setState(() {
          _tokenBalance = '$tokenBalance Tokens';
          _isTokenLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _tokenBalance = 'Error: ${e.toString()}';
        _isTokenLoading = false;
      });
      log('Error fetching token balance: $e');
    }
  }

  Future<void> _fetchTransactions() async {
    if (_addressController.text.isEmpty) {
      _showSnackBar('Please enter a wallet address first');
      return;
    }

    setState(() {
      _isLoadingTransactions = true;
    });

    try {
      final address = _addressController.text.trim();
      final chainInfo = _chains[_selectedChain]!;
      final chainType = chainInfo['type'] as String;
      final transactions = <Map<String, dynamic>>[];

      if (chainType == 'evm') {
        final rpcUrl = chainInfo['rpc'] as String;
        final client = Web3Client(rpcUrl, Client());
        final ethAddress = EthereumAddress.fromHex(address);

        // Get transaction count to determine range
        final txCount = await client.getTransactionCount(ethAddress);

        // Fetch last 10 transactions (simplified - in production use proper block explorer API)
        // Note: This is a simplified approach. For production, use a block explorer API
        // like Etherscan, Polygonscan, etc. to get actual transaction history
        for (int i = 0; i < 10 && i < txCount; i++) {
          try {
            final nonce = txCount - 1 - i;
            // This is a placeholder - actual implementation would query block explorer
            transactions.add({
              'hash': '0x${nonce.toRadixString(16).padLeft(64, '0')}',
              'nonce': nonce,
              'status': 'pending',
            });
          } catch (e) {
            break;
          }
        }
      } else if (chainType == 'solana') {
        // Solana transaction history
        final rpcUrl = chainInfo['rpc'] as String;
        final response = await Client().post(
          Uri.parse(rpcUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'getSignaturesForAddress',
            'params': [
              address,
              {'limit': 10},
            ],
          }),
        );

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (!data.containsKey('error') && data['result'] != null) {
          final sigs = data['result'] as List;
          for (var sig in sigs) {
            transactions.add({
              'hash': sig['signature'] ?? '',
              'status': sig['err'] == null ? 'success' : 'failed',
              'slot': sig['slot'] ?? 0,
            });
          }
        }
      } else if (chainType == 'sui') {
        // Sui transaction history
        final rpcUrl = chainInfo['rpc'] as String;
        final response = await Client().post(
          Uri.parse(rpcUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'suix_queryTransactionBlocks',
            'params': [
              {
                'filter': {'FromAddress': address},
                'options': {'showInput': true, 'showEffects': true, 'showEvents': true},
              },
              null,
              10,
              false,
            ],
          }),
        );

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (!data.containsKey('error') && data['result'] != null) {
          final txs = data['result']['data'] as List?;
          if (txs != null) {
            for (var tx in txs) {
              transactions.add({
                'hash': tx['digest'] ?? '',
                'status': tx['effects']['status']?['status'] ?? 'unknown',
                'timestamp': tx['timestampMs'] ?? 0,
              });
            }
          }
        }
      }

      setState(() {
        _transactions = transactions;
        _isLoadingTransactions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTransactions = false;
      });
      log('Error fetching transactions: $e');
      _showSnackBar('Error fetching transactions: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _tokenAddressController.dispose();
    _tokenWalletAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                child: Icon(Icons.account_balance, color: colorScheme.onPrimaryContainer, size: 22),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Check Balance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('View wallet balance on any chain', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wallet Address',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addressController,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      hintText: '0x742d35Cc6634C0532925a3b8...',
                      prefixIcon: Icon(Icons.wallet),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select Chain',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedChain,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.public)),
                    items: _chains.keys.map((String chain) {
                      final chainType = _chains[chain]!['type'] as String;
                      return DropdownMenuItem(
                        value: chain,
                        child: Row(
                          children: [
                            Text(chain, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: chainType == 'evm'
                                    ? Colors.blue.shade50
                                    : chainType == 'solana'
                                    ? Colors.purple.shade50
                                    : Colors.cyan.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                chainType.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: chainType == 'evm'
                                      ? Colors.blue.shade700
                                      : chainType == 'solana'
                                      ? Colors.purple.shade700
                                      : Colors.cyan.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedChain = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _fetchBalance,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.search),
                      label: Text(_isLoading ? 'Fetching...' : 'Fetch Balance'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_balance != null) ...[
            const SizedBox(height: 24),
            Card(
              color: _balance!.startsWith('Error') ? colorScheme.errorContainer : colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _balance!.startsWith('Error') ? Icons.error_outline : Icons.account_balance_wallet,
                          color: _balance!.startsWith('Error')
                              ? colorScheme.onErrorContainer
                              : colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _balance!.startsWith('Error') ? 'Error' : 'Balance',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _balance!.startsWith('Error')
                                ? colorScheme.onErrorContainer
                                : colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _balance!,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _balance!.startsWith('Error')
                            ? colorScheme.onErrorContainer
                            : colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          // Token Balance Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.account_balance_wallet, color: colorScheme.onPrimaryContainer, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Token Balance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wallet Address',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tokenWalletAddressController,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: '0x742d35Cc6634C0532925a3b8...',
                      prefixIcon: Icon(Icons.wallet, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Chain',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedChain,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.public, size: 20)),
                    items: _chains.keys.map((String chain) {
                      final chainType = _chains[chain]!['type'] as String;
                      return DropdownMenuItem(
                        value: chain,
                        child: Row(
                          children: [
                            Text(chain, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: chainType == 'evm'
                                    ? Colors.blue.shade50
                                    : chainType == 'solana'
                                    ? Colors.purple.shade50
                                    : Colors.cyan.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                chainType.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: chainType == 'evm'
                                      ? Colors.blue.shade700
                                      : chainType == 'solana'
                                      ? Colors.purple.shade700
                                      : Colors.cyan.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedChain = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Token Address',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tokenAddressController,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(hintText: '0x...', prefixIcon: Icon(Icons.token, size: 20)),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isTokenLoading ? null : _fetchTokenBalance,
                      icon: _isTokenLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.search, size: 18),
                      label: Text(
                        _isTokenLoading ? 'Fetching...' : 'Fetch Token Balance',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_tokenBalance != null) ...[
            const SizedBox(height: 16),
            Card(
              color: _tokenBalance!.startsWith('Error') ? colorScheme.errorContainer : colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _tokenBalance!.startsWith('Error') ? Icons.error_outline : Icons.token,
                          color: _tokenBalance!.startsWith('Error')
                              ? colorScheme.onErrorContainer
                              : colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _tokenBalance!.startsWith('Error') ? 'Error' : 'Token Balance',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _tokenBalance!.startsWith('Error')
                                ? colorScheme.onErrorContainer
                                : colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _tokenBalance!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _tokenBalance!.startsWith('Error')
                            ? colorScheme.onErrorContainer
                            : colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          // Latest Transactions Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.history, color: colorScheme.onPrimaryContainer, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Latest Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_isLoadingTransactions || _addressController.text.isEmpty)
                          ? null
                          : _fetchTransactions,
                      icon: _isLoadingTransactions
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(
                        _isLoadingTransactions ? 'Loading...' : 'Fetch Transactions',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  if (_transactions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    ..._transactions.map(
                      (tx) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long, size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tx: ${tx['hash'].toString().substring(0, 10)}...',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Nonce: ${tx['nonce']}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tx['status'] ?? 'pending',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (!_isLoadingTransactions) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: Text('No transactions found', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
