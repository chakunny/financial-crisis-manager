import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService apiService = ApiService();

  List<dynamic> _transactions = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;
  String _selectedFilter = 'All';
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadData();
  }

  Future<void> _checkAuthAndLoadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
      return;
    }
    _loadData();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        apiService.fetchSummary(),
        apiService.fetchTransactions(),
      ]);

      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _transactions = results[1] as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTransactionLocally(String id, String newClassification) async {
    // 1. Instantly update the list UI so it feels lightning fast
    setState(() {
      final index = _transactions.indexWhere((tx) => tx['id'].toString() == id);
      if (index != -1) {
        _transactions[index]['classification'] = newClassification;
        _transactions[index]['is_reviewed'] = true;
      }
    });

    try {
      // 2. Send the new category to your NestJS backend
      await apiService.categorizeTransaction(id, newClassification);

      // 3. THE MISSING LINK: Fetch the newly calculated math!
      final updatedSummary = await apiService.fetchSummary();

      // 4. Redraw the Pie Chart and Current Balance
      if (mounted) {
        setState(() {
          _summary = updatedSummary;
        });
      }
    } catch (error) {
      print("Failed to sync: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save category. Check connection.")),
        );
      }
    }
  }

  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() => _isLoading = true);
      try {
        await apiService.uploadFile(result.files.single);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Import Successful!")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Upload Failed: $e")),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // --- UPGRADED: Smart Review Dialog ---
  void _showReviewDialog(String id, String merchantName, String transactionType) {
    showDialog(
      context: context,
      builder: (context) {
        // Decide which options to show based on Credit vs Debit
        List<Widget> options = [];

        if (transactionType == 'credit') {
          options = [
            _buildDialogOption(id, 'Salary', Icons.work, Colors.green),
            _buildDialogOption(id, 'Interest', Icons.savings, Colors.teal),
            _buildDialogOption(id, 'Reimbursement', Icons.handshake, Colors.blueAccent),
            _buildDialogOption(id, 'Refund', Icons.replay, Colors.purple),
            _buildDialogOption(id, 'Transfer', Icons.swap_horiz, Colors.grey),
            _buildDialogOption(id, 'Adjustment', Icons.build, Colors.orange),
          ];
        } else {
          // It's a Debit
          options = [
            _buildDialogOption(id, 'Necessary', Icons.check_circle, Colors.green),
            _buildDialogOption(id, 'Leak', Icons.warning, Colors.red),
            _buildDialogOption(id, 'Transfer', Icons.swap_horiz, Colors.grey),
            _buildDialogOption(id, 'Adjustment', Icons.build, Colors.orange),
          ];
        }

        return SimpleDialog(
          title: Text("Categorize '$merchantName'"),
          children: options,
        );
      },
    );
  }

  // --- UPGRADED: Dialog Option Builder with custom icons ---
  Widget _buildDialogOption(String id, String label, IconData icon, Color color) {
    return SimpleDialogOption(
      onPressed: () {
        Navigator.pop(context);
        _updateTransactionLocally(id, label);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(double income, double expense) {
    return [
      PieChartSectionData(
        color: Colors.green,
        value: income,
        title: 'Income',
        radius: _touchedIndex == 0 ? 60 : 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.red,
        value: expense,
        title: 'Expense',
        radius: _touchedIndex == 1 ? 60 : 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final double income = (_summary['income'] ?? 0).toDouble();
    final double expense = (_summary['expense'] ?? 0).toDouble();
    final double balance = income - expense;

    final filteredTransactions = _transactions.where((tx) {
      if (_selectedFilter == 'All') return true;
      final category = (tx['category'] ?? 'Uncategorized').toString();
      return category.toLowerCase() == _selectedFilter.toLowerCase();
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Crisis Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndUploadFile,
        child: const Icon(Icons.upload_file),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            color: Colors.blueAccent,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Current Balance",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    "\$${balance.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: _buildPieSections(income, expense),
                centerSpaceRadius: 40,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      if (event is FlTapUpEvent) {
                        if (_touchedIndex == 0) {
                          _selectedFilter = _selectedFilter == 'Income' ? 'All' : 'Income';
                        } else if (_touchedIndex == 1) {
                          _selectedFilter = _selectedFilter == 'Expense' ? 'All' : 'Expense';
                        }
                      }
                    });
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Recent Transactions",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', Colors.grey),
                      const SizedBox(width: 8),
                      _buildFilterChip('Expense', Colors.red),
                      const SizedBox(width: 8),
                      _buildFilterChip('Income', Colors.green),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredTransactions.length,
              itemBuilder: (context, index) {
                final tx = filteredTransactions[index];
                final String classification = tx['classification'] ?? 'Uncategorized';
                final String amount = "\$${tx['amount']}";
                final String txId = tx['id'].toString();
                final String txType = tx['transaction_type'] ?? 'debit';

                // --- UPGRADED: Dynamic Icons & Colors based on new categories ---
                Color iconColor = Colors.grey;
                IconData iconData = Icons.help_outline;

                switch (classification) {
                  case 'Leak':
                    iconColor = Colors.red;
                    iconData = Icons.warning;
                    break;
                  case 'Necessary':
                    iconColor = Colors.green;
                    iconData = Icons.check_circle;
                    break;
                  case 'Salary':
                    iconColor = Colors.green;
                    iconData = Icons.work;
                    break;
                  case 'Interest':
                    iconColor = Colors.teal;
                    iconData = Icons.savings;
                    break;
                  case 'Reimbursement':
                    iconColor = Colors.blueAccent;
                    iconData = Icons.handshake;
                    break;
                  case 'Refund':
                    iconColor = Colors.purple;
                    iconData = Icons.replay;
                    break;
                  case 'Transfer':
                    iconColor = Colors.grey;
                    iconData = Icons.swap_horiz;
                    break;
                  case 'Adjustment':
                    iconColor = Colors.orange;
                    iconData = Icons.build;
                    break;
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: iconColor.withOpacity(0.1),
                      child: Icon(iconData, color: iconColor),
                    ),
                    title: Text(
                      tx['merchant_name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(classification),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          amount,
                          style: TextStyle(
                            color: txType == 'credit' ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blueGrey, size: 20),
                          // --- NEW: Pass the transaction type to the dialog ---
                          onPressed: () => _showReviewDialog(txId, tx['merchant_name'], txType),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, Color color) {
    final bool isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          if (isSelected && label != 'All') {
            _selectedFilter = 'All';
          } else {
            _selectedFilter = label;
          }
        });
      },
      backgroundColor: Colors.white,
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? color : Colors.grey.shade300),
      ),
    );
  }
}