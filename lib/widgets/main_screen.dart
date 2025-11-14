import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:web3modal_flutter/web3modal_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer';
import 'balance_tab.dart';
import 'connect_wallet_tab.dart';
import 'sign_transaction_tab.dart';

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

