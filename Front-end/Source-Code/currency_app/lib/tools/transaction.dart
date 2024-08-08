/// The Transaction class represents a financial transaction with relevant details.
class Transaction {
  late final String transactionId; // Unique identifier for the transaction.
  late final String? transactionType; // Type of the transaction (e.g., deposit, withdrawal).
  late final String? amount; // Amount involved in the transaction.
  late final String? expiryTime; // Expiry time for the transaction.
  late String status; // Current status of the transaction.

  /// Constructor for the Transaction class.
  ///
  /// [transactionId]: Unique identifier for the transaction.
  /// [transactionType]: Type of the transaction (optional).
  /// [amount]: Amount involved in the transaction (optional).
  /// [expiryTime]: Expiry time for the transaction (optional).
  /// [status]: Current status of the transaction.
  Transaction({
    required this.transactionId,
    this.transactionType,
    this.amount,
    this.expiryTime,
    required this.status,
  });
}
