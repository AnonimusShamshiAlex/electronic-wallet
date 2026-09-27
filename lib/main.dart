import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'wallet_engine.dart';

const Color kDarkGreen = Color(0xFF0B4D2C);
const Color kDarkGreenDeep = Color(0xFF08351D);
const Color kWhite = Colors.white;

void main() {
  runApp(const ElektronHamyonApp());
}

class ElektronHamyonApp extends StatelessWidget {
  const ElektronHamyonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elektron Hamyon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kWhite,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kDarkGreen,
          primary: kDarkGreen,
          surface: kWhite,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kDarkGreen,
          foregroundColor: kWhite,
          centerTitle: true,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kDarkGreen,
            foregroundColor: kWhite,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
        fontFamily: 'Roboto',
      ),
      home: const WalletHomePage(),
    );
  }
}

class WalletHomePage extends StatefulWidget {
  const WalletHomePage({super.key});
  @override
  State<WalletHomePage> createState() => _WalletHomePageState();
}

class _WalletHomePageState extends State<WalletHomePage> {
  final WalletEngine _engine = WalletEngine();
  WalletState? _state;
  final _fmt = NumberFormat.decimalPattern('uz');

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await _engine.load();
    setState(() => _state = s);
  }

  Future<void> _showAmountDialog({
    required String title,
    required String hint,
    required Future<void> Function(double amount) onSubmit,
  }) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(
                  controller.text.replaceAll(',', '.'));
              if (val != null && val > 0) {
                await onSubmit(val);
                if (ctx.mounted) Navigator.pop(ctx);
                await _refresh();
              }
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return Scaffold(
      appBar: AppBar(title: const Text('Elektron Hamyon')),
      body: state == null
          ? const Center(child: CircularProgressIndicator(color: kDarkGreen))
          : RefreshIndicator(
              onRefresh: _refresh,
              color: kDarkGreen,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildTotalCard(state),
                  const SizedBox(height: 16),
                  if (state.dailyCycle != null)
                    _buildDailyCycleCard(state),
                  const SizedBox(height: 12),
                  _buildPoolCard(
                    title: 'Jamg\'arma (25%)',
                    amount: state.pool25,
                    poolKey: 'pool25',
                  ),
                  const SizedBox(height: 12),
                  _buildPoolCard(
                    title: 'Zaxira (15%)',
                    amount: state.pool15,
                    poolKey: 'pool15',
                  ),
                  const SizedBox(height: 12),
                  _buildPoolCard(
                    title: 'Boshqa ehtiyojlar (10%)',
                    amount: state.pool10,
                    poolKey: 'pool10',
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _showAmountDialog(
                      title: 'Pul qo\'shish',
                      hint: 'Summani kiriting',
                      onSubmit: (amt) async {
                        setState(() => _state = null);
                        await _engine.addMoney(state, amt);
                      },
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Pul qo\'shish'),
                  ),
                  const SizedBox(height: 24),
                  const Text('Tarix',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kDarkGreen,
                          fontSize: 16)),
                  const SizedBox(height: 8),
                  ...state.history.take(30).map((h) => ListTile(
                        dense: true,
                        leading: Icon(
                          h.amount >= 0
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: h.amount >= 0 ? kDarkGreen : Colors.redAccent,
                        ),
                        title: Text(h.label),
                        subtitle: Text(
                            DateFormat('dd.MM.yyyy HH:mm').format(h.date)),
                        trailing: Text(
                          '${h.amount >= 0 ? '+' : ''}${_fmt.format(h.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                h.amount >= 0 ? kDarkGreen : Colors.redAccent,
                          ),
                        ),
                      )),
                ],
              ),
            ),
    );
  }

  Widget _buildTotalCard(WalletState state) {
    final total = (state.dailyCycle?.remainingBudget ?? 0) +
        state.pool25 +
        state.pool15 +
        state.pool10;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kDarkGreen, kDarkGreenDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Umumiy balans',
              style: TextStyle(color: kWhite, fontSize: 14)),
          const SizedBox(height: 6),
          Text('${_fmt.format(total)} so\'m',
              style: const TextStyle(
                  color: kWhite,
                  fontSize: 26,
                  fontWeight: FontWeight.bold)),
          if (state.lastClosedCycleOverspend > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Oldingi davrda limitdan oshgan: '
              '${_fmt.format(state.lastClosedCycleOverspend)} so\'m',
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDailyCycleCard(WalletState state) {
    final c = state.dailyCycle!;
    final available = c.availableNow;
    final over = available < 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kDarkGreen.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: kDarkGreen.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kunlik xarajat (50%)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kDarkGreen,
                      fontSize: 16)),
              Text('${c.dayIndex}/30 kun',
                  style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (c.dayIndex / 30).clamp(0, 1),
            color: kDarkGreen,
            backgroundColor: kDarkGreen.withOpacity(0.1),
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 14),
          _infoRow('Davr byudjeti', '${_fmt.format(c.totalBudget)} so\'m'),
          _infoRow('Kunlik limit', '${_fmt.format(c.dailyLimit)} so\'m'),
          _infoRow('Jami sarflangan', '${_fmt.format(c.spentTotal)} so\'m'),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                over ? 'Limitdan oshgan' : 'Bugun mavjud mablag\'',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: over ? Colors.redAccent : kDarkGreen,
                ),
              ),
              Text(
                '${_fmt.format(available.abs())} so\'m',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: over ? Colors.redAccent : kDarkGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: kDarkGreen,
                side: const BorderSide(color: kDarkGreen),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showAmountDialog(
                title: 'Bugungi xarajat',
                hint: 'Sarflangan summani kiriting',
                onSubmit: (amt) async {
                  setState(() => _state = null);
                  await _engine.addExpense(state, amt);
                },
              ),
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('Xarajat qo\'shish'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildPoolCard({
    required String title,
    required double amount,
    required String poolKey,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDarkGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDarkGreen.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: kDarkGreen)),
                const SizedBox(height: 4),
                Text('${_fmt.format(amount)} so\'m',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showAmountDialog(
              title: 'Sarflash: $title',
              hint: 'Sarflanadigan summa',
              onSubmit: (amt) async {
                final current = await _engine.load();
                setState(() => _state = null);
                await _engine.spendFromPool(current, poolKey, amt);
              },
            ),
            icon: const Icon(Icons.remove_circle_outline, color: kDarkGreen),
          ),
        ],
      ),
    );
  }
}
