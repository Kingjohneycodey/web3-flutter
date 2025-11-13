import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'package:web3modal_flutter/web3modal_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer';
import 'dart:convert';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Web3 Flutter App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0000FF),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFE3F2FD),
          onPrimaryContainer: Color(0xFF0000FF),
          secondary: Color(0xFF1976D2),
          onSecondary: Colors.white,
          tertiary: Color(0xFF0D47A1),
          onTertiary: Colors.white,
          error: Color(0xFFB00020),
          onError: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF1C1B1F),
          surfaceContainerHighest: Color(0xFFF5F5F5),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0000FF), width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  W3MService? _w3mService;
  late Web3Client _rpcClient;

  @override
  void initState() {
    super.initState();
    _rpcClient = Web3Client(
      'https://ethereum-sepolia-rpc.publicnode.com',
      Client(),
    );
    _initializeWeb3Modal();
  }

  void _initializeWeb3Modal() async {
    try {
      final projectId = dotenv.env['WALLETCONNECT_PROJECT_ID'] ?? '';
      if (projectId.isEmpty) {
        throw Exception('WALLETCONNECT_PROJECT_ID not found in .env file');
      }

      _w3mService = W3MService(
        projectId: projectId,
        metadata: PairingMetadata(
          name: 'Web3 Flutter App',
          description: 'A Web3 Flutter application',
          url: 'https://www.walletconnect.com',
          icons: ['https://web3modal.com/images/rpc-illustration.png'],
        ),
        logLevel: LogLevel.error,
      );

      await _w3mService!.init();
      _w3mService!.addListener(() => setState(() {}));
    } catch (e) {
      log('Error initializing Web3Modal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colorScheme.surface, colorScheme.surfaceContainerHighest],
          ),
        ),
        child: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: [
              BalanceTab(rpcClient: _rpcClient),
              ConnectWalletTab(w3mService: _w3mService),
              SignTransactionTab(
                w3mService: _w3mService,
                rpcClient: _rpcClient,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 100,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.zero,
          child: NavigationBar(
            selectedIndex: _currentIndex,
            height: 80,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.visibility_outlined, size: 22),
                selectedIcon: Icon(Icons.visibility, size: 22),
                label: 'Read',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined, size: 22),
                selectedIcon: Icon(Icons.account_balance_wallet, size: 22),
                label: 'Auth',
              ),
              NavigationDestination(
                icon: Icon(Icons.edit_note_outlined, size: 22),
                selectedIcon: Icon(Icons.edit_note, size: 22),
                label: 'Contract',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Tab 1: Balance Checker
class BalanceTab extends StatefulWidget {
  final Web3Client rpcClient;

  const BalanceTab({super.key, required this.rpcClient});

  @override
  State<BalanceTab> createState() => _BalanceTabState();
}

class _BalanceTabState extends State<BalanceTab> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _tokenAddressController = TextEditingController();
  final TextEditingController _tokenWalletAddressController =
      TextEditingController();
  String _selectedChain = 'Sepolia';
  String? _balance;
  String? _tokenBalance;
  bool _isLoading = false;
  bool _isTokenLoading = false;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoadingTransactions = false;

  final Map<String, Map<String, dynamic>> _chains = {
    'Sepolia': {
      'type': 'evm',
      'rpc': 'https://ethereum-sepolia-rpc.publicnode.com',
      'chainId': 11155111,
    },
    'Ethereum Mainnet': {
      'type': 'evm',
      'rpc': 'https://ethereum-rpc.publicnode.com',
      'chainId': 1,
    },
    'Base': {
      'type': 'evm',
      'rpc': 'https://base-rpc.publicnode.com',
      'chainId': 8453,
    },
    'Polygon': {
      'type': 'evm',
      'rpc': 'https://polygon-rpc.publicnode.com',
      'chainId': 137,
    },
    'Solana': {
      'type': 'solana',
      'rpc': 'https://api.mainnet-beta.solana.com',
      'chainId': null,
    },
    'Solana Devnet': {
      'type': 'solana',
      'rpc': 'https://api.devnet.solana.com',
      'chainId': null,
    },
    'Sui': {
      'type': 'sui',
      'rpc': 'https://fullnode.mainnet.sui.io:443',
      'chainId': null,
    },
    'Sui Testnet': {
      'type': 'sui',
      'rpc': 'https://fullnode.testnet.sui.io:443',
      'chainId': null,
    },
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
        // Solana balance fetch via RPC
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
        // Sui balance fetch via RPC
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
    if (_tokenWalletAddressController.text.isEmpty ||
        _tokenAddressController.text.isEmpty) {
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
        final result = await client.call(
          contract: contract,
          function: function,
          params: [walletEthAddress],
        );

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
        final tokenBalance =
            BigInt.parse(amount) / BigInt.from(10).pow(decimals);

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
        final tokenBalance =
            BigInt.parse(totalBalance) / BigInt.from(10).pow(9);

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
                'options': {
                  'showInput': true,
                  'showEffects': true,
                  'showEvents': true,
                },
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
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance,
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
                      'Check Balance',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'View wallet balance on any chain',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedChain,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.public),
                    ),
                    items: _chains.keys.map((String chain) {
                      final chainType = _chains[chain]!['type'] as String;
                      return DropdownMenuItem(
                        value: chain,
                        child: Row(
                          children: [
                            Text(chain, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
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
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.search),
                      label: Text(_isLoading ? 'Fetching...' : 'Fetch Balance'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_balance != null) ...[
            const SizedBox(height: 24),
            Card(
              color: _balance!.startsWith('Error')
                  ? colorScheme.errorContainer
                  : colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _balance!.startsWith('Error')
                              ? Icons.error_outline
                              : Icons.account_balance_wallet,
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
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: colorScheme.onPrimaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Token Balance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tokenWalletAddressController,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0x742d35Cc6634C0532925a3b8...',
                      prefixIcon: Icon(Icons.wallet, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Chain',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedChain,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.public, size: 20),
                    ),
                    items: _chains.keys.map((String chain) {
                      final chainType = _chains[chain]!['type'] as String;
                      return DropdownMenuItem(
                        value: chain,
                        child: Row(
                          children: [
                            Text(chain, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tokenAddressController,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0x...',
                      prefixIcon: Icon(Icons.token, size: 20),
                    ),
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
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.search, size: 18),
                      label: Text(
                        _isTokenLoading ? 'Fetching...' : 'Fetch Token Balance',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_tokenBalance != null) ...[
            const SizedBox(height: 16),
            Card(
              color: _tokenBalance!.startsWith('Error')
                  ? colorScheme.errorContainer
                  : colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _tokenBalance!.startsWith('Error')
                              ? Icons.error_outline
                              : Icons.token,
                          color: _tokenBalance!.startsWith('Error')
                              ? colorScheme.onErrorContainer
                              : colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _tokenBalance!.startsWith('Error')
                              ? 'Error'
                              : 'Token Balance',
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
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.history,
                  color: colorScheme.onPrimaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Latest Transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
                      onPressed:
                          (_isLoadingTransactions ||
                              _addressController.text.isEmpty)
                          ? null
                          : _fetchTransactions,
                      icon: _isLoadingTransactions
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(
                        _isLoadingTransactions
                            ? 'Loading...'
                            : 'Fetch Transactions',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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
                            Icon(
                              Icons.receipt_long,
                              size: 18,
                              color: Colors.grey,
                            ),
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
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
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
                      child: Text(
                        'No transactions found',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
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
                          const Text(
                            'Address',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _connectedAddress!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
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
