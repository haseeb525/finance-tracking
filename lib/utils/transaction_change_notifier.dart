import 'package:flutter/material.dart';

class TransactionChangeNotifier extends ChangeNotifier {
  void notifyTransactionChanged() {
    notifyListeners();
  }

  void notifyTransactionAdded() {
    notifyListeners();
  }

  void notifyTransactionDeleted() {
    notifyListeners();
  }

  void notifyTransactionUpdated() {
    notifyListeners();
  }
}
