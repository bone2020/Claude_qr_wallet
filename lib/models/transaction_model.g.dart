// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionModelAdapter extends TypeAdapter<TransactionModel> {
  @override
  final int typeId = 2;

  @override
  TransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionModel(
      id: fields[0] as String,
      senderWalletId: fields[1] as String,
      receiverWalletId: fields[2] as String,
      senderName: fields[3] as String?,
      receiverName: fields[4] as String?,
      amount: fields[5] as double,
      fee: fields[6] as double,
      currency: fields[7] as String,
      type: fields[8] as TransactionType,
      status: fields[9] as TransactionStatus,
      note: fields[10] as String?,
      createdAt: fields[11] as DateTime,
      completedAt: fields[12] as DateTime?,
      reference: fields[13] as String?,
      failureReason: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.senderWalletId)
      ..writeByte(2)
      ..write(obj.receiverWalletId)
      ..writeByte(3)
      ..write(obj.senderName)
      ..writeByte(4)
      ..write(obj.receiverName)
      ..writeByte(5)
      ..write(obj.amount)
      ..writeByte(6)
      ..write(obj.fee)
      ..writeByte(7)
      ..write(obj.currency)
      ..writeByte(8)
      ..write(obj.type)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.note)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.completedAt)
      ..writeByte(13)
      ..write(obj.reference)
      ..writeByte(14)
      ..write(obj.failureReason);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TransactionTypeAdapter extends TypeAdapter<TransactionType> {
  @override
  final int typeId = 3;

  @override
  TransactionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransactionType.send;
      case 1:
        return TransactionType.receive;
      case 2:
        return TransactionType.deposit;
      case 3:
        return TransactionType.withdraw;
      default:
        return TransactionType.send;
    }
  }

  @override
  void write(BinaryWriter writer, TransactionType obj) {
    switch (obj) {
      case TransactionType.send:
        writer.writeByte(0);
        break;
      case TransactionType.receive:
        writer.writeByte(1);
        break;
      case TransactionType.deposit:
        writer.writeByte(2);
        break;
      case TransactionType.withdraw:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TransactionStatusAdapter extends TypeAdapter<TransactionStatus> {
  @override
  final int typeId = 4;

  @override
  TransactionStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransactionStatus.pending;
      case 1:
        return TransactionStatus.completed;
      case 2:
        return TransactionStatus.failed;
      case 3:
        return TransactionStatus.cancelled;
      default:
        return TransactionStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, TransactionStatus obj) {
    switch (obj) {
      case TransactionStatus.pending:
        writer.writeByte(0);
        break;
      case TransactionStatus.completed:
        writer.writeByte(1);
        break;
      case TransactionStatus.failed:
        writer.writeByte(2);
        break;
      case TransactionStatus.cancelled:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
