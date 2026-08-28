import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/features/transactions/data/transaction_repository.dart';

class CurrencyBalance {
  final String code;
  final String symbol;
  final double totalIncome;
  final double totalExpense;
  double get netBalance => totalIncome - totalExpense;

  CurrencyBalance({
    required this.code,
    required this.symbol,
    this.totalIncome = 0,
    this.totalExpense = 0,
  });
}

final dashboardBalancesProvider = StreamProvider<List<CurrencyBalance>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  
  return repository.getBalancePerCurrency().map((summaries) {
    final Map<String, CurrencyBalance> balances = {};
    
    for (var summary in summaries) {
      final key = summary.currencyCode;
      if (!balances.containsKey(key)) {
        balances[key] = CurrencyBalance(
          code: key, 
          symbol: summary.currencySymbol,
        ); 
      }
      
      final current = balances[key]!;
      if (summary.type == 'income') {
        balances[key] = CurrencyBalance(
          code: key,
          symbol: current.symbol,
          totalIncome: current.totalIncome + summary.total,
          totalExpense: current.totalExpense,
        );
      } else {
        balances[key] = CurrencyBalance(
          code: key,
          symbol: current.symbol,
          totalIncome: current.totalIncome,
          totalExpense: current.totalExpense + summary.total,
        );
      }
    }
    return balances.values.toList();
  });
});


