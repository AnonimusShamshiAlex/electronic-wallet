import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Bitta xarajat yozuvi (kunlik jamg'armadan sarflangan pul)
class Expense {
  final DateTime date;
  final double amount;
  Expense(this.date, this.amount);

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'amount': amount,
      };

  factory Expense.fromJson(Map<String, dynamic> j) =>
      Expense(DateTime.parse(j['date']), (j['amount'] as num).toDouble());
}

/// Pul qo'shish tarixi
class HistoryItem {
  final DateTime date;
  final String label;
  final double amount;
  HistoryItem(this.date, this.label, this.amount);

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'label': label,
        'amount': amount,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        DateTime.parse(j['date']),
        j['label'],
        (j['amount'] as num).toDouble(),
      );
}

/// 30 kunlik kunlik-xarajat davri (50% ulush shu yerda boshqariladi)
class DailyCycle {
  DateTime startDate;
  double totalBudget; // shu davr uchun ajratilgan umumiy summa
  double spentTotal; // shu davrda hozirgacha sarflangan summa
  List<Expense> expenses;

  DailyCycle({
    required this.startDate,
    required this.totalBudget,
    required this.spentTotal,
    required this.expenses,
  });

  double get dailyLimit => totalBudget / 30.0;

  int get dayIndex {
    final diff = DateTime.now().difference(startDate).inDays;
    return diff.clamp(0, 29) + 1; // 1..30
  }

  int get daysRemaining => (30 - dayIndex).clamp(0, 30);

  bool get isFinished =>
      DateTime.now().difference(startDate).inDays >= 30;

  /// Davr boshidan hozirgi kungacha "ochilgan" limit (kun * kunlik limit)
  double get releasedSoFar => dailyLimit * dayIndex;

  /// Bugungi holatda mavjud bo'lgan mablag' (limitdan oshsa manfiy bo'lishi mumkin)
  double get availableNow => releasedSoFar - spentTotal;

  double get remainingBudget => totalBudget - spentTotal;

  Map<String, dynamic> toJson() => {
        'startDate': startDate.toIso8601String(),
        'totalBudget': totalBudget,
        'spentTotal': spentTotal,
        'expenses': expenses.map((e) => e.toJson()).toList(),
      };

  factory DailyCycle.fromJson(Map<String, dynamic> j) => DailyCycle(
        startDate: DateTime.parse(j['startDate']),
        totalBudget: (j['totalBudget'] as num).toDouble(),
        spentTotal: (j['spentTotal'] as num).toDouble(),
        expenses: (j['expenses'] as List)
            .map((e) => Expense.fromJson(e))
            .toList(),
      );
}

/// Butun hamyon holati: 4ta ulush + tarix
class WalletState {
  DailyCycle? dailyCycle; // 50% - kunlik xarajat
  double pool25; // jamg'arma
  double pool15; // zaxira
  double pool10; // boshqa ehtiyojlar
  List<HistoryItem> history;
  double lastClosedCycleOverspend; // oxirgi yopilgan davrda limitdan oshgan summa (ma'lumot uchun)

  WalletState({
    this.dailyCycle,
    this.pool25 = 0,
    this.pool15 = 0,
    this.pool10 = 0,
    List<HistoryItem>? history,
    this.lastClosedCycleOverspend = 0,
  }) : history = history ?? [];

  Map<String, dynamic> toJson() => {
        'dailyCycle': dailyCycle?.toJson(),
        'pool25': pool25,
        'pool15': pool15,
        'pool10': pool10,
        'history': history.map((h) => h.toJson()).toList(),
        'lastClosedCycleOverspend': lastClosedCycleOverspend,
      };

  factory WalletState.fromJson(Map<String, dynamic> j) => WalletState(
        dailyCycle: j['dailyCycle'] != null
            ? DailyCycle.fromJson(j['dailyCycle'])
            : null,
        pool25: (j['pool25'] as num?)?.toDouble() ?? 0,
        pool15: (j['pool15'] as num?)?.toDouble() ?? 0,
        pool10: (j['pool10'] as num?)?.toDouble() ?? 0,
        history: (j['history'] as List? ?? [])
            .map((h) => HistoryItem.fromJson(h))
            .toList(),
        lastClosedCycleOverspend:
            (j['lastClosedCycleOverspend'] as num?)?.toDouble() ?? 0,
      );
}

/// Barcha biznes-mantiq va saqlash shu klassda
class WalletEngine {
  static const _key = 'elektron_hamyon_state_v1';

  Future<WalletState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    WalletState state;
    if (raw == null) {
      state = WalletState();
    } else {
      state = WalletState.fromJson(jsonDecode(raw));
    }
    _rolloverIfNeeded(state);
    await _save(state);
    return state;
  }

  Future<void> _save(WalletState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  /// Agar joriy 30 kunlik davr tugagan bo'lsa - qolgan mablag'ni
  /// yangi 30 kunlik davrga o'tkazadi (yana 30 kunga bo'linadi).
  void _rolloverIfNeeded(WalletState state) {
    final cycle = state.dailyCycle;
    if (cycle == null) return;
    if (cycle.isFinished) {
      final leftover = cycle.remainingBudget;
      if (leftover < 0) {
        state.lastClosedCycleOverspend = -leftover;
      } else {
        state.lastClosedCycleOverspend = 0;
      }
      final newBudget = leftover > 0 ? leftover : 0.0;
      state.dailyCycle = DailyCycle(
        startDate: DateTime.now(),
        totalBudget: newBudget,
        spentTotal: 0,
        expenses: [],
      );
    }
  }

  /// Yangi pul qo'shish: 50% / 25% / 15% / 10% ga bo'linadi.
  /// 50% ulush faqat JORIY 30 kunlik davrga qo'shiladi (limit shu davr
  /// uchun qayta hisoblanadi). Agar davr bo'lmasa yoki tugagan bo'lsa,
  /// yangi 30 kunlik davr ochiladi.
  Future<WalletState> addMoney(WalletState state, double amount) async {
    _rolloverIfNeeded(state);

    final fund50 = amount * 0.50;
    final fund25 = amount * 0.25;
    final fund15 = amount * 0.15;
    final fund10 = amount * 0.10;

    state.pool25 += fund25;
    state.pool15 += fund15;
    state.pool10 += fund10;

    if (state.dailyCycle == null) {
      state.dailyCycle = DailyCycle(
        startDate: DateTime.now(),
        totalBudget: fund50,
        spentTotal: 0,
        expenses: [],
      );
    } else {
      // faqat joriy oy/davr uchun hisoblanadi - shu davr byudjetiga qo'shiladi
      state.dailyCycle!.totalBudget += fund50;
    }

    state.history.insert(
      0,
      HistoryItem(DateTime.now(), 'Pul qo\'shildi', amount),
    );

    await _save(state);
    return state;
  }

  /// Kunlik jamg'armadan (50% qismidan) xarajat yozish.
  Future<WalletState> addExpense(WalletState state, double amount) async {
    _rolloverIfNeeded(state);
    state.dailyCycle ??= DailyCycle(
      startDate: DateTime.now(),
      totalBudget: 0,
      spentTotal: 0,
      expenses: [],
    );
    state.dailyCycle!.spentTotal += amount;
    state.dailyCycle!.expenses.insert(0, Expense(DateTime.now(), amount));
    state.history.insert(
      0,
      HistoryItem(DateTime.now(), 'Xarajat (kunlik)', -amount),
    );
    await _save(state);
    return state;
  }

  /// Zaxira/jamg'arma cho'ntaklaridan (25/15/10) sarflash.
  Future<WalletState> spendFromPool(
      WalletState state, String poolName, double amount) async {
    switch (poolName) {
      case 'pool25':
        state.pool25 = (state.pool25 - amount).clamp(0, double.infinity);
        break;
      case 'pool15':
        state.pool15 = (state.pool15 - amount).clamp(0, double.infinity);
        break;
      case 'pool10':
        state.pool10 = (state.pool10 - amount).clamp(0, double.infinity);
        break;
    }
    state.history.insert(
      0,
      HistoryItem(DateTime.now(), 'Xarajat ($poolName)', -amount),
    );
    await _save(state);
    return state;
  }
}
